import '../../../core/models/app_models.dart';

abstract class ShoppingLinkService {
  Future<List<ShoppingLinkResult>> buildLinks({
    required ShoppingList list,
    required List<CommerceProvider> providers,
  });
}

abstract class ShoppingProviderAdapter {
  CommerceProvider get provider;

  Future<ShoppingLinkResult> buildLink(ShoppingList list);
}

abstract class InstacartProviderAdapter implements ShoppingProviderAdapter {}

abstract class AmazonProviderAdapter implements ShoppingProviderAdapter {}

abstract class WebFallbackProviderAdapter implements ShoppingProviderAdapter {}
