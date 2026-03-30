import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/features/shopping_list/infrastructure/adapters/amazon_link_adapter.dart';
import 'package:pantry_pilot/src/features/shopping_list/infrastructure/adapters/instacart_link_adapter.dart';
import 'package:pantry_pilot/src/features/shopping_list/infrastructure/adapters/shopping_link_service_impl.dart';

void main() {
  ShoppingList buildList() => ShoppingList(
        id: 'list-1',
        title: 'Demo list',
        createdAt: DateTime(2026, 3, 30),
        recipeTitle: 'Lemon Chicken',
        items: const [
          ShoppingListItem(
            id: '1',
            ingredientName: 'Chicken breast',
            groupLabel: 'Protein',
            quantity: 2,
            unit: 'lb',
            note: 'boneless',
          ),
          ShoppingListItem(
            id: '2',
            ingredientName: 'Lemon',
            groupLabel: 'Produce',
            quantity: 3,
            unit: 'count',
          ),
        ],
      );

  test('instacart adapter creates hosted URL and caches by request fingerprint', () async {
    final adapter = InstacartLinkAdapter();
    final list = buildList();

    final first = await adapter.buildLink(list);
    final second = await adapter.buildLink(list);

    expect(first.checkoutUri, isNotNull);
    expect(first.checkoutUri.toString(), contains('instacart.com'));
    expect(first.checkoutUri, equals(second.checkoutUri));
  });

  test('amazon adapter preserves quantities and notes in item search links', () async {
    final adapter = AmazonLinkAdapter(affiliateTag: 'pantrypilot-20');

    final result = await adapter.buildLink(buildList());

    expect(result.itemUris, isNotEmpty);
    final chickenQuery = result.itemUris.first.toString();
    expect(chickenQuery, contains('2+lb+Chicken+breast+(boneless)'));
    expect(chickenQuery, contains('tag=pantrypilot-20'));
  });

  test('service maps requested providers only', () async {
    final instacart = InstacartLinkAdapter();
    final amazon = AmazonLinkAdapter();
    final service = ShoppingLinkServiceImpl(adapters: [instacart, amazon]);

    final result = await service.buildLinks(
      list: buildList(),
      providers: [amazon.provider],
    );

    expect(result.length, 1);
    expect(result.single.provider.id, 'amazon');
  });
}
