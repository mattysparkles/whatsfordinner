import 'package:uuid/uuid.dart';

import '../../core/models/app_models.dart';
import '../../core/services/recipe_service.dart';
import '../recipes/openai/openai_recipe_suggestion_service.dart' show RecipeSuggestionException;
import 'pantry_gateway_client.dart';

class GatewayRecipeSuggestionService implements RecipeSuggestionService {
  GatewayRecipeSuggestionService({required PantryGatewayClient client, Uuid? uuid})
      : _client = client,
        _uuid = uuid ?? const Uuid();

  final PantryGatewayClient _client;
  final Uuid _uuid;

  @override
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
    required int servings,
  }) async {
    try {
      final response = await _client.postJson(
        path: '/recipes/suggest',
        payload: {
          'pantryItems': pantryItems
              .map((item) => {'id': item.id, 'name': item.name, 'quantity': item.quantity, 'unit': item.unit})
              .toList(growable: false),
          'mealType': mealType.name,
          'preferences': {
            'dietaryFilters': preferences.dietaryFilters,
            'preferenceFilters': preferences.preferenceFilters,
          },
          'servings': servings,
        },
      );
      final suggestions = (response['suggestions'] as List?) ?? const [];
      return suggestions.whereType<Map<String, dynamic>>().map((item) => _mapSuggestion(item: item, servings: servings)).toList(growable: false);
    } on PantryGatewayException catch (error) {
      throw RecipeSuggestionException(error.userMessage);
    }
  }

  RecipeSuggestion _mapSuggestion({required Map<String, dynamic> item, required int servings}) {
    final matchType = _parseMatchType((item['matchType'] as String?) ?? 'nearMatch');
    final requirements = (item['requirements'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (req) => RecipeIngredientRequirement(
                ingredientName: (req['ingredient'] as String?)?.trim() ?? 'ingredient',
                requiredAmount: (req['amount'] as num?)?.toDouble() ?? 1,
                unit: (req['unit'] as String?)?.trim() ?? 'portion',
                isAvailable: (req['isAvailable'] as bool?) ?? false,
                availableAmount: (req['availableAmount'] as num?)?.toDouble(),
              ),
            )
            .toList(growable: false) ??
        const <RecipeIngredientRequirement>[];

    final missing = (item['missingIngredients'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (entry) => MissingIngredient(
                ingredientName: (entry['ingredient'] as String?)?.trim() ?? 'ingredient',
                shortageAmount: (entry['amount'] as num?)?.toDouble(),
                unit: (entry['unit'] as String?)?.trim(),
                suggestedSubstitutions: (entry['substitutions'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
              ),
            )
            .toList(growable: false) ??
        const <MissingIngredient>[];

    final steps = (item['steps'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (step) => CookingStep(
                order: (step['order'] as num?)?.toInt() ?? 1,
                instruction: (step['instruction'] as String?)?.trim() ?? 'Cook and serve.',
                estimatedMinutes: (step['minutes'] as num?)?.toInt(),
              ),
            )
            .toList(growable: false) ??
        const <CookingStep>[];

    final pairings = (item['pairings'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (pairing) => PairingSuggestion(
                title: (pairing['title'] as String?)?.trim() ?? 'Pairing idea',
                description: (pairing['description'] as String?)?.trim() ?? 'Complements this recipe.',
              ),
            )
            .toList(growable: false) ??
        const <PairingSuggestion>[];

    return RecipeSuggestion(
      id: _uuid.v4(),
      title: (item['title'] as String?)?.trim() ?? 'Pantry Recipe',
      shortDescription: (item['description'] as String?)?.trim() ?? 'Generated from your pantry.',
      matchType: matchType,
      prepMinutes: (item['prepMinutes'] as num?)?.toInt() ?? 10,
      cookMinutes: (item['cookMinutes'] as num?)?.toInt() ?? 15,
      difficulty: (((item['difficulty'] as num?)?.toInt() ?? 2).clamp(1, 5) as int),
      familyFriendlyScore: (((item['familyFriendlyScore'] as num?)?.toInt() ?? 3).clamp(1, 5) as int),
      healthScore: (((item['healthScore'] as num?)?.toInt() ?? 3).clamp(1, 5) as int),
      fancyScore: (((item['fancyScore'] as num?)?.toInt() ?? 2).clamp(1, 5) as int),
      servings: (item['servings'] as num?)?.toInt() ?? servings,
      dietaryTags: (item['tags'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
      requirements: requirements,
      missingIngredients: missing,
      availableIngredients: requirements.where((req) => req.isAvailable).map((req) => req.ingredientName).toList(growable: false),
      steps: steps,
      suggestedPairings: pairings,
      explanation: RecipeExplanation(
        summary: (item['explanation'] as String?)?.trim() ?? 'Suggested from pantry analysis.',
        pantryHighlights: (item['highlights'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
      ),
      isPantryFreestyle: (item['isAiFreestyle'] as bool?) ?? matchType == RecipeMatchType.pantryFreestyle,
    );
  }

  RecipeMatchType _parseMatchType(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'exact' => RecipeMatchType.exact,
      'nearmatch' => RecipeMatchType.nearMatch,
      'pantryfreestyle' => RecipeMatchType.pantryFreestyle,
      _ => RecipeMatchType.nearMatch,
    };
  }
}
