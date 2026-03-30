import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';

void main() {
  test('recipe total minutes is prep + cook', () {
    const recipe = RecipeSuggestion(
      id: '1',
      title: 'Test',
      matchType: RecipeMatchType.exact,
      prepMinutes: 12,
      cookMinutes: 18,
    );

    expect(recipe.totalMinutes, 30);
  });
}
