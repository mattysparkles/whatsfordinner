import '../../../../../core/models/app_models.dart';
import '../../../domain/shopping_services.dart';
import '../../../../../infrastructure/gateway/pantry_gateway_client.dart';
import '../shopping_link_mapper.dart';

class BackendInstacartLinkAdapter implements InstacartProviderAdapter {
  BackendInstacartLinkAdapter({required PantryGatewayClient client}) : _client = client;

  final PantryGatewayClient _client;

  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'instacart',
        name: 'Instacart',
        capabilityLabel: ProviderCapabilityLabel.active,
        supportsAffiliateTracking: true,
        notes: 'Server-generated hosted page URL with secret-safe Instacart integration.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final pageType = _resolvePageType(list);
    final payload = {
      'recipeTitle': list.recipeTitle,
      'pageType': pageType,
      'items': list.items
          .map(
            (item) => {
              'ingredientName': item.ingredientName,
              'quantity': item.quantity,
              'unit': item.unit,
              'note': item.note,
            },
          )
          .toList(growable: false),
      'lineItems': list.items.map(_mapLineItem).toList(growable: false),
    };

    try {
      final response = await _client.postJson(path: '/shopping/instacart-link', payload: payload);
      final checkout = (response['checkoutUrl'] as String?) ?? 'https://www.instacart.com/store';
      return ShoppingLinkResult(
        provider: provider,
        checkoutUri: Uri.parse(checkout),
        message: (response['message'] as String?) ?? _defaultMessageFor(pageType),
        itemUris: const [],
      );
    } on PantryGatewayException catch (error) {
      throw StateError(error.userMessage);
    }
  }

  Map<String, Object?> _mapLineItem(ShoppingListItem item) {
    final healthFilters = _healthFiltersFrom(item);
    return {
      'itemName': item.ingredientName.trim(),
      'quantity': item.quantity,
      'unit': item.unit?.trim(),
      'displayText': formatItemForProvider(item),
      if (healthFilters.isNotEmpty)
        'healthFilters': healthFilters.map((code) => {'code': code}).toList(growable: false),
    };
  }

  String _resolvePageType(ShoppingList list) {
    if ((list.recipeTitle ?? '').trim().isNotEmpty) return 'recipe';
    return 'shopping_list';
  }

  String _defaultMessageFor(String pageType) {
    if (pageType == 'recipe') return 'Recipe handoff ready in Instacart.';
    return 'Shopping list handoff ready in Instacart.';
  }

  List<String> _healthFiltersFrom(ShoppingListItem item) {
    final source = '${item.ingredientName} ${item.note ?? ''}'.toLowerCase();
    final filters = <String>{};
    if (source.contains('organic')) filters.add('organic');
    if (source.contains('gluten free') || source.contains('gluten-free')) filters.add('gluten_free');
    if (source.contains('low sodium') || source.contains('no salt')) filters.add('low_sodium');
    if (source.contains('low sugar') || source.contains('no sugar')) filters.add('low_sugar');
    if (source.contains('whole grain')) filters.add('whole_grain');
    return filters.toList(growable: false)..sort();
  }
}
