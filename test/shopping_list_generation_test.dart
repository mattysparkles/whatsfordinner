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
          capabilityLabel: ProviderCapabilityLabel.availableNow,
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
        MissingIngredient(ingredientName: 'Onion', shortageAmount: 1, unit: 'count'),
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
    controller.toggleChecked(onion.id);
    controller.updateQuantity(onion.id, '2');
    controller.updateNotes(onion.id, 'yellow preferred');

    final updated = controller.state.list!.items.firstWhere((item) => item.id == onion.id);
    expect(updated.isChecked, isTrue);
    expect(updated.quantity, 2);
    expect(updated.note, 'yellow preferred');
  });
}
