# Backend observability and AI cost controls

This gateway now includes practical production controls for reliability, cost, and privacy.

## What is measured

Structured JSON logs emit dashboard-friendly events for:

- `vision_parse_requested` / `recipe_suggest_requested`
- `ai_request_succeeded` (includes rolling averages)
- `openai_retrying`
- `openai_failure`, `openai_failure_cache_fallback`
- `openai_circuit_fallback_cache_hit`
- `*_cache_hit` events for repeated requests

Rolling meter fields on `ai_request_succeeded`:

- `calls` (per endpoint kind)
- `avgPayloadBytes`
- `avgLatencyMs`

These directly track:

- vision parse calls
- recipe generation calls
- average payload size
- average latency

## Quota strategy (basic, practical defaults)

Quota checks run in-memory with per-hour windows:

- Per-user quota (`PANTRY_GATEWAY_USER_QUOTA_PER_HOUR`, default `120`)
- Per-device quota (`PANTRY_GATEWAY_DEVICE_QUOTA_PER_HOUR`, default `180`)

Identity source:

- `x-user-id` header (fallback `anon:<ip>`)
- `x-device-id` header (fallback `anon-device:<ip>`)

If either is exceeded, the API returns HTTP `429` + `quota_exceeded`.

## Cache strategy improvements

AI responses now cache by normalized request fingerprint + endpoint kind:

- Vision: cache repeated pantry image parse requests.
- Recipe: cache repeated recipe suggestion requests for unchanged pantry/preferences.
- Instacart links: existing stable fingerprint cache remains in place.

AI cache TTL is controlled by `PANTRY_GATEWAY_AI_CACHE_TTL_SECONDS` (default `600`).

## Privacy-safe logging

Logs are intentionally redacted:

- No raw base64 image data is logged.
- No raw OpenAI/Instacart secrets are logged.
- Log payloads include only safe summaries (counts + metadata).

## Retry + circuit-breaker behavior

OpenAI call flow:

1. Retry transient failures up to `PANTRY_GATEWAY_OPENAI_MAX_RETRIES` (default `2`).
2. Exponential backoff starts at `PANTRY_GATEWAY_OPENAI_RETRY_BACKOFF_SECONDS` (default `0.4`).
3. After `PANTRY_GATEWAY_OPENAI_CIRCUIT_FAIL_THRESHOLD` consecutive failures (default `5`), open a circuit for `PANTRY_GATEWAY_OPENAI_CIRCUIT_RESET_SECONDS` (default `45`).
4. While open, serve cached response when available; otherwise return upstream unavailable.

This gives predictable latency under incidents and limits runaway cost on repeated failing upstream calls.

## Suggested dashboard widgets

1. **AI Success Rate**
   - Count `ai_request_succeeded` vs `openai_failure`
2. **Mean AI Latency**
   - Average `avgLatencyMs` over time
3. **Mean AI Payload**
   - Average `avgPayloadBytes` over time
4. **Cache Hit Ratio**
   - `vision_parse_cache_hit` + `recipe_suggest_cache_hit` divided by all AI request events
5. **Quota Rejections**
   - Count HTTP 429 with `quota_exceeded`
6. **Circuit Open Events**
   - Count `openai_circuit_fallback_cache_hit` and failure fallback events

## Cost monitoring tips

- Alert when payload size drifts up unexpectedly.
- Alert when cache hit ratio drops (often means request canonicalization drift).
- Track retry volume (`openai_retrying`) as a leading indicator before full outages.
- Pair call counts with model unit pricing in your billing pipeline for estimated per-day spend.
