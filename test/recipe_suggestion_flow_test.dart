import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart' as core;
import 'package:pantry_pilot/src/core/services/recipe_service.dart';
import 'package:pantry_pilot/src/infrastructure/mock/mock_repositories.dart';

class _DeterministicRecipeService implements RecipeSuggestionService {
  @override
  Future<List<core.RecipeSuggestion>> suggestRecipes({
    required List<core.PantryItem> pantryItems,
    required core.MealType mealType,
    required core.UserPreferences preferences,
    required int servings,
  }) async {
    return const [
      core.RecipeSuggestion(
        id: 'slow',
        title: 'Slow stew',
        shortDescription: 'Long cook',
        matchType: core.RecipeMatchType.nearMatch,
        prepMinutes: 20,
        cookMinutes: 40,
        difficulty: 3,
        familyFriendlyScore: 2,
        healthScore: 2,
        fancyScore: 1,
        servings: 2,
        dietaryTags: [],
        requirements: [],
        missingIngredients: [],
        availableIngredients: [],
        steps: [],
        suggestedPairings: [],
        explanation: core.RecipeExplanation(summary: 'mock', pantryHighlights: []),
      ),
      core.RecipeSuggestion(
        id: 'fast',
        title: 'Fast pasta',
        shortDescription: 'Quick cook',
        matchType: core.RecipeMatchType.exact,
        prepMinutes: 5,
        cookMinutes: 10,
        difficulty: 1,
        familyFriendlyScore: 5,
        healthScore: 4,
        fancyScore: 2,
        servings: 2,
        dietaryTags: [],
        requirements: [],
        missingIngredients: [],
        availableIngredients: [],
        steps: [],
        suggestedPairings: [],
        explanation: core.RecipeExplanation(summary: 'mock', pantryHighlights: []),
      ),
    ];
  }
}

void main() {
  test('recipe suggestion flow returns sorted results by fastest', () async {
    final container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(InMemoryPantryRepository()),
        preferencesRepositoryProvider.overrideWithValue(InMemoryPreferencesRepository()),
        recipeServiceProvider.overrideWithValue(_DeterministicRecipeService()),
      ],
    );
    addTearDown(container.dispose);

    final recipes = await container.read(recipeSuggestionsProvider.future);

    expect(recipes.first.id, 'fast');
    expect(recipes.last.id, 'slow');
  });
}
