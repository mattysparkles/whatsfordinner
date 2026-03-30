# PantryPilot Release Checklist

## 1) API key setup
- Configure `RECIPE_API_KEY` and `VISION_API_KEY` for staging/prod builds.
- Set `FEATURE_USE_PRODUCTION_AI_SERVICES=true` only when keys and endpoint quotas are verified.
- Keep demo builds on mocks (`USE_MOCKS=true`) for deterministic QA.

## 2) Platform permissions
- iOS: camera + photo library usage descriptions in `Info.plist`.
- Android: camera/photos permissions in manifest and runtime prompts.
- Confirm wording explains ingredient capture purpose.

## 3) Build flavors
- Recommended flavors: `dev`, `staging`, `prod` via `APP_ENV` define.
- Default beta flavor should keep external monetization and provider risk low.
- Verify app icon/name suffix differences so testers can run side-by-side.

## 4) Environment config
- `USE_MOCKS` controls broad mock behavior.
- Feature flags:
  - `FEATURE_USE_PRODUCTION_AI_SERVICES`
  - `FEATURE_SHOPPING_INSTACART`
  - `FEATURE_SHOPPING_AMAZON`
  - `FEATURE_SHOPPING_WEB_FALLBACK`
  - `FEATURE_ADS_ENABLED`
  - `FEATURE_PREMIUM_ENABLED`
- Validate each build flavor with a printed config matrix before distribution.
