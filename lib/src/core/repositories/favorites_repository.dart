import '../models/app_models.dart';

abstract interface class FavoritesRepository {
  Future<List<SavedRecipe>> fetchSaved();
  Future<void> saveRecipe(RecipeSuggestion recipe);
  Future<void> removeRecipe(String recipeId);
  Future<List<HistoryEvent>> fetchHistory();
  Future<void> addHistoryEvent(HistoryEvent event);
}
