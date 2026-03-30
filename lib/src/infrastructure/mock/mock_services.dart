import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repository_interfaces.dart';
import '../../domain/services/service_interfaces.dart';

class MockVisionParsingService implements VisionParsingService {
  @override
  Future<List<ParsedIngredient>> parseImages(List<CapturedImage> images) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const [
      ParsedIngredient(rawText: '2x tomato cans', suggestedName: 'tomato', confidence: 0.81),
      ParsedIngredient(rawText: 'pasta box', suggestedName: 'pasta', confidence: 0.92),
      ParsedIngredient(rawText: 'green leafy?', suggestedName: 'spinach', confidence: 0.51),
    ];
  }
}

class MockIngredientNormalizationService implements IngredientNormalizationService {
  @override
  String normalize(String rawIngredient) => rawIngredient.trim().toLowerCase();
}

class MockRecipeSuggestionService implements RecipeSuggestionService {
  @override
  Future<List<RecipeSuggestion>> suggestRecipes({required List<PantryItem> pantry, required MealType mealType, required UserPreferences preferences}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return [
      RecipeSuggestion(
        id: const Uuid().v4(),
        title: '15-Min Pantry Pasta',
        description: 'Simple weeknight pasta with tomatoes and garlic.',
        matchType: RecipeMatchType.exact,
        confidence: 0.94,
        whySuggested: 'You have pasta, tomato, garlic, and olive oil already in pantry.',
        mealType: mealType,
        prepMinutes: 5,
        cookMinutes: 10,
        servings: preferences.preferredServings,
        requirements: const [
          RecipeIngredientRequirement(name: 'pasta', quantity: 1, unit: 'box'),
          RecipeIngredientRequirement(name: 'tomato', quantity: 2, unit: 'cups'),
        ],
        availableIngredients: const ['pasta', 'tomato', 'garlic'],
        missingIngredients: const [],
        substitutions: const {'parmesan': 'nutritional yeast'},
        steps: const [
          CookingStep(order: 1, instruction: 'Boil pasta in salted water.'),
          CookingStep(order: 2, instruction: 'Simmer tomato, garlic, and oil for 8 minutes.'),
          CookingStep(order: 3, instruction: 'Combine and serve warm.'),
        ],
        dietaryTags: const ['Vegetarian'],
      ),
      RecipeSuggestion(
        id: const Uuid().v4(),
        title: 'Cozy Skillet Hash',
        description: 'Near match one-pan hash with crisp veggies.',
        matchType: RecipeMatchType.nearMatch,
        confidence: 0.75,
        whySuggested: 'You have potatoes and onions; eggs are missing but optional.',
        mealType: mealType,
        prepMinutes: 10,
        cookMinutes: 20,
        servings: 4,
        requirements: const [RecipeIngredientRequirement(name: 'potato', quantity: 3, unit: 'whole')],
        availableIngredients: const ['potato', 'onion'],
        missingIngredients: const [MissingIngredient(name: 'egg', substitutions: ['silken tofu'])],
        substitutions: const {'egg': 'silken tofu scramble'},
        steps: const [CookingStep(order: 1, instruction: 'Pan fry potatoes until golden.')],
      ),
      RecipeSuggestion(
        id: const Uuid().v4(),
        title: 'AI Pantry Wrap Bites',
        description: 'Inventive no-cook wraps using what you have.',
        matchType: RecipeMatchType.aiInvention,
        confidence: 0.63,
        whySuggested: 'AI inferred compatible flavors from your pantry photos.',
        mealType: mealType,
        prepMinutes: 8,
        cookMinutes: 0,
        servings: 2,
        requirements: const [RecipeIngredientRequirement(name: 'tortilla', quantity: 4, unit: 'pieces')],
        availableIngredients: const ['beans'],
        missingIngredients: const [MissingIngredient(name: 'tortilla')],
        substitutions: const {'tortilla': 'lettuce cups'},
        steps: const [CookingStep(order: 1, instruction: 'Fill wraps and roll tightly.')],
        isAiCreated: true,
      ),
    ];
  }
}

class MockPairingSuggestionService implements PairingSuggestionService {
  @override
  Future<List<PairingSuggestion>> pairFor(RecipeSuggestion recipe) async =>
      const [PairingSuggestion(title: 'Citrus Sparkler', description: 'A bright non-alcoholic pairing.')];
}

class MockShoppingLinkService implements ShoppingLinkService {
  @override
  Future<Map<String, Uri>> buildLinks(List<MissingIngredient> items) async => {
        'instacart': Uri.parse('https://example.com/instacart-placeholder'),
        'amazon': Uri.parse('https://example.com/amazon-placeholder'),
        'delivery': Uri.parse('https://example.com/delivery-placeholder'),
      };
}

class MockTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

class MockSpeechCommandService implements SpeechCommandService {
  @override
  Stream<String> commandStream() => const Stream.empty();
}

class InMemoryPantryRepository implements PantryRepository {
  List<PantryItem> _items = [];

  @override
  Future<List<PantryItem>> getItems() async => _items;

  @override
  Future<void> saveItems(List<PantryItem> items) async {
    _items = items;
  }
}

class InMemoryFavoritesRepository implements FavoritesRepository {
  final List<SavedRecipe> _saved = [];

  @override
  Future<List<SavedRecipe>> getSavedRecipes() async => _saved;

  @override
  Future<void> saveRecipe(RecipeSuggestion recipe) async {
    _saved.add(SavedRecipe(recipe: recipe, savedAt: DateTime.now()));
  }
}

class InMemoryPreferencesRepository implements PreferencesRepository {
  UserPreferences _preferences = const UserPreferences(
    dietaryProfile: DietaryProfile(),
    householdProfile: HouseholdProfile(householdSize: 2, skillLevel: 'beginner'),
  );

  @override
  Future<UserPreferences> getPreferences() async => _preferences;

  @override
  Future<void> savePreferences(UserPreferences preferences) async {
    _preferences = preferences;
  }
}

class MockSubscriptionService implements SubscriptionService {
  SubscriptionState _state = const SubscriptionState(isPremium: false);

  @override
  Future<SubscriptionState> currentState() async => _state;

  @override
  Future<void> mockUpgrade() async {
    _state = const SubscriptionState(isPremium: true, tierName: 'premium');
  }
}

class MockAdService implements AdService {
  @override
  Future<List<AdPlacement>> placements() async => const [
        AdPlacement(id: 'home-banner', placement: 'home_banner', enabled: true),
        AdPlacement(id: 'results-native', placement: 'results_native', enabled: true),
      ];
}
