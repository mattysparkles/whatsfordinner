import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/config/env_config.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/infrastructure/recipes/openai/openai_recipe_suggestion_service.dart';

void main() {
  group('PantryAnalysisEngine', () {
    test('classifies deterministic candidate as exact when all requirements are present', () {
      final engine = PantryAnalysisEngine();
      final analysis = engine.analyze(
        pantryItems: const [
          PantryItem(id: '1', name: 'pasta'),
          PantryItem(id: '2', name: 'tomatoes'),
          PantryItem(id: '3', name: 'garlic'),
          PantryItem(id: '4', name: 'olive oil'),
        ],
        mealType: MealType.dinner,
        preferences: const UserPreferences(dietaryFilters: ['vegetarian']),
        servings: 2,
      );

      expect(analysis.candidates, isNotEmpty);
      expect(analysis.candidates.first.classification, RecipeMatchType.exact);
      expect(analysis.candidates.first.available, containsAll(['pasta', 'tomatoes', 'garlic', 'olive oil']));
      expect(analysis.candidates.first.missing, isEmpty);
    });

    test('marks missing ingredient as substitutable when pantry has allowed substitute', () {
      final engine = PantryAnalysisEngine();
      final analysis = engine.analyze(
        pantryItems: const [
          PantryItem(id: '1', name: 'pasta'),
          PantryItem(id: '2', name: 'tomato sauce'),
          PantryItem(id: '3', name: 'garlic'),
          PantryItem(id: '4', name: 'butter'),
        ],
        mealType: MealType.dinner,
        preferences: const UserPreferences(dietaryFilters: ['vegetarian']),
        servings: 2,
      );

      expect(analysis.candidates.first.classification, RecipeMatchType.exact);
      expect(analysis.candidates.first.substitutable, containsAll(['tomatoes', 'olive oil']));
    });
  });

  group('OpenAiRecipeSuggestionService', () {
    test('maps structured response and labels freestyle suggestion', () async {
      final service = OpenAiRecipeSuggestionService(
        config: const EnvConfig(
          environment: AppEnvironment.dev,
          useMocks: false,
          gatewayApiBaseUrl: 'http://localhost:8000',
          recipeApiBaseUrl: 'https://api.openai.com/v1',
          visionApiBaseUrl: 'https://api.openai.com/v1',
          recipeApiKey: 'test-key',
          recipeCacheTtl: Duration(minutes: 10),
        ),
        apiClient: _FakeRecipeApiClient(
          payload: {
            'choices': [
              {
                'message': {
                  'content':
                      '{"suggestions":[{"title":"Pantry Bowl","description":"Great with what you have","matchType":"pantryFreestyle","servings":2,"prepMinutes":10,"cookMinutes":15,"difficulty":2,"familyFriendlyScore":4,"healthScore":4,"fancyScore":3,"requirements":[{"ingredient":"rice","amount":1,"unit":"cup","isAvailable":true,"availableAmount":1}],"missingIngredients":[],"steps":[{"order":1,"instruction":"Cook rice.","minutes":15}],"pairings":[{"title":"Tea","description":"Simple pairing"}],"explanation":"AI improvisation from pantry.","tags":["vegetarian"],"highlights":["rice"],"isAiFreestyle":true}]}'
                }
              }
            ]
          },
        ),
      );

      final results = await service.suggestRecipes(
        pantryItems: const [PantryItem(id: '1', name: 'rice')],
        mealType: MealType.lunch,
        preferences: const UserPreferences(),
        servings: 2,
      );

      expect(results, isNotEmpty);
      expect(results.first.title, 'Pantry Bowl');
      expect(results.first.matchType, RecipeMatchType.pantryFreestyle);
      expect(results.first.isPantryFreestyle, isTrue);
      expect(results.first.explanation.summary, contains('AI improvisation'));
    });

    test('returns cached results if API fails after successful call', () async {
      final client = _FlakyRecipeApiClient();
      var now = DateTime(2026, 3, 30, 10);
      final service = OpenAiRecipeSuggestionService(
        config: const EnvConfig(
          environment: AppEnvironment.dev,
          useMocks: false,
          gatewayApiBaseUrl: 'http://localhost:8000',
          recipeApiBaseUrl: 'https://api.openai.com/v1',
          visionApiBaseUrl: 'https://api.openai.com/v1',
          recipeApiKey: 'test-key',
          recipeCacheTtl: Duration(seconds: 1),
        ),
        apiClient: client,
        now: () => now,
      );

      final pantry = const [
        PantryItem(id: '1', name: 'pasta'),
        PantryItem(id: '2', name: 'tomatoes'),
        PantryItem(id: '3', name: 'garlic'),
        PantryItem(id: '4', name: 'olive oil'),
      ];

      final first = await service.suggestRecipes(
        pantryItems: pantry,
        mealType: MealType.dinner,
        preferences: const UserPreferences(dietaryFilters: ['vegetarian']),
        servings: 2,
      );

      now = now.add(const Duration(seconds: 5));
      client.failAll = true;
      final second = await service.suggestRecipes(
        pantryItems: pantry,
        mealType: MealType.dinner,
        preferences: const UserPreferences(dietaryFilters: ['vegetarian']),
        servings: 2,
      );

      expect(second.first.title, first.first.title);
    });
  });
}

class _FakeRecipeApiClient implements OpenAiRecipeApiClient {
  _FakeRecipeApiClient({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>> generateSuggestions(OpenAiRecipeRequest request) async => payload;
}

class _FlakyRecipeApiClient implements OpenAiRecipeApiClient {
  bool failAll = false;

  @override
  Future<Map<String, dynamic>> generateSuggestions(OpenAiRecipeRequest request) async {
    if (failAll) throw Exception('network down');
    return {
      'choices': [
        {
          'message': {
            'content':
                '{"suggestions":[{"title":"Reliable Pasta","description":"Reliable","matchType":"exact","servings":2,"prepMinutes":5,"cookMinutes":10,"difficulty":1,"familyFriendlyScore":5,"healthScore":3,"fancyScore":2,"requirements":[{"ingredient":"pasta","amount":1,"unit":"box","isAvailable":true,"availableAmount":1}],"missingIngredients":[],"steps":[{"order":1,"instruction":"Boil.","minutes":10}],"pairings":[],"explanation":"Deterministic match.","tags":["vegetarian"],"highlights":["pasta"],"isAiFreestyle":false}]}'
          }
        }
      ]
    };
  }
}
