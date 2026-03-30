import 'package:uuid/uuid.dart';

import '../../core/models/app_models.dart';
import '../../core/services/recipe_service.dart';
import '../../core/services/vision_service.dart';

class MockVisionService implements VisionService {
  @override
  Future<List<ParsedIngredient>> parseCapturedSources(List<String> sourcePaths) async {
    return const [
      ParsedIngredient(rawText: '2x tomato cans', normalizedName: 'tomato', confidence: 0.86),
      ParsedIngredient(rawText: 'pasta box', normalizedName: 'pasta', confidence: 0.94),
      ParsedIngredient(rawText: 'garlic bulb', normalizedName: 'garlic', confidence: 0.91),
    ];
  }
}

class MockRecipeService implements RecipeService {
  @override
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
  }) async {
    return [
      const RecipeSuggestion(
        id: 'recipe-1',
        title: '15-Min Pantry Pasta',
        matchType: RecipeMatchType.exact,
        prepMinutes: 5,
        cookMinutes: 10,
        reason: 'Exact pantry match for pasta night.',
      ),
      const RecipeSuggestion(
        id: 'recipe-2',
        title: 'One-Skillet Veggie Hash',
        matchType: RecipeMatchType.nearMatch,
        prepMinutes: 10,
        cookMinutes: 18,
        reason: 'Only one ingredient missing.',
      ),
      RecipeSuggestion(
        id: const Uuid().v4(),
        title: 'Pantry Freestyle Wraps',
        matchType: RecipeMatchType.pantryFreestyle,
        prepMinutes: 8,
        cookMinutes: 0,
        reason: 'AI-composed from current pantry profile.',
      ),
    ];
  }
}
