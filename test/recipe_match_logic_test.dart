import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/infrastructure/mock/mock_services.dart';

void main() {
  test('recipe total minutes is prep + cook', () {
    const recipe = RecipeSuggestion(
      id: '1',
      title: 'Test',
      shortDescription: 'desc',
      matchType: RecipeMatchType.exact,
      prepMinutes: 12,
      cookMinutes: 18,
      difficulty: 1,
      familyFriendlyScore: 4,
      healthScore: 4,
      fancyScore: 1,
      servings: 2,
      dietaryTags: [],
      requirements: [],
      missingIngredients: [],
      availableIngredients: [],
      steps: [],
      suggestedPairings: [],
      explanation: RecipeExplanation(summary: 'why', pantryHighlights: []),
    );

    expect(recipe.totalMinutes, 30);
  });

  test('mock matching yields exact when all ingredients are present', () async {
    final service = MockRecipeSuggestionService();
    final suggestions = await service.suggestRecipes(
      pantryItems: const [
        PantryItem(id: '1', name: 'pasta'),
        PantryItem(id: '2', name: 'tomatoes'),
        PantryItem(id: '3', name: 'garlic'),
      ],
      mealType: MealType.dinner,
      preferences: const UserPreferences(),
      servings: 2,
    );

    final pasta = suggestions.firstWhere((recipe) => recipe.id == 'recipe-pasta');
    expect(pasta.matchType, RecipeMatchType.exact);
    expect(pasta.missingIngredients, isEmpty);
  });

  test('mock matching yields near match when one ingredient missing', () async {
    final service = MockRecipeSuggestionService();
    final suggestions = await service.suggestRecipes(
      pantryItems: const [
        PantryItem(id: '1', name: 'pasta'),
        PantryItem(id: '2', name: 'tomatoes'),
      ],
      mealType: MealType.dinner,
      preferences: const UserPreferences(),
      servings: 4,
    );

    final pasta = suggestions.firstWhere((recipe) => recipe.id == 'recipe-pasta');
    expect(pasta.matchType, RecipeMatchType.nearMatch);
    expect(pasta.missingIngredients.length, 1);
    expect(pasta.servings, 4);
  });
}
