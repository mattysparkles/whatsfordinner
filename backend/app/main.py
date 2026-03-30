from __future__ import annotations

import hashlib
import asyncio
import json
import logging
import time
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import Enum
from typing import Any, Literal
from urllib.parse import quote_plus

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from .config import settings
from .schemas import (
    ErrorResponse,
    InstacartHealthFilterInput,
    InstacartLinkRequest,
    InstacartLinkResponse,
    InstacartLineItemInput,
    RecipeSuggestRequest,
    RecipeSuggestResponse,
    VisionParseRequest,
    VisionParseResponse,
)

app = FastAPI(title='PantryPilot Gateway', version='0.1.0')
logger = logging.getLogger('pantry_gateway')
logging.basicConfig(level=logging.INFO, format='%(message)s')

_rate_window: dict[str, deque[float]] = defaultdict(deque)
_user_quota_window: dict[str, deque[float]] = defaultdict(deque)
_device_quota_window: dict[str, deque[float]] = defaultdict(deque)


class MeterKind(str, Enum):
    vision = 'vision'
    recipe = 'recipe'


@dataclass(slots=True)
class _InstacartCacheEntry:
    checkout_url: str
    page_type: Literal['shopping_list', 'recipe']
    expires_at: datetime
    message: str


@dataclass(slots=True)
class _AICacheEntry:
    value: dict[str, Any]
    expires_at: datetime


@dataclass(slots=True)
class _CircuitState:
    failures: int = 0
    opened_until: float = 0.0


@dataclass(slots=True)
class _EndpointMeter:
    calls: int = 0
    payload_bytes_total: int = 0
    latency_ms_total: float = 0.0


_instacart_url_cache: dict[str, _InstacartCacheEntry] = {}
_ai_response_cache: dict[tuple[MeterKind, str], _AICacheEntry] = {}
_openai_circuit: dict[MeterKind, _CircuitState] = defaultdict(_CircuitState)
_meters: dict[MeterKind, _EndpointMeter] = defaultdict(_EndpointMeter)


def _request_id(request: Request) -> str:
    return request.headers.get('x-request-id') or str(uuid.uuid4())


def _client_identity(request: Request) -> tuple[str, str, str]:
    ip = request.client.host if request.client else 'unknown'
    user_id = request.headers.get('x-user-id') or f'anon:{ip}'
    device_id = request.headers.get('x-device-id') or f'anon-device:{ip}'
    return ip, user_id.strip(), device_id.strip()


def _safe_error(code: str, message: str, request_id: str, status_code: int) -> HTTPException:
    payload = ErrorResponse(errorCode=code, userMessage=message, requestId=request_id).model_dump(by_alias=True)
    return HTTPException(status_code=status_code, detail=payload)


def _abuse_guard(client_id: str) -> bool:
    now = time.time()
    q = _rate_window[client_id]
    while q and now - q[0] > 60:
        q.popleft()
    if len(q) >= settings.rate_limit_per_minute:
        return False
    q.append(now)
    return True


def _bounded_window_allow(window: dict[str, deque[float]], key: str, *, max_requests: int, seconds: int) -> bool:
    now = time.time()
    q = window[key]
    while q and now - q[0] > seconds:
        q.popleft()
    if len(q) >= max_requests:
        return False
    q.append(now)
    return True


def _quota_guard(user_id: str, device_id: str) -> bool:
    user_ok = _bounded_window_allow(_user_quota_window, user_id, max_requests=settings.user_quota_per_hour, seconds=3600)
    device_ok = _bounded_window_allow(
        _device_quota_window,
        device_id,
        max_requests=settings.device_quota_per_hour,
        seconds=3600,
    )
    return user_ok and device_ok


def _cache_key_from_payload(payload: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode('utf-8')).hexdigest()


