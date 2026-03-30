import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/core/repositories/pantry_repository.dart';
import 'package:pantry_pilot/src/core/services/pantry_intelligence_service.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';

class _FakePantryRepository implements PantryRepository {
  List<PantryItem> _items;

  _FakePantryRepository(this._items);

  @override
  Future<void> deleteById(String id) async {
    _items = _items.where((item) => item.id != id).toList(growable: false);
  }

  @override
  Future<String> exportToJson() async => '[]';

  @override
  Future<List<PantryItem>> fetchAll() async => _items;

  @override
  Future<void> importFromJson(String json) async {}

  @override
  Future<void> saveAll(List<PantryItem> items) async {
    _items = items;
  }

  @override
  Future<void> upsert(PantryItem item) async {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      _items = [..._items, item];
      return;
    }
    _items = [..._items]..[index] = item;
  }
}

void main() {
  test('pantry controller can add update and delete items', () async {
    final repository = _FakePantryRepository(const []);
    final controller = PantryController(repository, const PantryIntelligenceService());
    await controller.load();

    await controller.addOrUpdateItem(
      ingredientName: 'Soy sauce',
      category: IngredientCategory.oilsCondiments,
      amount: 1,
      unit: 'bottle',
    );
    final added = controller.state.items.single;

    await controller.addOrUpdateItem(
      id: added.id,
      ingredientName: 'Low sodium soy sauce',
      category: IngredientCategory.oilsCondiments,
    );
    await controller.deleteItem(added.id);

    expect(controller.state.items, isEmpty);
  });

  test('pantry state filtering respects query/category/source', () {
    const itemA = PantryItem(
      id: '1',
      ingredient: Ingredient(id: 'i1', name: 'Milk', category: IngredientCategory.dairy),
      sourceType: PantrySourceType.manual,
    );
    const itemB = PantryItem(
      id: '2',
      ingredient: Ingredient(id: 'i2', name: 'Cumin', category: IngredientCategory.spicesSeasonings),
      sourceType: PantrySourceType.pantryPhoto,
    );

    final state = PantryState(
      items: const [itemA, itemB],
      searchQuery: 'mi',
      filters: const PantryFilters(category: IngredientCategory.dairy),
    );

    expect(state.filteredItems.map((item) => item.id), ['1']);
  });
}
