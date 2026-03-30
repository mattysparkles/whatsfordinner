import '../../../../core/models/app_models.dart';
import '../../domain/shopping_services.dart';

class ShoppingLinkServiceImpl implements ShoppingLinkService {
  ShoppingLinkServiceImpl({required List<ShoppingProviderAdapter> adapters}) : _adapters = adapters;

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