def _record_meter(kind: MeterKind, payload_bytes: int, latency_ms: float) -> dict[str, float | int]:
    meter = _meters[kind]
    meter.calls += 1
    meter.payload_bytes_total += payload_bytes
    meter.latency_ms_total += latency_ms
    avg_payload = meter.payload_bytes_total / meter.calls
    avg_latency = meter.latency_ms_total / meter.calls
    return {
        'calls': meter.calls,
        'avgPayloadBytes': round(avg_payload, 2),
        'avgLatencyMs': round(avg_latency, 2),
    }


def _safe_payload_summary(payload: dict[str, Any]) -> dict[str, Any]:
    redacted = dict(payload)
    messages = redacted.get('messages')
    if isinstance(messages, list):
        redacted['messageCount'] = len(messages)
        redacted.pop('messages', None)
    redacted.pop('input_image', None)
    return redacted


def _log_event(event: str, **fields: Any) -> None:
    logger.info(json.dumps({'event': event, 'ts': datetime.now(UTC).isoformat(), **fields}, default=str))


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    if isinstance(exc.detail, dict) and {'errorCode', 'userMessage', 'requestId'}.issubset(exc.detail):
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(errorCode='gateway_error', userMessage='Request failed. Please try again.', requestId='unknown').model_dump(by_alias=True),
    )


async def _openai_chat_completion(
    request_id: str,
    body: dict[str, Any],
    *,
    meter_kind: MeterKind,
    cache_key: str,
) -> dict[str, Any]:
    circuit = _openai_circuit[meter_kind]
    now = time.time()
    if circuit.opened_until > now:
        cached = _ai_response_cache.get((meter_kind, cache_key))
        if cached and cached.expires_at > datetime.now(UTC):
            _log_event('openai_circuit_fallback_cache_hit', requestId=request_id, kind=meter_kind.value)
            return cached.value
        raise _safe_error('upstream_unavailable', 'AI service is temporarily unavailable. Please try again.', request_id, 502)

    headers = {'Authorization': f'Bearer {settings.openai_api_key}', 'Content-Type': 'application/json'}
    timeout = httpx.Timeout(settings.request_timeout_seconds)
    started = time.perf_counter()
    payload_bytes = len(json.dumps(body).encode('utf-8'))

    last_status: int | None = None
    for attempt in range(settings.openai_max_retries + 1):
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(f'{settings.openai_base_url}/chat/completions', headers=headers, json=body)
            if response.status_code < 500:
                if response.status_code >= 400:
                    _log_event('openai_error', requestId=request_id, status=response.status_code, kind=meter_kind.value)
                    raise _safe_error('upstream_unavailable', 'AI service is temporarily unavailable. Please try again.', request_id, 502)
                circuit.failures = 0
                circuit.opened_until = 0.0
                data = response.json()
                _ai_response_cache[(meter_kind, cache_key)] = _AICacheEntry(
                    value=data,
                    expires_at=datetime.now(UTC) + timedelta(seconds=settings.ai_cache_ttl_seconds),
                )
                meter_rollup = _record_meter(meter_kind, payload_bytes, (time.perf_counter() - started) * 1000)
                _log_event('ai_request_succeeded', requestId=request_id, kind=meter_kind.value, **meter_rollup)
                return data
            last_status = response.status_code
        except httpx.HTTPError:
            last_status = None

        if attempt < settings.openai_max_retries:
            backoff = settings.openai_retry_backoff_seconds * (2**attempt)
            _log_event('openai_retrying', requestId=request_id, kind=meter_kind.value, attempt=attempt + 1, backoffSeconds=backoff)
            await asyncio.sleep(backoff)

    circuit.failures += 1
    if circuit.failures >= settings.openai_circuit_fail_threshold:
        circuit.opened_until = time.time() + settings.openai_circuit_reset_seconds
    cached = _ai_response_cache.get((meter_kind, cache_key))
    if cached and cached.expires_at > datetime.now(UTC):
        _log_event(
            'openai_failure_cache_fallback',
            requestId=request_id,
            kind=meter_kind.value,
            failures=circuit.failures,
            status=last_status,
        )
        return cached.value

    _log_event('openai_failure', requestId=request_id, kind=meter_kind.value, failures=circuit.failures, status=last_status)
    raise _safe_error('upstream_unavailable', 'AI service is temporarily unavailable. Please try again.', request_id, 502)


