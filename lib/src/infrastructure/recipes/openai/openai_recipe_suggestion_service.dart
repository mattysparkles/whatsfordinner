import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env_config.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/recipe_service.dart';

class OpenAiRecipeSuggestionService implements RecipeSuggestionService {
  OpenAiRecipeSuggestionService({
    required EnvConfig config,
    Uuid? uuid,
    OpenAiRecipeApiClient? apiClient,
    DateTime Function()? now,
  })  : _config = config,
        _uuid = uuid ?? const Uuid(),
        _apiClient = apiClient ?? DioOpenAiRecipeApiClient(config: config),
        _now = now ?? DateTime.now;

  final EnvConfig _config;
  final Uuid _uuid;
  final OpenAiRecipeApiClient _apiClient;
  final DateTime Function() _now;
  final Map<String, _CachedRecipeSuggestions> _cache = <String, _CachedRecipeSuggestions>{};

  @override
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
    required int servings,
  }) async {
    final analysis = PantryAnalysisEngine().analyze(
      pantryItems: pantryItems,
      mealType: mealType,
      preferences: preferences,
      servings: servings,
    );
    final cacheKey = _cacheKey(analysis: analysis, preferences: preferences, servings: servings);
    final cached = _cache[cacheKey];
    final now = _now();
    if (cached != null && now.difference(cached.createdAt) <= _config.recipeCacheTtl) {
      return cached.suggestions;
    }

    if (_config.recipeApiKey.trim().isEmpty) {
      if (cached != null) return cached.suggestions;
      throw const RecipeSuggestionException(
        'Recipe suggestions are not configured yet. Please try again soon.',
      );
    }

    try {
      final response = await _apiClient.generateSuggestions(
        OpenAiRecipeRequest(
          model: _config.recipeModel,
          analysis: analysis,
          servings: servings,
          mealType: mealType,
          preferences: preferences,
        ),
      );
      final mapped = _mapResponse(response, analysis, servings);
      _cache[cacheKey] = _CachedRecipeSuggestions(createdAt: now, suggestions: mapped);
      return mapped;
    } catch (_) {
      if (cached != null) return cached.suggestions;
      throw const RecipeSuggestionException(
        'We could not refresh suggestions right now. Check your connection and tap Try again.',
      );
    }
  }

  String _cacheKey({required PantryAnalysis analysis, required UserPreferences preferences, required int servings}) {
    final pantryHash = analysis.pantryHash;
    final dietary = [...preferences.dietaryFilters]..sort();
    final prefs = [...preferences.preferenceFilters]..sort();
    return '$pantryHash|${analysis.mealType.name}|$servings|${dietary.join(',')}|${prefs.join(',')}';
  }

  List<RecipeSuggestion> _mapResponse(Map<String, dynamic> response, PantryAnalysis analysis, int servings) {
    final contentJson = _extractStructuredContentJson(response);
    final decoded = jsonDecode(contentJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Recipe response was not an object.');
    }

    final suggestions = decoded['suggestions'];
    if (suggestions is! List) {
      throw const FormatException('Recipe response missing suggestions list.');
    }

    final mapped = suggestions
        .whereType<Map<String, dynamic>>()
        .map((item) => _mapSuggestion(item: item, servings: servings))
        .toList(growable: false);

    final ranked = [...mapped]
      ..sort((a, b) {
        final rankDelta = _matchRank(a.matchType).compareTo(_matchRank(b.matchType));
        if (rankDelta != 0) return rankDelta;
        return a.missingIngredients.length.compareTo(b.missingIngredients.length);
      });

    final exactSuggestions = ranked.where((recipe) => recipe.matchType == RecipeMatchType.exact).toList(growable: false);
    if (exactSuggestions.isNotEmpty) {
      return ranked;
    }

    final upgraded = _deterministicBestMatchFallback(analysis: analysis, servings: servings);
    return [...upgraded, ...ranked];
  }

  List<RecipeSuggestion> _deterministicBestMatchFallback({required PantryAnalysis analysis, required int servings}) {
    final best = analysis.candidates.where((candidate) => candidate.classification == RecipeMatchType.exact).toList(growable: false);
    return best
        .take(2)
        .map(
          (candidate) => RecipeSuggestion(
            id: 'det-${candidate.directionKey}',
            title: '${candidate.displayName} (Pantry Match)',
            shortDescription: 'Deterministic pantry match based on what you already have.',
            matchType: RecipeMatchType.exact,
            prepMinutes: 10,
            cookMinutes: 20,
            difficulty: 2,
            familyFriendlyScore: 4,
            healthScore: 4,
            fancyScore: 2,
            servings: servings,
            dietaryTags: const [],
            requirements: candidate.requirements
                .map((name) => RecipeIngredientRequirement(
                      ingredientName: name,
                      requiredAmount: 1,
                      unit: 'portion',
                      isAvailable: true,
                      availableAmount: 1,
                    ))
                .toList(growable: false),
            missingIngredients: const [],
            availableIngredients: candidate.available,
            steps: const [
              CookingStep(order: 1, instruction: 'Prep the key ingredients.', estimatedMinutes: 10),
              CookingStep(order: 2, instruction: 'Cook using your preferred technique.', estimatedMinutes: 20),
            ],
            suggestedPairings: const [],
            explanation: RecipeExplanation(
              summary: 'Best Match from deterministic pantry analysis (${candidate.score.toStringAsFixed(2)}).',
              pantryHighlights: candidate.available.take(3).toList(growable: false),
            ),
          ),
        )
        .toList(growable: false);
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
                category: _parsePairingCategory(pairing['category'] as String?),
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
      heroImageUrl: (item['heroImageUrl'] as String?)?.trim(),
      leftoverGuidance: LeftoverGuidance(
        storageMethod: (item['leftovers'] as Map<String, dynamic>?)?['storageMethod'] as String? ??
            'Cool completely, then store in an airtight container.',
        fridgeDuration: (item['leftovers'] as Map<String, dynamic>?)?['fridgeDuration'] as String? ?? 'Up to 3 days',
        freezerDuration: (item['leftovers'] as Map<String, dynamic>?)?['freezerDuration'] as String? ?? 'Up to 2 months',
        reheatingSuggestions: ((item['leftovers'] as Map<String, dynamic>?)?['reheatingSuggestions'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const ['Reheat gently on the stovetop or in the microwave.'],
      ),
      isPantryFreestyle: (item['isAiFreestyle'] as bool?) ?? matchType == RecipeMatchType.pantryFreestyle,
    );
  }

  String _extractStructuredContentJson(Map<String, dynamic> apiResponse) {
    final choices = apiResponse['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Missing choices in response.');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('Invalid first choice.');
    }
    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Missing message.');
    }
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }
    throw const FormatException('No JSON content returned.');
  }

  int _matchRank(RecipeMatchType matchType) => switch (matchType) {
        RecipeMatchType.exact => 0,
        RecipeMatchType.nearMatch => 1,
        RecipeMatchType.pantryFreestyle => 2,
      };

  RecipeMatchType _parseMatchType(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'exact' => RecipeMatchType.exact,
      'nearmatch' => RecipeMatchType.nearMatch,
      'pantryfreestyle' => RecipeMatchType.pantryFreestyle,
      _ => RecipeMatchType.nearMatch,
    };
  }

  PairingCategory _parsePairingCategory(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'wine' => PairingCategory.wine,
      'cocktail' => PairingCategory.cocktail,
      'beer' => PairingCategory.beer,
      'softdrink' || 'soft_drink' || 'soft drink' => PairingCategory.softDrink,
      'appetizer' || 'appetizerorside' || 'appetizer_or_side' || 'appetizer / side pairing' => PairingCategory.appetizerOrSide,
      _ => PairingCategory.softDrink,
    };
  }
}

