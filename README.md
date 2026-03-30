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
