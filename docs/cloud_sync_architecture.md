# PantryPilot Cloud Sync Architecture

## Stack
- Firebase Authentication
  - Anonymous guest session
  - Email/password sign-in and sign-up
  - Anonymous upgrade using account linking (`linkWithCredential`)
- Cloud Firestore
  - Root path: `users/{uid}/state/*`

## Firestore data model
- `users/{uid}/state/pantry_inventory`
  - `updatedAt`: server timestamp
  - `items`: serialized pantry inventory (`domain.PantryItem.toJson`)
- `users/{uid}/state/preferences`
  - `updatedAt`
  - `value`: `UserPreferences.toJson`
- `users/{uid}/state/saved_recipes`
  - `updatedAt`
  - `recipes`: `SavedRecipe[]`
- `users/{uid}/state/recipe_history`
  - `updatedAt`
  - `events`: `HistoryEvent[]`
- `users/{uid}/state/shopping_list`
  - `updatedAt`
  - `value`: serialized active shopping list
- `users/{uid}/state/active_cook_session`
  - `updatedAt`
  - `value`: structured cook session payload

## Local-first sync strategy
1. All writes commit to local persistence first.
2. Sync repository wrappers mirror local state to Firestore in background (`unawaited`/async write pattern where safe).
3. Pull on sign-in can hydrate local from cloud (for repositories with `pullFromCloud`).
4. If offline, local write still succeeds; Firestore SDK queues writes until connectivity returns.

## Conflict strategy
- Current strategy: **last-write-wins by document**.
- Reasoning: PantryPilot currently has single-user document ownership and modest write contention.
- Local-first behavior ensures no user interaction is blocked by connectivity.
- Future extension: item-level merge using deterministic IDs + revision metadata.

## Migration behavior
- After email sign-in/sign-up/upgrade, local data is uploaded to cloud via `AccountSyncMigrationService`.
- Guest users remain fully local and usable with no login.

## Emulator support
- Enable with dart define: `USE_FIREBASE_EMULATORS=true`.
- Auth emulator: localhost:9099.
- Firestore emulator: localhost:8080.
