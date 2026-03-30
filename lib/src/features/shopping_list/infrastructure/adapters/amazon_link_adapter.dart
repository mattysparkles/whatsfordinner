import '../../../../core/models/app_models.dart';
import '../../domain/shopping_services.dart';
import 'shopping_link_mapper.dart';

class AmazonLinkAdapter implements AmazonProviderAdapter {
  AmazonLinkAdapter({this.affiliateTag = 'pantrypilot-20'});

  final String affiliateTag;

  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'amazon',
        name: 'Amazon',
        capabilityLabel: ProviderCapabilityLabel.active,
        supportsAffiliateTracking: true,
        notes: 'Opens Amazon search results per item. Purchases happen in Amazon.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final links = list.items
        .map(
          (item) => Uri.https('www.amazon.com', '/s', {
            'k': formatItemForProvider(item),
            'tag': affiliateTag,
          }),
        )
        .toList(growable: false);

    return ShoppingLinkResult(
      provider: provider,
      itemUris: links,
      message: 'Item-level Amazon searches are ready. Verify product sizes before purchase.',
    );
  }
}
