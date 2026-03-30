# Shopping provider adapter architecture

PantryPilot keeps shopping provider integrations outside core recipe/shopping domain logic.

## Core design

- `ShoppingList` and `ShoppingListItem` are plain domain models in `core/models/app_models.dart`.
- `ShoppingLinkService` is an abstraction that converts a shopping list into provider link results.
- `ShoppingProviderAdapter` interfaces isolate provider-specific formatting and URL strategy.
- `ShoppingListController` only manages list state (grouping, quantity, notes, checkboxes) and never depends on provider SDKs.

## Adapter layers

- **Instacart adapter**: backend-generated hosted shopping list + recipe page links, with cache and regeneration handled server-side.
- **Amazon adapter**: product-level links with placeholder affiliate tag support (available now in mock mode).
- **Generic web fallback adapter**: remains decoupled from Instacart/Amazon and clearly labeled "coming later" in UI.

## Integration points for real providers

When production integrations are added, replace mock adapters inside `MockShoppingLinkService` with real adapters that:

1. implement each adapter interface,
2. inject credentials/config from environment,
3. optionally append affiliate tracking tokens,
4. keep account auth and checkout redirect logic in adapter/infrastructure code,
5. return `ShoppingLinkResult` back to presentation without exposing provider internals.

## UX honesty commitments

- No direct account sync is claimed.
- Labels clearly separate available provider actions from future ones.
- Share action explicitly notes current limitation and safe fallback behavior.
