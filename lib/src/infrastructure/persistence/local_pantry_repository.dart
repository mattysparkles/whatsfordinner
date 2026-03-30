import 'dart:convert';

import '../../core/repositories/pantry_repository.dart';
import '../../core/services/local_persistence_service.dart';
import '../../domain/models/models.dart';
import '../../infrastructure/persistence/hive_local_persistence.dart';

class LocalPantryRepository implements PantryRepository {
  LocalPantryRepository({LocalPersistenceService? persistence})
      : _persistence = persistence ?? HiveLocalPersistence.instance;

  static const _storageKey = 'pantry_inventory_v1';
  final LocalPersistenceService _persistence;

  @override
  Future<void> deleteById(String id) async {
    final allItems = await fetchAll();
    final next = allItems.where((item) => item.id != id).toList(growable: false);
    await saveAll(next);
  }

  @override
  Future<String> exportToJson() async {
    final items = await fetchAll();
    return jsonEncode(items.map((item) => item.toJson()).toList(growable: false));
  }

  @override
  Future<List<PantryItem>> fetchAll() async {
    final raw = await _persistence.readString(_storageKey);
    if (raw == null || raw.isEmpty) {
      final seed = _seedData();
      await saveAll(seed);
      return seed;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => PantryItem.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      final seed = _seedData();
      await saveAll(seed);
      return seed;
    }
  }

  @override
  Future<void> importFromJson(String json) async {
    final decoded = jsonDecode(json) as List<dynamic>;
    final items = decoded
        .map((entry) => PantryItem.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    await saveAll(items);
  }

  @override
  Future<void> saveAll(List<PantryItem> items) async {
    await _persistence.writeString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<void> upsert(PantryItem item) async {
    final allItems = await fetchAll();
    final index = allItems.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      await saveAll([...allItems, item]);
      return;
    }
    final updated = [...allItems]..[index] = item;
    await saveAll(updated);
  }

  List<PantryItem> _seedData() {
    return const [
      PantryItem(
        id: 'seed-rice',
        ingredient: Ingredient(id: 'ing-rice', name: 'Rice', category: IngredientCategory.grainsBread),
        quantityInfo: QuantityInfo(amount: 2, unit: 'cups'),
        freshnessState: FreshnessState.fresh,
        sourceType: PantrySourceType.manual,
      ),
      PantryItem(
        id: 'seed-black-beans',
        ingredient: Ingredient(
          id: 'ing-black-beans',
          name: 'Black beans',
          category: IngredientCategory.cannedJarred,
        ),
        quantityInfo: QuantityInfo(amount: 2, unit: 'cans'),
        sourceType: PantrySourceType.pantryPhoto,
        confidence: 0.88,
      ),
      PantryItem(
        id: 'seed-eggs',
        ingredient: Ingredient(id: 'ing-eggs', name: 'Eggs', category: IngredientCategory.dairy),
        quantityInfo: QuantityInfo(amount: 12, unit: 'count'),
        freshnessState: FreshnessState.useSoon,
        sourceType: PantrySourceType.fridgePhoto,
        confidence: 0.81,
      ),
      PantryItem(
        id: 'seed-garlic',
        ingredient: Ingredient(id: 'ing-garlic', name: 'Garlic', category: IngredientCategory.produce),
        quantityInfo: QuantityInfo(),
        sourceType: PantrySourceType.manual,
      ),
    ];
  }
}
