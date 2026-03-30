import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/features/shopping_list/domain/shopping_list_controller.dart';

void main() {
  test('shopping list generation flow groups and edits missing ingredients', () {
    final controller = ShoppingListController(
      providers: const [
        CommerceProvider(
          id: 'instacart',
          name: 'Instacart',
          capabilityLabel: ProviderCapabilityLabel.active,
        ),
      ],
    );

    const recipe = RecipeSuggestion(
      id: 'recipe-1',
      title: 'Weeknight pasta',
      shortDescription: 'Simple pasta',
      matchType: RecipeMatchType.nearMatch,
      prepMinutes: 10,
      cookMinutes: 15,
      difficulty: 1,
      familyFriendlyScore: 4,
      healthScore: 3,
      fancyScore: 1,
      servings: 2,
      dietaryTags: [],
      requirements: [],
      missingIngredients: [
        MissingIngredient(
          ingredientName: 'Onion',
          shortageAmount: 1,
          unit: 'count',
          suggestedSubstitutions: ['shallot'],
        ),
        MissingIngredient(ingredientName: 'Onion', shortageAmount: 0.5, unit: 'count'),
        MissingIngredient(ingredientName: 'Milk', shortageAmount: 1, unit: 'cup'),
      ],
      availableIngredients: [],
      steps: [],
      suggestedPairings: [],
      explanation: RecipeExplanation(summary: 'mock', pantryHighlights: []),
    );

    controller.createFromRecipe(recipe);

    final list = controller.state.list!;
    expect(list.items.length, 2);
    expect(controller.state.groupedItems.keys, containsAll(['Produce', 'Dairy & Eggs']));

    final onion = list.items.firstWhere((item) => item.ingredientName == 'Onion');
    expect(onion.quantity, 1.5);
    expect(onion.note, contains('shallot'));
    controller.toggleChecked(onion.id);
    controller.updateQuantity(onion.id, '2');
    controller.updateNotes(onion.id, 'yellow preferred');

    final updated = controller.state.list!.items.firstWhere((item) => item.id == onion.id);
    expect(updated.isChecked, isTrue);
    expect(updated.quantity, 2);
    expect(updated.note, 'yellow preferred');
  });

  test('meal-plan shopping aggregation merges duplicates across recipes', () {
    final controller = ShoppingListController(providers: const []);
    const base = RecipeExplanation(summary: 'mock', pantryHighlights: []);

    const recipeA = RecipeSuggestion(
      id: 'a',
      title: 'A',
      shortDescription: 'a',
      matchType: RecipeMatchType.nearMatch,
      prepMinutes: 10,
      cookMinutes: 10,
      difficulty: 2,
      familyFriendlyScore: 3,
      healthScore: 3,
      fancyScore: 2,
      servings: 2,
      dietaryTags: [],
      requirements: [],
      missingIngredients: [
        MissingIngredient(ingredientName: 'Onion', shortageAmount: 1, unit: 'count'),
        MissingIngredient(ingredientName: 'Milk', shortageAmount: 1, unit: 'cup'),
      ],
      availableIngredients: [],
      steps: [],
      suggestedPairings: [],
      explanation: base,
    );
    const recipeB = RecipeSuggestion(
      id: 'b',
      title: 'B',
      shortDescription: 'b',
      matchType: RecipeMatchType.nearMatch,
      prepMinutes: 10,
      cookMinutes: 10,
      difficulty: 2,
      familyFriendlyScore: 3,
      healthScore: 3,
      fancyScore: 2,
      servings: 2,
      dietaryTags: [],
      requirements: [],
      missingIngredients: [
        MissingIngredient(ingredientName: 'Onion', shortageAmount: 2, unit: 'count'),
      ],
      availableIngredients: [],
      steps: [],
      suggestedPairings: [],
      explanation: base,
    );

    controller.createFromMealPlan(title: 'Weekly list', recipes: const [recipeA, recipeB]);

    final list = controller.state.list;
    expect(list, isNotNull);
    expect(list!.items.length, 2);
    final onion = list.items.firstWhere((item) => item.ingredientName == 'Onion');
    expect(onion.quantity, 3);
  });
}
