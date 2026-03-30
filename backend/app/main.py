from __future__ import annotations

import hashlib
import json
import logging
import time
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
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


@dataclass(slots=True)
class _InstacartCacheEntry:
    checkout_url: str
    page_type: Literal['shopping_list', 'recipe']
    expires_at: datetime
    message: str


_instacart_url_cache: dict[str, _InstacartCacheEntry] = {}


def _request_id(request: Request) -> str:
    return request.headers.get('x-request-id') or str(uuid.uuid4())


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


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
    if isinstance(exc.detail, dict) and {'errorCode', 'userMessage', 'requestId'}.issubset(exc.detail):
        return JSONResponse(status_code=exc.status_code, content=exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(errorCode='gateway_error', userMessage='Request failed. Please try again.', requestId='unknown').model_dump(by_alias=True),
    )


async def _openai_chat_completion(request_id: str, body: dict[str, Any]) -> dict[str, Any]:
    headers = {'Authorization': f'Bearer {settings.openai_api_key}', 'Content-Type': 'application/json'}
    timeout = httpx.Timeout(settings.request_timeout_seconds)
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(f'{settings.openai_base_url}/chat/completions', headers=headers, json=body)
    if response.status_code >= 400:
        logger.warning(json.dumps({'event': 'openai_error', 'requestId': request_id, 'status': response.status_code}))
        raise _safe_error('upstream_unavailable', 'AI service is temporarily unavailable. Please try again.', request_id, 502)
    return response.json()


@app.post('/vision/parse', response_model=VisionParseResponse)
async def parse_vision(payload: VisionParseRequest, request: Request) -> VisionParseResponse:
    request_id = _request_id(request)
    client_id = request.client.host if request.client else 'unknown'
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)
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
    logger.info(json.dumps({'event': 'vision_parse_requested', 'requestId': request_id, 'imageCount': len(payload.images)}))
    raw = await _openai_chat_completion(request_id, body)
    content = raw.get('choices', [{}])[0].get('message', {}).get('content', '{}')
    try:
        parsed = VisionParseResponse.model_validate(json.loads(content))
        return parsed
    except (json.JSONDecodeError, ValidationError):
        raise _safe_error('invalid_upstream_payload', 'Could not understand AI response. Please try again.', request_id, 502)


@app.post('/recipes/suggest', response_model=RecipeSuggestResponse)
async def suggest_recipes(payload: RecipeSuggestRequest, request: Request) -> RecipeSuggestResponse:
    request_id = _request_id(request)
    client_id = request.client.host if request.client else 'unknown'
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)
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
    logger.info(json.dumps({'event': 'recipe_suggest_requested', 'requestId': request_id, 'pantryCount': len(payload.pantry_items)}))
    raw = await _openai_chat_completion(request_id, body)
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
        logger.warning(json.dumps({'event': 'instacart_connect_failed', 'requestId': request_id}))
        return _fallback_instacart_url(payload, page_type), None

    if response.status_code >= 400:
        logger.warning(
            json.dumps({'event': 'instacart_connect_error', 'requestId': request_id, 'status': response.status_code})
        )
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
    client_id = request.client.host if request.client else 'unknown'
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)

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
    logger.info(
        json.dumps(
            {
                'event': 'instacart_link_requested',
                'requestId': request_id,
                'itemCount': len(payload.items),
                'pageType': page_type,
                'fromCache': False,
            }
        )
    )
    return InstacartLinkResponse(
        checkoutUrl=checkout_url,
        message=message,
        pageType=page_type,
        expiresAt=expires_at,
        fromCache=False,
    )