class PantryAnalysisEngine {
  PantryAnalysis analyze({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
    required int servings,
  }) {
    final normalized = pantryItems.map((item) => _normalize(item.name)).where((name) => name.isNotEmpty).toSet();
    final candidates = _directions
        .where((direction) => direction.mealType == mealType)
        .where((direction) => _passesFilters(direction, preferences))
        .map((direction) => _scoreDirection(direction: direction, pantry: normalized))
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    final hashPayload = {
      'pantry': normalized.toList()..sort(),
      'mealType': mealType.name,
      'servings': servings,
      'dietary': [...preferences.dietaryFilters]..sort(),
      'preferences': [...preferences.preferenceFilters]..sort(),
    };

    return PantryAnalysis(
      mealType: mealType,
      pantryHash: base64Url.encode(utf8.encode(jsonEncode(hashPayload))),
      normalizedPantry: normalized.toList(growable: false),
      candidates: candidates,
      weakConfidenceIngredients: pantryItems.where((item) => (item.quantity ?? 1) <= 0).map((item) => _normalize(item.name)).toList(growable: false),
    );
  }

  CandidateDirectionScore _scoreDirection({required _MealDirection direction, required Set<String> pantry}) {
    final available = <String>[];
    final missing = <String>[];
    final substitutable = <String>[];

    for (final requirement in direction.requirements) {
      if (pantry.contains(requirement)) {
        available.add(requirement);
        continue;
      }

      final hasSubstitute = (direction.substitutions[requirement] ?? const <String>[]).any(pantry.contains);
      if (hasSubstitute) {
        substitutable.add(requirement);
      } else {
        missing.add(requirement);
      }
    }

    final exactRatio = direction.requirements.isEmpty ? 0.0 : available.length / direction.requirements.length;
    final substitutionRatio = direction.requirements.isEmpty ? 0.0 : substitutable.length / direction.requirements.length;
    final score = (exactRatio * 0.75) + (substitutionRatio * 0.2) - ((missing.length / (direction.requirements.length + 1)) * 0.1);

    final classification = missing.isEmpty
        ? RecipeMatchType.exact
        : missing.length <= 2
            ? RecipeMatchType.nearMatch
            : RecipeMatchType.pantryFreestyle;

    return CandidateDirectionScore(
      directionKey: direction.key,
      displayName: direction.displayName,
      classification: classification,
      score: score,
      available: available,
      missing: missing,
      substitutable: substitutable,
      requirements: direction.requirements,
    );
  }

