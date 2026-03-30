import 'dart:convert';

import '../../core/models/app_models.dart';
import '../../core/repositories/favorites_repository.dart';
import '../../core/repositories/pantry_repository.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../domain/models/models.dart' as domain;

class InMemoryPantryRepository implements PantryRepository {
  List<domain.PantryItem> _items = [
    domain.PantryItem(
      id: 'item-1',
      ingredient: const domain.Ingredient(
        id: 'ingredient-pasta',
        name: 'Pasta',
        category: domain.IngredientCategory.grainsBread,
      ),
      quantityInfo: const domain.QuantityInfo(amount: 1, unit: 'box'),
    ),
    domain.PantryItem(
      id: 'item-2',
      ingredient: const domain.Ingredient(
        id: 'ingredient-tomato',
        name: 'Tomatoes',
        category: domain.IngredientCategory.cannedJarred,
      ),
      quantityInfo: const domain.QuantityInfo(amount: 2, unit: 'cans'),
      sourceType: domain.PantrySourceType.aiImport,
      confidence: 0.84,
    ),
  ];

  @override
  Future<List<domain.PantryItem>> fetchAll() async => _items;

  @override
  Future<void> upsert(domain.PantryItem item) async {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      _items = [..._items, item];
      return;
    }
    _items = [..._items]..[index] = item;
  }

  @override
  Future<void> deleteById(String id) async {
    _items = _items.where((item) => item.id != id).toList(growable: false);
  }

  @override
  Future<void> saveAll(List<domain.PantryItem> items) async {
    _items = items;
  }

  @override
  Future<String> exportToJson() async {
    return jsonEncode(_items.map((item) => item.toJson()).toList(growable: false));
  }

  @override
  Future<void> importFromJson(String json) async {
    final decoded = (jsonDecode(json) as List<dynamic>)
        .map((entry) => domain.PantryItem.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    _items = decoded;
  }
}

class InMemoryPreferencesRepository implements PreferencesRepository {
  UserPreferences _preferences = const UserPreferences();

  @override
  Future<UserPreferences> fetch() async => _preferences;

  @override
  Future<void> save(UserPreferences preferences) async {
    _preferences = preferences;
  }
}

class InMemoryFavoritesRepository implements FavoritesRepository {
  final List<SavedRecipe> _saved = [];
  final List<HistoryEvent> _history = [];

  @override
  Future<List<SavedRecipe>> fetchSaved() async => _saved;

  @override
  Future<void> saveRecipe(RecipeSuggestion recipe) async {
    _saved.add(SavedRecipe(recipeId: recipe.id, recipeTitle: recipe.title, savedAt: DateTime.now()));
  }

  @override
  Future<void> removeRecipe(String recipeId) async {
    _saved.removeWhere((item) => item.recipeId == recipeId);
  }

  @override
  Future<List<HistoryEvent>> fetchHistory() async => _history;

  @override
  Future<void> addHistoryEvent(HistoryEvent event) async {
    _history.insert(0, event);
  }
}
