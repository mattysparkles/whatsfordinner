import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/core/services/local_persistence_service.dart';
import 'package:pantry_pilot/src/features/meal_planning/domain/meal_planning_controller.dart';

class _FakePersistence implements LocalPersistenceService {
  final Map<String, String> cache = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> readString(String key) async => cache[key];

  @override
  Future<void> writeString(String key, String value) async {
    cache[key] = value;
  }
}

RecipeSuggestion _recipe({required String id, required String title, List<MissingIngredient> missing = const []}) {
  return RecipeSuggestion(
    id: id,
    title: title,
    shortDescription: 'desc',
    matchType: RecipeMatchType.nearMatch,
    prepMinutes: 10,
    cookMinutes: 10,
    difficulty: 2,
    familyFriendlyScore: 4,
    healthScore: 3,
    fancyScore: 2,
    servings: 2,
    dietaryTags: const [],
    requirements: const [],
    missingIngredients: missing,
    availableIngredients: const [],
    steps: const [],
    suggestedPairings: const [],
    explanation: const RecipeExplanation(summary: 'why', pantryHighlights: []),
  );
}

void main() {
  test('assigning entries and generating plan shopping list aggregates ingredients', () async {
    final controller = MealPlanningController(_FakePersistence());
    await Future<void>.delayed(Duration.zero);

    final pasta = _recipe(
      id: 'pasta',
      title: 'Pasta',
      missing: const [
        MissingIngredient(ingredientName: 'Onion', shortageAmount: 1, unit: 'count'),
        MissingIngredient(ingredientName: 'Milk', shortageAmount: 1, unit: 'cup'),
      ],
    );
    final soup = _recipe(
      id: 'soup',
      title: 'Soup',
      missing: const [
        MissingIngredient(ingredientName: 'Onion', shortageAmount: 2, unit: 'count'),
      ],
    );

    await controller.assignRecipe(date: DateTime(2026, 4, 1), recipe: pasta, sourceLabel: 'suggestion');
    await controller.assignRecipe(date: DateTime(2026, 4, 2), recipe: soup, sourceLabel: 'saved');

    final shopping = controller.generateShoppingListFromPlan(recipes: [pasta, soup]);
    expect(controller.state.entries.length, 2);
    expect(shopping.items.length, 2);
    final onion = shopping.items.firstWhere((item) => item.ingredientName == 'Onion');
    expect(onion.quantity, 3);
  });

  test('history and reused plans are tracked', () async {
    final controller = MealPlanningController(_FakePersistence());
    await Future<void>.delayed(Duration.zero);

    final recipe = _recipe(id: 'r', title: 'Recipe');
    await controller.assignRecipe(date: DateTime(2026, 4, 4), recipe: recipe, sourceLabel: 'saved');
    await controller.commitCurrentPlan(label: 'Weekend plan');

    expect(controller.state.planHistory, isNotEmpty);
    final plan = controller.state.planHistory.first;
    await controller.markPlanReused(plan);
    expect(controller.state.recentlyReused.first.id, plan.id);
  });
}
