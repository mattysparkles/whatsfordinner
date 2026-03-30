import '../models/app_models.dart';

abstract interface class RecipeService {
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
  });
}
