# PantryPilot Beta Readiness Snapshot

## Real today
- Pantry inventory CRUD + local persistence.
- Capture import workflow with review-before-save guardrails.
- Recipe suggestion browsing and recipe detail flow.
- Shopping list editing, copy/share handoff.
- Structured analytics event hooks and crash/error abstraction.
- Feature flags for AI services, shopping adapters, ads, and premium gating.

## Mocked today
- Ad rendering (mock widgets).
- Subscription upgrades/restores (mock service).
- Some AI and voice command paths when `USE_MOCKS=true` or feature flags disable production.

## Planned / next
- Production analytics backend sink.
- Production crash reporting backend sink.
- Full consent flow for analytics/privacy.
- Production shopping deep integrations and affiliate telemetry.
- Store-review hardening: legal copy, localization, and QA automation coverage expansion.

## Beta testing guidance
- Keep debug/demo toggles available in debug builds only.
- Use settings toggles to declare analytics placeholder and AI voice disclosure state during test scripts.
- Focus exploratory testing on import failures, offline behavior, and shopping handoff robustness.