  bool _passesFilters(_MealDirection direction, UserPreferences preferences) {
    final dietary = preferences.dietaryFilters.map(_normalize).toSet();
    final preference = preferences.preferenceFilters.map(_normalize).toSet();
    if (dietary.isNotEmpty && dietary.difference(direction.tags).isNotEmpty) {
      return false;
    }
    if (preference.isEmpty) return true;
    return preference.intersection(direction.tags).isNotEmpty;
  }

  String _normalize(String raw) => raw.trim().toLowerCase();
}

class PantryAnalysis {
  const PantryAnalysis({
    required this.mealType,
    required this.pantryHash,
    required this.normalizedPantry,
    required this.candidates,
    required this.weakConfidenceIngredients,
  });

  final MealType mealType;
  final String pantryHash;
  final List<String> normalizedPantry;
  final List<CandidateDirectionScore> candidates;
  final List<String> weakConfidenceIngredients;

  Map<String, dynamic> toJson() => {
        'mealType': mealType.name,
        'pantryHash': pantryHash,
        'normalizedPantry': normalizedPantry,
        'weakConfidenceIngredients': weakConfidenceIngredients,
        'candidates': candidates.map((candidate) => candidate.toJson()).toList(growable: false),
      };
}

class CandidateDirectionScore {
  const CandidateDirectionScore({
    required this.directionKey,
    required this.displayName,
    required this.classification,
    required this.score,
    required this.available,
    required this.missing,
    required this.substitutable,
    required this.requirements,
  });