@app.post('/vision/parse', response_model=VisionParseResponse)
async def parse_vision(payload: VisionParseRequest, request: Request) -> VisionParseResponse:
    request_id = _request_id(request)
    client_id, user_id, device_id = _client_identity(request)
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)
    if not _quota_guard(user_id, device_id):
        raise _safe_error('quota_exceeded', 'Request quota reached. Please try again later.', request_id, 429)
    if not settings.openai_api_key:
        raise _safe_error('misconfigured', 'Service is not configured right now.', request_id, 503)

    image_content = [
        {
            'type': 'image_url',
            'image_url': {'url': f"data:{image.mime_type};base64,{image.base64_data}"},
        }
        for image in payload.images
    ]
    prompt = 'Return strict JSON with ingredientCandidates[]. Include sourceImageId, rawTextOrCue, suggestedIngredientName, confidenceScore(0..1), confidenceClass(likely|possible|unclear), ingredientCategory, quantity, unit, whyDetected.'
    body = {
        'model': settings.openai_model_vision,
        'messages': [
            {'role': 'system', 'content': 'You are a pantry ingredient extraction assistant. Return valid JSON only.'},
            {'role': 'user', 'content': [{'type': 'text', 'text': prompt}, *image_content]},
        ],
        'temperature': 0.2,
    }
    cache_key = _cache_key_from_payload(payload.model_dump(by_alias=True))
    cached = _ai_response_cache.get((MeterKind.vision, cache_key))
    if cached and cached.expires_at > datetime.now(UTC):
        raw = cached.value
        _log_event('vision_parse_cache_hit', requestId=request_id, userId=user_id)
    else:
        _log_event(
            'vision_parse_requested',
            requestId=request_id,
            userId=user_id,
            imageCount=len(payload.images),
            safeRequest=_safe_payload_summary(body),
        )
        raw = await _openai_chat_completion(request_id, body, meter_kind=MeterKind.vision, cache_key=cache_key)

    content = raw.get('choices', [{}])[0].get('message', {}).get('content', '{}')
    try:
        parsed = VisionParseResponse.model_validate(json.loads(content))
        return parsed
    except (json.JSONDecodeError, ValidationError):
        raise _safe_error('invalid_upstream_payload', 'Could not understand AI response. Please try again.', request_id, 502)


@app.post('/recipes/suggest', response_model=RecipeSuggestResponse)
async def suggest_recipes(payload: RecipeSuggestRequest, request: Request) -> RecipeSuggestResponse:
    request_id = _request_id(request)
    client_id, user_id, device_id = _client_identity(request)
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)
    if not _quota_guard(user_id, device_id):
        raise _safe_error('quota_exceeded', 'Request quota reached. Please try again later.', request_id, 429)
    if not settings.openai_api_key:
        raise _safe_error('misconfigured', 'Service is not configured right now.', request_id, 503)

    body = {
        'model': settings.openai_model_recipe,
        'messages': [
            {'role': 'system', 'content': 'You generate pantry recipe suggestions as strict JSON with top-level suggestions array.'},
            {'role': 'user', 'content': json.dumps(payload.model_dump(by_alias=True))},
        ],
        'temperature': 0.4,
    }
    cache_key = _cache_key_from_payload(payload.model_dump(by_alias=True))
    cached = _ai_response_cache.get((MeterKind.recipe, cache_key))
    if cached and cached.expires_at > datetime.now(UTC):
        raw = cached.value
        _log_event('recipe_suggest_cache_hit', requestId=request_id, userId=user_id)
    else:
        _log_event(
            'recipe_suggest_requested',
            requestId=request_id,
            userId=user_id,
            pantryCount=len(payload.pantry_items),
            safeRequest=_safe_payload_summary(body),
        )
        raw = await _openai_chat_completion(request_id, body, meter_kind=MeterKind.recipe, cache_key=cache_key)

    content = raw.get('choices', [{}])[0].get('message', {}).get('content', '{}')
    try:
        parsed = RecipeSuggestResponse.model_validate(json.loads(content))
        return parsed
    except (json.JSONDecodeError, ValidationError):
        raise _safe_error('invalid_upstream_payload', 'Could not generate recipes right now. Please try again.', request_id, 502)


