# PantryPilot (working title)

PantryPilot is a Flutter MVP scaffold for helping users discover meals from ingredients they already have.

## Phase 1 Included
- Cross-platform Flutter scaffold (iOS/Android-ready code architecture)
- Onboarding, home, capture, pantry, recipe results/detail, cook mode, shopping list, preferences, and favorites/history screens
- Recipe matching taxonomy (exact / near match / AI invention)
- Mock AI parsing + mock recipe suggestion services
- Manual pantry editing flow
- Shopping list generation placeholders
- Ad and premium architecture placeholders (service interfaces + premium badges)
- Riverpod state management + GoRouter routing
- Local storage bootstrap (Hive)
- Unit + widget test examples

## Setup
1. Install Flutter SDK (3.22+ recommended) and platform toolchains.
2. Copy env template:
   ```bash
   cp .env.example .env
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run app:
   ```bash
   flutter run
   ```
5. Run tests:
   ```bash
   flutter test
   ```

## Architecture Notes

### Clean-ish layered structure
- `lib/src/domain`: pure domain models + service/repository contracts
- `lib/src/infrastructure`: mock implementations + persistence bootstrap
- `lib/src/features`: feature-first UI screens
- `lib/src/app`: router + DI providers
- `lib/src/shared`: reusable UI primitives

### Future integration extension points
- **AI vision API**: replace `MockVisionParsingService` in `lib/src/infrastructure/mock/mock_services.dart`
- **Recipe generation API**: replace `MockRecipeSuggestionService`
- **Instacart/cart flow**: implement provider adapters behind `ShoppingLinkService`
- **Amazon affiliate/product links**: add adapter implementation, keep external logic out of domain
- **Delivery providers**: add adapters behind `ShoppingLinkService` or dedicated `DeliveryAdapter`
- **Ads**: replace `MockAdService`; keep cook mode ad-free in UI composition
- **Premium subscriptions**: replace `MockSubscriptionService` with store-backed service

## TODO Integration Markers
- Add image_picker/camera concrete capture adapters and permissions handling.
- Add real OCR/vision parsing, confidence explanation provenance, and retry pipeline.
- Add robust ingredient normalization and unit conversion pipeline.
- Add persistent repositories using Hive boxes/typed adapters.
- Add analytics, crash reporting, and feature flag remote config.

## Product Guardrails Implemented
- Recipe cards and detail pages explicitly show match type.
- Capture flow exposes confidence and allows manual review.
- Suggestions include “why this was suggested.”
- Grocery providers are isolated behind abstraction interfaces.
