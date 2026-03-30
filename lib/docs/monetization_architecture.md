# Monetization architecture notes

## Goals
- Keep monetization tasteful and non-intrusive.
- Never interrupt active cooking tasks.
- Keep premium gating centralized so future billing/ads SDK swaps are low-risk.

## Current architecture (mocked)
1. `SubscriptionState` models free vs premium and billing lifecycle.
2. `SubscriptionService` abstracts billing and restore operations.
3. `AdPlacement` models where an ad may appear, including screen context.
4. `AdService` decides if an ad can render for a placement + subscription.
5. `EntitlementPolicy` translates subscription state into premium feature unlocks.
6. `MonetizationPolicy` (provider) is the central read API for both ad and feature gates.

## Guardrails
- `MockAdService.canRenderPlacement` always returns `false` for `AppScreenContext.cookMode`.
- Premium users never see ad placements (`adFree` entitlement).
- UI consumes a single `monetizationPolicyProvider` instead of scattering boolean checks.

## Integration plan: real ad SDK
- Add an adapter implementing `AdService` for Google Mobile Ads / equivalent.
- Keep `AdPlacement.id` stable so analytics and frequency capping can be configured remotely.
- Respect platform policy: label ads clearly and avoid deceptive placements.
- Keep rewarded flows optional and user-initiated.

## Integration plan: real purchases
- Replace `MockSubscriptionService` with StoreKit/Play Billing wrapper.
- Map purchase state updates into `SubscriptionState` with server-side verification later.
- Add startup sync + restore flow in onboarding/settings.
- Keep feature unlock logic in `EntitlementPolicy` so paywall logic stays centralized.

## UX policy
- Cook Mode remains ad-free now and in future releases.
- Upsells appear in Settings and on locked placeholder features only.
- No full-screen/interstitial ads implemented in this phase.
