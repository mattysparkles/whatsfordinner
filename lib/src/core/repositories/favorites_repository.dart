import '../models/app_models.dart';

abstract interface class FavoritesRepository {
  Future<List<SavedRecipe>> fetchSaved();
  Future<void> saveRecipe(String recipeId);
}