  final String directionKey;
  final String displayName;
  final RecipeMatchType classification;
  final double score;
  final List<String> available;
  final List<String> missing;
  final List<String> substitutable;
  final List<String> requirements;

  Map<String, dynamic> toJson() => {
        'directionKey': directionKey,
        'displayName': displayName,
        'classification': classification.name,
        'score': score,
        'available': available,
        'missing': missing,
        'substitutable': substitutable,
        'requirements': requirements,
      };
}

class RecipeSuggestionException implements Exception {
  const RecipeSuggestionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _CachedRecipeSuggestions {
  const _CachedRecipeSuggestions({required this.createdAt, required this.suggestions});

  final DateTime createdAt;
  final List<RecipeSuggestion> suggestions;
}

class OpenAiRecipeRequest {
  const OpenAiRecipeRequest({
    required this.model,
    required this.analysis,
    required this.servings,
    required this.mealType,
    required this.preferences,
  });

  final String model;
  final PantryAnalysis analysis;
  final int servings;
  final MealType mealType;
  final UserPreferences preferences;
}

abstract interface class OpenAiRecipeApiClient {
  Future<Map<String, dynamic>> generateSuggestions(OpenAiRecipeRequest request);
}

class DioOpenAiRecipeApiClient implements OpenAiRecipeApiClient {
  DioOpenAiRecipeApiClient({required EnvConfig config, Dio? dio})
      : _config = config,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.recipeApiBaseUrl,
                connectTimeout: Duration(milliseconds: config.recipeRequestTimeoutMs),
                receiveTimeout: Duration(milliseconds: config.recipeRequestTimeoutMs),
                sendTimeout: Duration(milliseconds: config.recipeRequestTimeoutMs),
              ),
            );

  final EnvConfig _config;
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> generateSuggestions(OpenAiRecipeRequest request) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/chat/completions',
          options: Options(headers: {'Authorization': 'Bearer ${_config.recipeApiKey}'}),
          data: _buildPayload(request),
        );
        final data = response.data;
        if (data == null) {
          throw const FormatException('Recipe API returned empty response.');
        }
        return data;
      } on DioException catch (error) {
        final retryable = error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout;
        if (retryable && attempt <= _config.recipeMaxRetries) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 250));
          continue;
        }
        rethrow;
      }
    }
  }

  Map<String, dynamic> _buildPayload(OpenAiRecipeRequest request) {
    return {
      'model': request.model,
      'temperature': 0.3,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are PantryPilot recipe planner. Be honest. Separate Best Matches, Almost There, and Pantry Freestyle. For Pantry Freestyle explicitly mark as AI-created improvisation.',
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'task': 'Generate practical recipe suggestions from pantry analysis.',
            'mealType': request.mealType.name,
            'servings': request.servings,
            'dietaryFilters': request.preferences.dietaryFilters,
            'preferenceFilters': request.preferences.preferenceFilters,
            'pantryAnalysis': request.analysis.toJson(),
          }),
        },
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'recipe_suggestions',
          'strict': true,
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'suggestions': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'title': {'type': 'string'},
                    'description': {'type': 'string'},
                    'matchType': {'type': 'string', 'enum': ['exact', 'nearMatch', 'pantryFreestyle']},
                    'servings': {'type': 'integer'},
                    'prepMinutes': {'type': 'integer'},
                    'cookMinutes': {'type': 'integer'},
                    'difficulty': {'type': 'integer'},
                    'familyFriendlyScore': {'type': 'integer'},
                    'healthScore': {'type': 'integer'},
                    'fancyScore': {'type': 'integer'},
                    'requirements': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'ingredient': {'type': 'string'},
                          'amount': {'type': 'number'},
                          'unit': {'type': 'string'},
                          'isAvailable': {'type': 'boolean'},
                          'availableAmount': {'type': ['number', 'null']},
                        },
                        'required': ['ingredient', 'amount', 'unit', 'isAvailable', 'availableAmount'],
                      },
                    },
                    'missingIngredients': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'ingredient': {'type': 'string'},
                          'amount': {'type': ['number', 'null']},
                          'unit': {'type': ['string', 'null']},
                          'substitutions': {'type': 'array', 'items': {'type': 'string'}},
                        },
                        'required': ['ingredient', 'amount', 'unit', 'substitutions'],
                      },
                    },
                    'steps': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'order': {'type': 'integer'},
                          'instruction': {'type': 'string'},
                          'minutes': {'type': ['integer', 'null']},
                        },
                        'required': ['order', 'instruction', 'minutes'],
                      },
                    },
                    'pairings': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {'title': {'type': 'string'}, 'description': {'type': 'string'}},
                        'required': ['title', 'description'],
                      },
                    },
                    'explanation': {'type': 'string'},
                    'tags': {'type': 'array', 'items': {'type': 'string'}},
                    'highlights': {'type': 'array', 'items': {'type': 'string'}},
                    'isAiFreestyle': {'type': 'boolean'},
                  },
                  'required': [
                    'title',
                    'description',
                    'matchType',
                    'servings',
                    'prepMinutes',
                    'cookMinutes',
                    'difficulty',
                    'familyFriendlyScore',
                    'healthScore',
                    'fancyScore',
                    'requirements',
                    'missingIngredients',
                    'steps',
                    'pairings',
                    'explanation',
                    'tags',
                    'highlights',
                    'isAiFreestyle',
                  ],
                },
              },
            },
            'required': ['suggestions'],
          },
        },
      },
    };
  }
}

