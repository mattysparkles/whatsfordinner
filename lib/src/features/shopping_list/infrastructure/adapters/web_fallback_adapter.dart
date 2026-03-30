import '../../../../core/models/app_models.dart';
import '../../domain/shopping_services.dart';

class WebFallbackAdapter implements WebFallbackProviderAdapter {
  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'web-fallback',
        name: 'Web Search',
        capabilityLabel: ProviderCapabilityLabel.comingLater,
        supportsAffiliateTracking: false,
        notes: 'Planned fallback when no dedicated grocery partner is available.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final query = Uri.encodeComponent('grocery delivery ${list.items.map((item) => item.ingredientName).join(' ')}');
    return ShoppingLinkResult(
      provider: provider,
      checkoutUri: Uri.parse('https://www.google.com/search?q=$query'),
      itemUris: const [],
      message: 'Fallback provider is coming later.',
      canOpenNow: false,
    );
  }
}
