import '../models/app_models.dart';

abstract interface class RecipeSuggestionService {
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
    required int servings,
  });
}
