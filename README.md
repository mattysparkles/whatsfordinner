# PantryPilot (Flutter)

PantryPilot helps people decide what to cook from ingredients they already have, with pantry tracking, recipe suggestions, shopping list generation, and cook mode guidance.

This repository is intentionally scaffolded for **serious ongoing development**: clear architecture boundaries, mock-friendly services, test coverage for key flows, and CI checks.

## Quick start

### 1) Prerequisites
- Flutter stable (Dart 3.3+)
- iOS or Android toolchain configured (`flutter doctor`)

### 2) Install dependencies
```bash
flutter pub get
```

### 3) Run
```bash
flutter run
```

### 4) Test
```bash
flutter test
```

### 5) Lint + format checks
```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
```

---

## Environment configuration

PantryPilot uses `--dart-define` for runtime configuration. A sample reference template is provided in `.env.example`.

Example:

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=USE_MOCKS=true \
  --dart-define=RECIPE_API_BASE_URL=https://example.com/recipes \
  --dart-define=VISION_API_BASE_URL=https://example.com/vision \
  --dart-define=APP_VERSION=0.1.0+1 \
  --dart-define=BUILD_DATE=2026-03-30
```

Key defines:
- `APP_ENV` = `dev | staging | prod`
- `USE_MOCKS` = `true | false`
- `RECIPE_API_BASE_URL`, `RECIPE_API_KEY`
- `VISION_API_BASE_URL`, `VISION_API_KEY`
- `APP_VERSION`, `BUILD_DATE` (for About screen metadata)

---


## Camera + photo permissions

Capture flows now use the device camera and photo library via `image_picker`, and imported files are copied into app-local support storage for durable parsing sessions.

When generating platform folders (`flutter create .` if needed), ensure these permissions are present:

- **iOS (`ios/Runner/Info.plist`)**
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
- **Android (`android/app/src/main/AndroidManifest.xml`)**
  - Camera permission + media/gallery read access appropriate for your target SDK

Android startup now attempts `ImagePicker.retrieveLostData()` to recover interrupted imports after process death.

---


## Backend gateway (FastAPI)

Production mode now uses a **backend gateway** so the mobile app never sends OpenAI or Instacart secrets from the client.

### Endpoints
- `POST /vision/parse`
- `POST /recipes/suggest`
- `POST /shopping/instacart-link`

### Local backend run
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Backend environment variables
Set these on the backend host (or local shell), never in Flutter mobile builds:
- `PANTRY_GATEWAY_OPENAI_API_KEY`
- `PANTRY_GATEWAY_OPENAI_MODEL_VISION`
- `PANTRY_GATEWAY_OPENAI_MODEL_RECIPE`
- `PANTRY_GATEWAY_OPENAI_BASE_URL`
- `PANTRY_GATEWAY_INSTACART_PARTNER_ID`
- `PANTRY_GATEWAY_INSTACART_API_KEY`
- `PANTRY_GATEWAY_RATE_LIMIT_PER_MINUTE`

### Flutter production wiring
Use `--dart-define=GATEWAY_API_BASE_URL=https://your-gateway-host` and set:
- `USE_MOCKS=false`
- `FEATURE_USE_PRODUCTION_AI_SERVICES=true`

Mock mode still works unchanged for local demos (`USE_MOCKS=true`).


## Product polish + store-readiness references

- `docs/app_store_readiness.md` — screenshot checklist, privacy nutrition placeholders, release metadata, and reviewer demo flow.
- `docs/app_icon_asset_pipeline.md` — app icon placeholder specs and bread-plane brand asset integration notes.

## Architecture at a glance

See `architecture.md` for the full overview.

```text
lib/src
├── app/                # bootstrap + providers + router
├── core/               # config, shared models, contracts, widgets
├── domain/             # cross-feature domain models/contracts
├── infrastructure/     # concrete adapters (mock + persistence)
└── features/           # feature-first UI + feature domain logic
```

---

## Developer workflow

- **Debug menu** lives in Preferences:
  - reset sample pantry data
  - refresh mock recipe suggestions
- **About / Privacy / Terms** screens are wired for demo and legal placeholders.
- CI validates analyze + format + tests on PRs.

---

## Current product flows covered by tests

- Pantry flows
- Recipe suggestion flows
- Shopping list generation
- Cook mode state transitions

---

## Suggested next iteration

1. Replace mock service adapters with production API implementations.
2. Expand persistence to durable multi-device sync strategy.
3. Add legal-approved Privacy/Terms copy.
4. Introduce analytics + crash reporting + release pipeline.