def _coerce_page_type(payload: InstacartLinkRequest) -> Literal['shopping_list', 'recipe']:
    if payload.page_type is not None:
        return payload.page_type
    if payload.recipe_title:
        return 'recipe'
    return 'shopping_list'


def _normalize_text(value: str | None) -> str:
    return (value or '').strip().lower()


def _line_item_health_filters(note: str | None, item_name: str) -> list[InstacartHealthFilterInput]:
    source = f'{note or ""} {item_name}'.lower()
    mappings = {
        'organic': 'organic',
        'gluten-free': 'gluten_free',
        'gluten free': 'gluten_free',
        'low sodium': 'low_sodium',
        'no salt': 'low_sodium',
        'no sugar': 'no_sugar_added',
        'low sugar': 'low_sugar',
        'whole grain': 'whole_grain',
    }
    seen: set[str] = set()
    for pattern, code in mappings.items():
        if pattern in source:
            seen.add(code)
    return [InstacartHealthFilterInput(code=code) for code in sorted(seen)]


def _display_text(ingredient_name: str, quantity: float | None, unit: str | None, note: str | None) -> str:
    bits: list[str] = []
    if quantity is not None:
        if quantity.is_integer():
            bits.append(str(int(quantity)))
        else:
            bits.append(f'{quantity:.2f}'.rstrip('0').rstrip('.'))
    if unit:
        bits.append(unit.strip())
    bits.append(ingredient_name.strip())
    text = ' '.join(bits)
    if note and note.strip():
        text = f'{text} ({note.strip()})'
    return text


def _build_line_items(payload: InstacartLinkRequest) -> list[InstacartLineItemInput]:
    if payload.line_items:
        return payload.line_items

    line_items: list[InstacartLineItemInput] = []
    for item in payload.items:
        display = _display_text(item.ingredient_name, item.quantity, item.unit, item.note)
        line_items.append(
            InstacartLineItemInput(
                itemName=item.ingredient_name.strip(),
                quantity=item.quantity,
                unit=item.unit.strip() if item.unit else None,
                displayText=display,
                healthFilters=_line_item_health_filters(item.note, item.ingredient_name),
            )
        )
    return line_items


def _fingerprint_for_request(page_type: str, recipe_title: str | None, line_items: list[InstacartLineItemInput]) -> str:
    normalized_items = [
        {
            'name': _normalize_text(item.item_name),
            'quantity': item.quantity,
            'unit': _normalize_text(item.unit),
            'displayText': _normalize_text(item.display_text),
            'healthFilters': sorted(f.code for f in item.health_filters),
        }
        for item in line_items
    ]
    normalized_items.sort(key=lambda item: (item['name'], str(item['quantity']), item['unit'], item['displayText']))
    source = {
        'pageType': page_type,
        'recipeTitle': _normalize_text(recipe_title),
        'lineItems': normalized_items,
    }
    return hashlib.sha256(json.dumps(source, sort_keys=True).encode('utf-8')).hexdigest()


def _fallback_instacart_url(payload: InstacartLinkRequest, page_type: str) -> str:
    query = payload.recipe_title or ', '.join(
        f"{item.quantity or ''} {item.unit or ''} {item.ingredient_name} {f'({item.note})' if item.note else ''}".strip()
        for item in payload.items
    )
    if page_type == 'recipe':
        return f'https://www.instacart.com/store/recipes/s?k={quote_plus(query)}'
    return f'https://www.instacart.com/store/s?k={quote_plus(query)}'


