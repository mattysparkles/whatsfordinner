# PantryPilot Architecture (Scaffold)

## Principles
- **Feature-first UI**: each feature owns its presentation entry points.
- **Clean boundaries**: `core` defines contracts and models; `infrastructure` provides implementations.
- **Swap-friendly dependencies**: Riverpod providers map interfaces to mock or real adapters.
- **Small files**: avoid monolithic files and centralize shared concerns in `core`.

## Layers
1. **App layer (`lib/src/app`)**
   - Router (`GoRouter`) and dependency graph (`Riverpod`).
2. **Core layer (`lib/src/core`)**
   - Typed models, repository/service contracts, theme tokens/system, config.
3. **Infrastructure layer (`lib/src/infrastructure`)**
   - Mock services + in-memory repositories for local development.
   - Persistence adapter scaffold for Hive-backed storage.
4. **Feature layer (`lib/src/features`)**
   - Placeholder screens per product area with TODO markers for future integrations.

## Environment Strategy
- Runtime behavior controlled via Dart defines and `EnvConfig`.
- `USE_MOCKS=true` keeps local development deterministic.
- API keys and base URLs are configured but not yet consumed by live adapters.

## Why this scaffold
This structure keeps onboarding and navigation immediately runnable while preserving clean seams for future API, persistence, monetization, and cook-mode integrations without large refactors.
