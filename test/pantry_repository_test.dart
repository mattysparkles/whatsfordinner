import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/services/local_persistence_service.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';
import 'package:pantry_pilot/src/infrastructure/persistence/local_pantry_repository.dart';

class _FakePersistenceService implements LocalPersistenceService {
  final Map<String, String> _cache = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> readString(String key) async => _cache[key];

  @override
  Future<void> writeString(String key, String value) async {
    _cache[key] = value;
  }
}

void main() {
  test('local pantry repository seeds demo data for empty storage', () async {
    final repo = LocalPantryRepository(persistence: _FakePersistenceService());

    final items = await repo.fetchAll();

    expect(items, isNotEmpty);
    expect(items.first.ingredient.name, isNotEmpty);
  });

  test('local pantry repository supports export and import placeholders', () async {
    final repo = LocalPantryRepository(persistence: _FakePersistenceService());
    final exported = await repo.exportToJson();

    await repo.importFromJson(exported);
    final items = await repo.fetchAll();

    expect(items.length, greaterThan(0));
  });

  test('upsert and deleteById mutate inventory', () async {
    final repo = LocalPantryRepository(persistence: _FakePersistenceService());
    const item = PantryItem(
      id: 'custom-id',
      ingredient: Ingredient(id: 'ingredient-id', name: 'Flour', category: IngredientCategory.baking),
      quantityInfo: QuantityInfo(amount: 1, unit: 'bag'),
    );

    await repo.upsert(item);
    await repo.deleteById('custom-id');
    final items = await repo.fetchAll();

    expect(items.any((entry) => entry.id == 'custom-id'), isFalse);
  });
}
