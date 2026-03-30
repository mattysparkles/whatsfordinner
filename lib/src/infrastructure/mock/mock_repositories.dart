import '../../core/models/app_models.dart';
import '../../core/repositories/favorites_repository.dart';
import '../../core/repositories/pantry_repository.dart';
import '../../core/repositories/preferences_repository.dart';

class InMemoryPantryRepository implements PantryRepository {
  List<PantryItem> _items = const [
    PantryItem(id: 'item-1', name: 'pasta', quantity: 1, unit: 'box'),
    PantryItem(id: 'item-2', name: 'tomato', quantity: 2, unit: 'can'),
  ];

  @override
  Future<List<PantryItem>> fetchAll() async => _items;

  @override
  Future<void> saveAll(List<PantryItem> items) async {
    _items = items;
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

  @override
  Future<List<SavedRecipe>> fetchSaved() async => _saved;

  @override
  Future<void> saveRecipe(String recipeId) async {
    _saved.add(SavedRecipe(recipeId: recipeId, savedAt: DateTime.now()));
  }
}
