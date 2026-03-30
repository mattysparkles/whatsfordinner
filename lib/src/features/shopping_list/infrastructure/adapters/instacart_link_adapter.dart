import '../../../../core/models/app_models.dart';
import '../../domain/shopping_services.dart';
import 'shopping_link_mapper.dart';

enum InstacartRequestType { recipePage, shoppingListPage }

class InstacartLinkAdapter implements InstacartProviderAdapter {
  InstacartLinkAdapter({Map<String, Uri>? urlCache}) : _urlCache = urlCache ?? <String, Uri>{};

  static const _base = 'https://www.instacart.com/store';
  final Map<String, Uri> _urlCache;

  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'instacart',
        name: 'Instacart',
        capabilityLabel: ProviderCapabilityLabel.active,
        supportsAffiliateTracking: true,
        notes: 'Opens an Instacart-hosted page with your recipe/list prefilled. Checkout continues in Instacart.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final requestType = _requestTypeFor(list);
    final cacheKey = '${requestType.name}:${stableListFingerprint(list)}';
    final hostedUrl = _urlCache.putIfAbsent(cacheKey, () => _buildHostedUrl(list, requestType));

    return ShoppingLinkResult(
      provider: provider,
      checkoutUri: hostedUrl,
      message: requestType == InstacartRequestType.recipePage
          ? 'Recipe handoff ready in Instacart. Review and complete checkout there.'
          : 'Shopping list handoff ready in Instacart. Review and complete checkout there.',
      itemUris: const [],
    );
  }

  InstacartRequestType _requestTypeFor(ShoppingList list) {
    if (list.recipeTitle != null && list.recipeTitle!.trim().isNotEmpty) {
      return InstacartRequestType.recipePage;
    }
    return InstacartRequestType.shoppingListPage;
  }

  Uri _buildHostedUrl(ShoppingList list, InstacartRequestType type) {
    final items = list.items.map(formatItemForProvider).toList(growable: false);
    if (type == InstacartRequestType.recipePage) {
      return Uri.parse('$_base/s?k=${Uri.encodeQueryComponent(list.recipeTitle!)}');
    }

    final combined = items.join(', ');
    return Uri.parse('$_base/s?k=${Uri.encodeQueryComponent(combined)}');
  }
}
