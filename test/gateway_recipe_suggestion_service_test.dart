import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/infrastructure/gateway/gateway_recipe_suggestion_service.dart';
import 'package:pantry_pilot/src/infrastructure/gateway/pantry_gateway_client.dart';
import 'package:pantry_pilot/src/infrastructure/recipes/openai/openai_recipe_suggestion_service.dart';

void main() {
  test('maps backend response into recipe suggestions', () async {
    final service = GatewayRecipeSuggestionService(
      client: _FakeGatewayClient(
        payload: {
          'suggestions': [
            {
              'title': 'Pantry Bowl',
              'description': 'Great with what you have',
              'matchType': 'pantryFreestyle',
              'servings': 2,
              'prepMinutes': 10,
              'cookMinutes': 15,
              'difficulty': 2,
              'familyFriendlyScore': 4,
              'healthScore': 4,
              'fancyScore': 3,
              'requirements': [
                {'ingredient': 'rice', 'amount': 1, 'unit': 'cup', 'isAvailable': true, 'availableAmount': 1}
              ],
              'missingIngredients': [],
              'steps': [
                {'order': 1, 'instruction': 'Cook rice.', 'minutes': 15}
              ],
              'pairings': [
                {'title': 'Tea', 'description': 'Simple pairing'}
              ],
              'explanation': 'AI improvisation from pantry.',
              'tags': ['vegetarian'],
              'highlights': ['rice'],
              'isAiFreestyle': true,
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
  });

  test('throws recipe exception with safe message on backend failure', () async {
    final service = GatewayRecipeSuggestionService(client: _FakeGatewayClient(error: const PantryGatewayException('Please retry later.')));

    expect(
      () => service.suggestRecipes(
        pantryItems: const [PantryItem(id: '1', name: 'rice')],
        mealType: MealType.lunch,
        preferences: const UserPreferences(),
        servings: 2,
      ),
      throwsA(isA<RecipeSuggestionException>()),
    );
  });
}

class _FakeGatewayClient extends PantryGatewayClient {
  _FakeGatewayClient({this.payload, this.error}) : super(baseUrl: 'https://example.com');

  final Map<String, dynamic>? payload;
  final PantryGatewayException? error;

  @override
  Future<Map<String, dynamic>> postJson({required String path, required Map<String, dynamic> payload}) async {
    if (error != null) throw error!;
    return this.payload ?? const {};
  }
}
