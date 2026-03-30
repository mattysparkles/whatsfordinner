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
- App-wide models used by multiple features (recipes, shopping, shared enums).
- Shared UI primitives (`AppScaffold`, design tokens, app theme).

### 3) Domain layer (`lib/src/domain`)
- Pantry/capture domain entities plus repository/service contracts that are not feature-local.
- Keep this layer focused on domain contracts and avoid duplicate UI-facing models.

### 4) Infrastructure layer (`lib/src/infrastructure`)
- Mock implementations used for deterministic local development.
- Local persistence adapter scaffolding.

### 5) Feature layer (`lib/src/features`)
- Presentation and feature-specific state controllers.
- UI state transitions and screen composition.
- Use `presentation/` as the canonical location for screen widgets.
- Remove legacy duplicate screen files when migrating a feature.

## Data and dependency direction

```text
features -> domain/core contracts -> infrastructure implementations
```

- UI should depend on contracts, not concrete services.
- Riverpod providers decide whether mock vs real adapters are injected.
- Providers must not silently return mocks in production mode. If a production adapter does not exist yet, throw a clear `UnsupportedError`.

## Navigation conventions
- Central route constants live in `lib/src/app/app_routes.dart`.
- Typed route extras for data-carrying routes live in `lib/src/app/app_navigation.dart`.
- Use typed extension helpers (`context.pushRecipeDetail(...)`, `context.pushCookMode(...)`) instead of ad-hoc `extra` maps/casts.
- Screens that require route data must:
  1. accept typed seed data through constructors from `app_router.dart`, and
  2. gracefully handle missing data with a user-safe fallback state.

## Scaffold conventions
- `AppScaffold` is the default shell for feature screens.
- A custom `Scaffold` is allowed only for compelling UX reasons (example: full-screen themed cook mode).
- Do not introduce additional scaffold wrappers unless they are truly app-wide and replace `AppScaffold`.

## Folder boundary rules
- Prefer imports from `presentation/` screens and avoid parallel legacy paths.
- Keep shared widgets in `core/widgets`; avoid a second shared widget root.
- Delete dead placeholder files once the canonical implementation exists.

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
- Add regression widget tests for route handoffs when a screen requires typed payloads.
- CI enforces analyze + format + tests on every PR.

## Contributor onboarding checklist
1. Read `README.md` + this file.
2. Run `flutter pub get` then `flutter test`.
3. Use mock mode (`USE_MOCKS=true`) for deterministic demos.
4. Add/adjust tests with every behavior change.
