import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/core/repositories/pantry_repository.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';

class _MemoryPantryRepository implements PantryRepository {
  _MemoryPantryRepository(this._items);

  List<PantryItem> _items;

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
  test('pantry flow supports add, filter, edit, delete', () async {
    final controller = PantryController(_MemoryPantryRepository(const []));

    await controller.addOrUpdateItem(
      ingredientName: 'Milk',
      category: IngredientCategory.dairy,
      sourceType: PantrySourceType.manual,
    );
    await controller.addOrUpdateItem(
      ingredientName: 'Tomatoes',
      category: IngredientCategory.cannedJarred,
      sourceType: PantrySourceType.aiImport,
    );

    controller.setSearchQuery('mil');
    expect(controller.state.filteredItems.single.ingredient.name, 'Milk');

    controller.setSourceFilter(PantrySourceType.aiImport);
    expect(controller.state.filteredItems.single.ingredient.name, 'Tomatoes');

    final toEdit = controller.state.items.firstWhere((item) => item.ingredient.name == 'Tomatoes');
    await controller.addOrUpdateItem(
      id: toEdit.id,
      ingredientName: 'Diced Tomatoes',
      category: IngredientCategory.cannedJarred,
    );

    await controller.deleteItem(toEdit.id);
    expect(controller.state.items.any((item) => item.id == toEdit.id), isFalse);
  });
}
