# PantryPilot architecture overview

## Goals
- Keep the app always runnable for demos.
- Make production replacement of mocks straightforward.
- Keep responsibilities obvious for new contributors.

## Layering

### 1) App layer (`lib/src/app`)
- App bootstrap and global dependency graph.
- Route mapping and navigation entry points.

### 2) Core layer (`lib/src/core`)
- Config parsing from Dart defines.
- Shared models and contracts for repositories/services.
- Reusable widgets and theme tokens.

### 3) Domain layer (`lib/src/domain`)
- Product-focused domain entities that cross features.
- Domain interfaces for business-oriented operations.

### 4) Infrastructure layer (`lib/src/infrastructure`)
- Mock implementations used for deterministic local development.
- Local persistence adapter scaffolding.

### 5) Feature layer (`lib/src/features`)
- Presentation and feature-specific state controllers.
- UI state transitions and screen composition.

## Data and dependency direction

```text
features -> domain/core contracts -> infrastructure implementations
```

- UI should depend on contracts, not concrete services.
- Riverpod providers decide whether mock vs real adapters are injected.

## State management strategy
- Riverpod `Provider` for stateless dependencies.
- Riverpod `StateNotifierProvider` for mutable feature states.
- `FutureProvider` for async recipe suggestion fetching.

## Error/loading strategy
- Async flows surface loading indicators and retry actions.
- Recoverable failures are shown in-screen with actionable messaging.
- Feature controllers keep lightweight error state where practical.

## Testing strategy
- Unit tests for controller/domain behavior.
- Widget tests for key state transitions and feature UX interactions.
- CI enforces analyze + format + tests on every PR.

## Contributor onboarding checklist
1. Read `README.md` + this file.
2. Run `flutter pub get` then `flutter test`.
3. Use mock mode (`USE_MOCKS=true`) for deterministic demos.
4. Add/adjust tests with every behavior change.
