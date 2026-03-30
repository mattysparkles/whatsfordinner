# PantryPilot Flutter Scaffold

Production-oriented first-pass scaffold for PantryPilot (iOS + Android), built with:
- Flutter
- Riverpod
- GoRouter
- Feature-first organization with clean architecture boundaries
- Mock-ready service and persistence abstractions

## Quick Start

1. Install Flutter (stable channel, Dart 3.3+).
2. Get packages:
   ```bash
   flutter pub get
   ```
3. Run app:
   ```bash
   flutter run
   ```
4. Run tests:
   ```bash
   flutter test
   ```

## Optional Runtime Config (Dart Defines)

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=USE_MOCKS=true \
  --dart-define=RECIPE_API_BASE_URL=https://example.com/recipes \
  --dart-define=VISION_API_BASE_URL=https://example.com/vision
```

Available defines:
- `APP_ENV`: `dev | staging | prod`
- `USE_MOCKS`: `true | false`
- `RECIPE_API_BASE_URL`
- `VISION_API_BASE_URL`
- `RECIPE_API_KEY`
- `VISION_API_KEY`

## Architecture Snapshot

```text
lib/src
├── app/                   # app bootstrap, DI providers, router
├── core/
│   ├── config/            # env + app config providers
│   ├── models/            # strongly typed app models
│   ├── repositories/      # repository contracts
│   ├── services/          # service contracts
│   ├── theme/             # tokens + theme system (light/dark)
│   ├── utils/             # utility constants/helpers
│   └── widgets/           # shared reusable widgets
├── features/
│   ├── onboarding/
│   ├── home/
│   ├── capture/
│   ├── pantry/
│   ├── recipes/
│   ├── cook_mode/
│   ├── shopping_list/
│   ├── preferences/
│   ├── favorites_history/
│   └── monetization/
└── infrastructure/
    ├── mock/              # mock services and in-memory repositories
    └── persistence/       # local persistence adapters
```

## Implemented Navigation Flow

- App starts at `/onboarding`
- Onboarding CTA navigates to `/home`
- Home provides links to all placeholder feature screens:
  - capture
  - pantry
  - recipes
  - cook mode
  - shopping list
  - preferences
  - favorites/history
  - monetization

## Notes for Next Iteration

- TODO(api): Replace mock services with production adapters behind `core/services` interfaces.
- TODO(persistence): Move repository data from in-memory to durable local persistence.
- TODO(features): Replace placeholder screens with real feature state + use cases.
