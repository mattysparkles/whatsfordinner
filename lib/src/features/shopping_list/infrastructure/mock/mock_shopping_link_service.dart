import 'dart:math';

import '../../../../core/models/app_models.dart';
import '../../domain/shopping_services.dart';

class MockShoppingLinkService implements ShoppingLinkService {
  MockShoppingLinkService({
    InstacartProviderAdapter? instacart,
    AmazonProviderAdapter? amazon,
    WebFallbackProviderAdapter? web,
  }) : _adapters = [
          instacart ?? MockInstacartAdapter(),
          amazon ?? MockAmazonAdapter(),
          web ?? MockWebFallbackAdapter(),
        ];

  final List<ShoppingProviderAdapter> _adapters;

  @override
  Future<List<ShoppingLinkResult>> buildLinks({
    required ShoppingList list,
    required List<CommerceProvider> providers,
  }) async {
    final requested = providers.map((provider) => provider.id).toSet();
    final matches = _adapters.where((adapter) => requested.contains(adapter.provider.id));
    return Future.wait(matches.map((adapter) => adapter.buildLink(list)));
  }
}

class MockInstacartAdapter implements InstacartProviderAdapter {
  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'instacart',
        name: 'Instacart',
        capabilityLabel: ProviderCapabilityLabel.availableNow,
        supportsAffiliateTracking: true,
        notes: 'Mock checkout handoff only; no direct account sync in MVP.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final query = Uri.encodeComponent(list.items.map((item) => item.ingredientName).join(','));
    return ShoppingLinkResult(
      provider: provider,
      checkoutUri: Uri.parse('https://www.instacart.com/store/s?k=$query'),
      message: 'Open Instacart search with your list prefilled terms.',
      itemUris: const [],
    );
  }
}

class MockAmazonAdapter implements AmazonProviderAdapter {
  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'amazon',
        name: 'Amazon',
        capabilityLabel: ProviderCapabilityLabel.availableNow,
        supportsAffiliateTracking: true,
        notes: 'Generates product search links; affiliate tags can be appended later.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final random = Random(list.items.length);
    final links = list.items
        .map(
          (item) => Uri.parse(
            'https://www.amazon.com/s?k=${Uri.encodeComponent(item.ingredientName)}&tag=pantrypilot-${random.nextInt(99).toString().padLeft(2, '0')}',
          ),
        )
        .toList(growable: false);

    return ShoppingLinkResult(
      provider: provider,
      checkoutUri: null,
      itemUris: links,
      message: 'Open item-level Amazon product searches.',
    );
  }
}

class MockWebFallbackAdapter implements WebFallbackProviderAdapter {
  @override
  CommerceProvider get provider => const CommerceProvider(
        id: 'web-fallback',
        name: 'Web Search',
        capabilityLabel: ProviderCapabilityLabel.comingLater,
        supportsAffiliateTracking: false,
        notes: 'Generic fallback is planned and intentionally not launched yet.',
      );

  @override
  Future<ShoppingLinkResult> buildLink(ShoppingList list) async {
    final query = Uri.encodeComponent('grocery delivery ${list.items.map((item) => item.ingredientName).join(' ')}');
    return ShoppingLinkResult(
      provider: provider,
      checkoutUri: Uri.parse('https://www.google.com/search?q=$query'),
      itemUris: const [],
      message: 'Coming later: broader provider matching and ranking.',
      canOpenNow: false,
    );
  }
}
