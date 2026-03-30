import '../models/models.dart';

abstract class PantryRepository {
  Future<List<PantryItem>> getItems();
  Future<void> saveItems(List<PantryItem> items);
}

abstract class FavoritesRepository {
  Future<List<SavedRecipe>> getSavedRecipes();
  Future<void> saveRecipe(RecipeSuggestion recipe);
}

abstract class PreferencesRepository {
  Future<UserPreferences> getPreferences();
  Future<void> savePreferences(UserPreferences preferences);
}