async def _create_instacart_hosted_url(
    request_id: str,
    *,
    payload: InstacartLinkRequest,
    page_type: Literal['shopping_list', 'recipe'],
    line_items: list[InstacartLineItemInput],
) -> tuple[str, datetime | None]:
    if not settings.instacart_partner_id or not settings.instacart_api_key:
        return _fallback_instacart_url(payload, page_type), None

    request_body = {
        'partner_id': settings.instacart_partner_id,
        'page_type': page_type,
        'title': payload.recipe_title,
        'line_items': [item.model_dump(by_alias=True, exclude_none=True) for item in line_items],
    }
    headers = {
        'Authorization': f'Bearer {settings.instacart_api_key}',
        'Content-Type': 'application/json',
        'X-Partner-Id': settings.instacart_partner_id,
    }
    timeout = httpx.Timeout(settings.request_timeout_seconds)

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                f'{settings.instacart_api_base_url.rstrip("/")}/idp/v1/hosted_pages',
                headers=headers,
                json=request_body,
            )
    except httpx.HTTPError:
        _log_event('instacart_connect_failed', requestId=request_id)
        return _fallback_instacart_url(payload, page_type), None

    if response.status_code >= 400:
        _log_event('instacart_connect_error', requestId=request_id, status=response.status_code)
        return _fallback_instacart_url(payload, page_type), None

    body = response.json() if response.content else {}
    checkout_url = body.get('url') or body.get('hosted_url') or body.get('checkout_url')
    expires_at_raw = body.get('expires_at') or body.get('expiresAt')
    if not isinstance(checkout_url, str) or not checkout_url.strip():
        return _fallback_instacart_url(payload, page_type), None

    parsed_expiration: datetime | None = None
    if isinstance(expires_at_raw, str):
        try:
            parsed_expiration = datetime.fromisoformat(expires_at_raw.replace('Z', '+00:00')).astimezone(UTC)
        except ValueError:
            parsed_expiration = None
    return checkout_url.strip(), parsed_expiration


def _cache_default_expiration() -> datetime:
    return datetime.now(UTC) + timedelta(seconds=settings.instacart_hosted_link_ttl_seconds)


@app.post('/shopping/instacart-link', response_model=InstacartLinkResponse)
async def instacart_link(payload: InstacartLinkRequest, request: Request) -> InstacartLinkResponse:
    request_id = _request_id(request)
    client_id, user_id, device_id = _client_identity(request)
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)
    if not _quota_guard(user_id, device_id):
        raise _safe_error('quota_exceeded', 'Request quota reached. Please try again later.', request_id, 429)

    page_type = _coerce_page_type(payload)
    line_items = _build_line_items(payload)
    cache_key = _fingerprint_for_request(page_type, payload.recipe_title, line_items)
    now = datetime.now(UTC)

    cached = _instacart_url_cache.get(cache_key)
    if cached and cached.expires_at > now:
        return InstacartLinkResponse(
            checkoutUrl=cached.checkout_url,
            message=cached.message,
            pageType=cached.page_type,
            expiresAt=cached.expires_at,
            fromCache=True,
        )

    checkout_url, upstream_expires_at = await _create_instacart_hosted_url(
        request_id,
        payload=payload,
        page_type=page_type,
        line_items=line_items,
    )
    expires_at = upstream_expires_at or _cache_default_expiration()
    message = (
        'Recipe handoff ready in Instacart. Review and complete checkout there.'
        if page_type == 'recipe'
        else 'Shopping list handoff ready in Instacart. Review and complete checkout there.'
    )
    _instacart_url_cache[cache_key] = _InstacartCacheEntry(
        checkout_url=checkout_url,
        page_type=page_type,
        expires_at=expires_at,
        message=message,
    )
    _log_event(
        'instacart_link_requested',
        requestId=request_id,
        userId=user_id,
        itemCount=len(payload.items),
        pageType=page_type,
        fromCache=False,
    )
    return InstacartLinkResponse(
        checkoutUrl=checkout_url,
        message=message,
        pageType=page_type,
        expiresAt=expires_at,
        fromCache=False,
    )
