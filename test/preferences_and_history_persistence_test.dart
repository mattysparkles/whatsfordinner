import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/core/services/local_persistence_service.dart';
import 'package:pantry_pilot/src/infrastructure/persistence/local_favorites_repository.dart';
import 'package:pantry_pilot/src/infrastructure/persistence/local_preferences_repository.dart';

class _FakePersistence implements LocalPersistenceService {
  final Map<String, String> _cache = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> readString(String key) async => _cache[key];

  @override
  Future<void> writeString(String key, String value) async {
    _cache[key] = value;
  }
}

RecipeSuggestion _recipe({required String id, required String title, bool freestyle = false}) {
  return RecipeSuggestion(
    id: id,
    title: title,
    shortDescription: 'desc',
    matchType: RecipeMatchType.exact,
    prepMinutes: 10,
    cookMinutes: 10,
    difficulty: 1,
    familyFriendlyScore: 5,
    healthScore: 5,
    fancyScore: 2,
    servings: 2,
    dietaryTags: const [],
    requirements: const [],
    missingIngredients: const [],
    availableIngredients: const [],
    steps: const [CookingStep(order: 1, instruction: 'Cook')],
    suggestedPairings: const [],
    explanation: const RecipeExplanation(summary: 'summary', pantryHighlights: []),
    isPantryFreestyle: freestyle,
  );
}

void main() {
  test('preferences persist and round-trip with new fields', () async {
    final persistence = _FakePersistence();
    final repo = LocalPreferencesRepository(persistence);

    final prefs = const UserPreferences(
      dietaryFilters: ['Vegan'],
      allergies: ['Peanuts'],
      aversions: ['Mushrooms'],
      cookingSkillLevel: CookingSkillLevel.intermediate,
      preferredMealTypes: [MealType.dinner, MealType.lunch],
      householdSize: 4,
      leftoverPreference: LeftoverPreference.loveLeftovers,
      lowSodium: true,
      lowSugar: true,
      lowerCalorie: false,
    );

    await repo.save(prefs);
    final loaded = await repo.fetch();

    expect(loaded.dietaryFilters, ['Vegan']);
    expect(loaded.allergies, ['Peanuts']);
    expect(loaded.aversions, ['Mushrooms']);
    expect(loaded.cookingSkillLevel, CookingSkillLevel.intermediate);
    expect(loaded.preferredMealTypes, [MealType.dinner, MealType.lunch]);
    expect(loaded.householdSize, 4);
    expect(loaded.leftoverPreference, LeftoverPreference.loveLeftovers);
    expect(loaded.lowSodium, isTrue);
    expect(loaded.lowSugar, isTrue);
    expect(loaded.lowerCalorie, isFalse);
  });

  test('favorites and history persist and preserve newest ordering', () async {
    final persistence = _FakePersistence();
    final repo = LocalFavoritesRepository(persistence);

    final recipeA = _recipe(id: 'a', title: 'A');
    final recipeB = _recipe(id: 'b', title: 'B', freestyle: true);

    await repo.saveRecipe(recipeA);
    await repo.saveRecipe(recipeB);
    await repo.addHistoryEvent(
      HistoryEvent(
        type: HistoryEventType.viewedRecipe,
        occurredAt: DateTime(2026, 3, 30, 12, 0),
        recipeId: recipeA.id,
        recipeTitle: recipeA.title,
      ),
    );
    await repo.addHistoryEvent(
      HistoryEvent(
        type: HistoryEventType.completedCookMode,
        occurredAt: DateTime(2026, 3, 30, 12, 1),
        recipeId: recipeB.id,
        recipeTitle: recipeB.title,
        isPantryFreestyle: true,
      ),
    );

    final saved = await repo.fetchSaved();
    final history = await repo.fetchHistory();

    expect(saved.first.recipeId, 'b');
    expect(saved.first.isPantryFreestyle, isTrue);
    expect(history.first.type, HistoryEventType.completedCookMode);
    expect(history.first.recipeTitle, 'B');
  });

  test('history tracker deduplicates same event in short window', () async {
    final persistence = _FakePersistence();
    final controller = FavoritesHistoryController(LocalFavoritesRepository(persistence));
    final freestyle = _recipe(id: 'x', title: 'Freestyle', freestyle: true);

    await controller.trackEvent(type: HistoryEventType.generatedFreestyleIdea, recipe: freestyle);
    await controller.trackEvent(type: HistoryEventType.generatedFreestyleIdea, recipe: freestyle);

    expect(controller.state.history.where((item) => item.type == HistoryEventType.generatedFreestyleIdea).length, 1);
  });
}
