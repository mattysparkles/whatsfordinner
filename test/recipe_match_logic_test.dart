import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';

void main() {
  test('recipe total minutes is prep + cook', () {
    const recipe = RecipeSuggestion(
      id: '1',
      title: 'Test',
      description: 'desc',
      matchType: RecipeMatchType.exact,
      confidence: 1,
      whySuggested: 'fit',
      mealType: MealType.dinner,
      prepMinutes: 12,
      cookMinutes: 18,
      servings: 2,
      requirements: [],
      availableIngredients: [],
      missingIngredients: [],
      substitutions: {},
      steps: [],
    );

    expect(recipe.totalMinutes, 30);
  });
}
