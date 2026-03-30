from __future__ import annotations

import json
import logging
import time
import uuid
from urllib.parse import quote_plus
from collections import defaultdict, deque
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from .config import settings
from .schemas import (
    ErrorResponse,
    InstacartLinkRequest,
    InstacartLinkResponse,
    RecipeSuggestRequest,
    RecipeSuggestResponse,
    VisionParseRequest,
    VisionParseResponse,
)

app = FastAPI(title='PantryPilot Gateway', version='0.1.0')
logger = logging.getLogger('pantry_gateway')
logging.basicConfig(level=logging.INFO, format='%(message)s')

_rate_window: dict[str, deque[float]] = defaultdict(deque)


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


@app.post('/shopping/instacart-link', response_model=InstacartLinkResponse)
async def instacart_link(payload: InstacartLinkRequest, request: Request) -> InstacartLinkResponse:
    request_id = _request_id(request)
    client_id = request.client.host if request.client else 'unknown'
    if not _abuse_guard(client_id):
        raise _safe_error('rate_limited', 'Too many requests. Please try again shortly.', request_id, 429)

    # Placeholder for signed/affiliate Instacart API call. Keep secret-bearing calls on server only.
    # If Instacart credentials are absent, graceful fallback to hosted search URL.
    query = payload.recipe_title or ', '.join(
        f"{item.quantity or ''} {item.unit or ''} {item.ingredient_name} {f'({item.note})' if item.note else ''}".strip()
        for item in payload.items
    )
    checkout_url = f'https://www.instacart.com/store/s?k={quote_plus(query)}'
    logger.info(json.dumps({'event': 'instacart_link_requested', 'requestId': request_id, 'itemCount': len(payload.items)}))
    return InstacartLinkResponse(
        checkoutUrl=checkout_url,
        message='Shopping handoff ready in Instacart. Review and complete checkout there.',
    )
