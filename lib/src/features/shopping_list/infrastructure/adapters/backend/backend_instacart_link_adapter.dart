import '../../../../../core/models/app_models.dart';
import '../../../domain/shopping_services.dart';
import '../../../../../infrastructure/gateway/pantry_gateway_client.dart';

class BackendInstacartLinkAdapter implements InstacartProviderAdapter {
  BackendInstacartLinkAdapter({required PantryGatewayClient client}) : _client = client;

  final PantryGatewayClient _client;

  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'instacart',
        name: 'Instacart',
        capabilityLabel: ProviderCapabilityLabel.active,
        supportsAffiliateTracking: true,
        notes: 'Server-generated handoff URL with secret-safe provider integration.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final payload = {
      'recipeTitle': list.recipeTitle,
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
    };

    try {
      final response = await _client.postJson(path: '/shopping/instacart-link', payload: payload);
      return ShoppingLinkResult(
        provider: provider,
        checkoutUri: Uri.parse((response['checkoutUrl'] as String?) ?? 'https://www.instacart.com/store'),
        message: (response['message'] as String?) ?? 'Shopping handoff ready in Instacart.',
        itemUris: const [],
      );
    } on PantryGatewayException catch (error) {
      throw StateError(error.userMessage);
    }
  }
}