class _MealDirection {
  const _MealDirection({
    required this.key,
    required this.displayName,
    required this.mealType,
    required this.requirements,
    required this.substitutions,
    required this.tags,
  });

  final String key;
  final String displayName;
  final MealType mealType;
  final List<String> requirements;
  final Map<String, List<String>> substitutions;
  final Set<String> tags;
}

const List<_MealDirection> _directions = [
  _MealDirection(
    key: 'pasta-red-sauce',
    displayName: 'Tomato Garlic Pasta',
    mealType: MealType.dinner,
    requirements: ['pasta', 'tomatoes', 'garlic', 'olive oil'],
    substitutions: {
      'tomatoes': ['tomato sauce', 'crushed tomatoes'],
      'garlic': ['garlic powder'],
      'olive oil': ['butter'],
    },
    tags: {'vegetarian', 'family-friendly'},
  ),
  _MealDirection(
    key: 'egg-scramble',
    displayName: 'Savory Egg Scramble',
    mealType: MealType.breakfast,
    requirements: ['eggs', 'onion', 'spinach'],
    substitutions: {
      'spinach': ['kale'],
      'onion': ['shallot'],
    },
    tags: {'gluten-free', 'high-protein'},
  ),
  _MealDirection(
    key: 'rice-bowl',
    displayName: 'Veggie Rice Bowl',
    mealType: MealType.lunch,
    requirements: ['rice', 'beans', 'onion'],
    substitutions: {
      'beans': ['lentils', 'chickpeas'],
      'rice': ['quinoa'],
    },
    tags: {'vegetarian', 'high-fiber'},
  ),
  _MealDirection(
    key: 'yogurt-parfait',
    displayName: 'Fruit Yogurt Parfait',
    mealType: MealType.snack,
    requirements: ['yogurt', 'fruit', 'nuts'],
    substitutions: {
      'nuts': ['granola'],
      'fruit': ['berries'],
    },
    tags: {'high-protein', 'kid-friendly'},
  ),
  _MealDirection(
    key: 'sweet-toast',
    displayName: 'Sweet Cinnamon Toast',
    mealType: MealType.dessert,
    requirements: ['bread', 'butter', 'sugar'],
    substitutions: {
      'sugar': ['honey'],
      'butter': ['coconut oil'],
    },
    tags: {'quick', 'comfort'},
  ),
];
