import 'package:uuid/uuid.dart';

import '../../core/models/app_models.dart';
import '../../core/services/recipe_service.dart';
import '../../core/services/vision_service.dart';

class MockVisionService implements VisionService {
  @override
  Future<List<ParsedIngredient>> parseCapturedSources(List<String> sourcePaths) async {
    return const [
      ParsedIngredient(rawText: '2x tomato cans', normalizedName: 'tomato', confidence: 0.86),
      ParsedIngredient(rawText: 'pasta box', normalizedName: 'pasta', confidence: 0.94),
      ParsedIngredient(rawText: 'garlic bulb', normalizedName: 'garlic', confidence: 0.91),
    ];
  }
}

class _RecipeTemplate {
  const _RecipeTemplate({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.tags,
    required this.requirements,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.familyFriendlyScore,
    required this.healthScore,
    required this.fancyScore,
    required this.mealType,
    required this.steps,
    required this.pairings,
    required this.heroImageUrl,
    required this.leftoverGuidance,
  });

  final String id;
  final String title;
  final String shortDescription;
  final List<String> tags;
  final List<({String ingredient, double amount, String unit})> requirements;
  final int prepMinutes;
  final int cookMinutes;
  final int difficulty;
  final int familyFriendlyScore;
  final int healthScore;
  final int fancyScore;
  final MealType mealType;
  final List<CookingStep> steps;
  final List<PairingSuggestion> pairings;
  final String heroImageUrl;
  final LeftoverGuidance leftoverGuidance;
}

class MockRecipeSuggestionService implements RecipeSuggestionService {
  static const _templates = [
    _RecipeTemplate(
      id: 'recipe-pasta',
      title: '15-Min Pantry Pasta',
      shortDescription: 'Garlicky tomato pasta with pantry staples.',
      tags: ['vegetarian', 'family-friendly'],
      requirements: [
        (ingredient: 'pasta', amount: 1, unit: 'box'),
        (ingredient: 'tomatoes', amount: 1, unit: 'can'),
        (ingredient: 'garlic', amount: 2, unit: 'cloves'),
      ],
      prepMinutes: 5,
      cookMinutes: 10,
      difficulty: 1,
      familyFriendlyScore: 5,
      healthScore: 3,
      fancyScore: 2,
      mealType: MealType.dinner,
      steps: [
        CookingStep(order: 1, instruction: 'Boil pasta until al dente.', estimatedMinutes: 8),
        CookingStep(order: 2, instruction: 'Sauté garlic and add tomatoes.', estimatedMinutes: 6),
        CookingStep(order: 3, instruction: 'Toss pasta in sauce and serve.', estimatedMinutes: 2),
      ],
      pairings: [
        PairingSuggestion(
          category: PairingCategory.appetizerOrSide,
          title: 'Simple side salad',
          description: 'Lemony greens to brighten the dish.',
        ),
        PairingSuggestion(
          category: PairingCategory.wine,
          title: 'Pinot Grigio',
          description: 'Crisp acidity balances tomato richness.',
        ),
      ],
      heroImageUrl: 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?auto=format&fit=crop&w=1200&q=80',
      leftoverGuidance: LeftoverGuidance(
        storageMethod: 'Store sauce and pasta together in a sealed container.',
        fridgeDuration: 'Up to 4 days',
        freezerDuration: 'Up to 1 month',
        reheatingSuggestions: ['Microwave with a splash of water', 'Reheat in skillet over medium-low heat'],
      ),
    ),
    _RecipeTemplate(
      id: 'recipe-frittata',
      title: 'Fridge-Cleanout Frittata',
      shortDescription: 'Flexible egg skillet that welcomes leftovers.',
      tags: ['high-protein', 'gluten-free'],
      requirements: [
        (ingredient: 'eggs', amount: 6, unit: 'count'),
        (ingredient: 'onion', amount: 1, unit: 'count'),
        (ingredient: 'spinach', amount: 2, unit: 'cups'),
      ],
      prepMinutes: 10,
      cookMinutes: 15,
      difficulty: 2,
      familyFriendlyScore: 4,
      healthScore: 5,
      fancyScore: 3,
      mealType: MealType.breakfast,
      steps: [
        CookingStep(order: 1, instruction: 'Sauté onion until translucent.', estimatedMinutes: 5),
        CookingStep(order: 2, instruction: 'Add spinach until wilted.', estimatedMinutes: 2),
        CookingStep(order: 3, instruction: 'Add eggs and bake or cover until set.', estimatedMinutes: 15),
      ],
      pairings: [
        PairingSuggestion(
          category: PairingCategory.appetizerOrSide,
          title: 'Toast soldiers',
          description: 'Crunchy side for a balanced plate.',
        ),
        PairingSuggestion(
          category: PairingCategory.softDrink,
          title: 'Sparkling lemonade',
          description: 'Bright citrus keeps the plate feeling light.',
        ),
      ],
      heroImageUrl: 'https://images.unsplash.com/photo-1512058564366-c9e3f7a5a6a2?auto=format&fit=crop&w=1200&q=80',
      leftoverGuidance: LeftoverGuidance(
        storageMethod: 'Slice and chill in airtight container once fully cooled.',
        fridgeDuration: 'Up to 3 days',
        freezerDuration: 'Up to 1 month',
        reheatingSuggestions: ['Warm in 325°F oven for 8-10 minutes', 'Microwave individual slices for 45-60 seconds'],
      ),
    ),
  ];

  @override
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantryItems,
    required MealType mealType,
    required UserPreferences preferences,
    required int servings,
  }) async {
    final pantryNames = pantryItems.map((item) => item.name.trim().toLowerCase()).toSet();
    final results = <RecipeSuggestion>[];

    for (final template in _templates.where((template) => template.mealType == mealType)) {
      final missing = <MissingIngredient>[];
      final reqs = <RecipeIngredientRequirement>[];
      for (final requirement in template.requirements) {
        final hasIngredient = pantryNames.contains(requirement.ingredient);
        reqs.add(
          RecipeIngredientRequirement(
            ingredientName: requirement.ingredient,
            requiredAmount: requirement.amount,
            unit: requirement.unit,
            isAvailable: hasIngredient,
            availableAmount: hasIngredient ? requirement.amount : null,
          ),
        );
        if (!hasIngredient) {
          missing.add(
            MissingIngredient(
              ingredientName: requirement.ingredient,
              shortageAmount: requirement.amount,
              unit: requirement.unit,
              suggestedSubstitutions: _substitutionsFor(requirement.ingredient),
            ),
          );
        }
      }

      final matchType = missing.isEmpty
          ? RecipeMatchType.exact
          : missing.length <= 2
              ? RecipeMatchType.nearMatch
              : RecipeMatchType.pantryFreestyle;
      results.add(
        RecipeSuggestion(
          id: template.id,
          title: template.title,
          shortDescription: template.shortDescription,
          matchType: matchType,
          prepMinutes: template.prepMinutes,
          cookMinutes: template.cookMinutes,
          difficulty: template.difficulty,
          familyFriendlyScore: template.familyFriendlyScore,
          healthScore: template.healthScore,
          fancyScore: template.fancyScore,
          servings: servings,
          dietaryTags: template.tags,
          requirements: reqs,
          missingIngredients: missing,
          availableIngredients: reqs.where((req) => req.isAvailable).map((req) => req.ingredientName).toList(),
          steps: template.steps,
          suggestedPairings: template.pairings,
          explanation: RecipeExplanation(
            summary: _summaryFor(matchType, missing.length),
            pantryHighlights: pantryNames.take(3).toList(),
            nutritionAngle: template.healthScore >= 4 ? 'Prioritizes greens and lean ingredients.' : null,
          ),
          heroImageUrl: template.heroImageUrl,
          leftoverGuidance: template.leftoverGuidance,
          isPantryFreestyle: false,
        ),
      );
    }

    final freestyle = RecipeSuggestion(
      id: const Uuid().v4(),
      title: 'Pantry Freestyle Bowl',
      shortDescription: 'AI-inspired bowl idea from your current ingredients.',
      matchType: RecipeMatchType.pantryFreestyle,
      prepMinutes: 10,
      cookMinutes: 10,
      difficulty: 1,
      familyFriendlyScore: 4,
      healthScore: 4,
      fancyScore: 3,
      servings: servings,
      dietaryTags: preferences.dietaryFilters,
      requirements: pantryNames
          .take(4)
          .map((name) => RecipeIngredientRequirement(ingredientName: name, requiredAmount: 1, unit: 'portion', isAvailable: true, availableAmount: 1))
          .toList(),
      missingIngredients: const [],
      availableIngredients: pantryNames.take(4).toList(),
      steps: const [
        CookingStep(order: 1, instruction: 'Sauté aromatics and sturdy veggies.', estimatedMinutes: 4),
        CookingStep(order: 2, instruction: 'Add proteins/grains and season to taste.', estimatedMinutes: 8),
        CookingStep(order: 3, instruction: 'Finish with acidity and crunch.', estimatedMinutes: 2),
      ],
      suggestedPairings: const [
        PairingSuggestion(
          category: PairingCategory.softDrink,
          title: 'Sparkling water + citrus',
          description: 'Fresh, neutral pairing.',
        ),
      ],
      explanation: RecipeExplanation(
        summary: 'Pantry Freestyle (creative AI output): generated from pantry patterns, use your judgment.',
        pantryHighlights: pantryNames.take(3).toList(),
      ),
      heroImageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80',
      leftoverGuidance: const LeftoverGuidance(
        storageMethod: 'Cool, then refrigerate in shallow airtight containers.',
        fridgeDuration: 'Up to 4 days',
        freezerDuration: 'Up to 2 months',
        reheatingSuggestions: ['Microwave with a splash of water', 'Warm in skillet over medium heat'],
      ),
      isPantryFreestyle: true,
    );

    return [...results, freestyle];
  }

  static String _summaryFor(RecipeMatchType type, int missingCount) => switch (type) {
        RecipeMatchType.exact => 'Exact match: you can cook this now using your pantry inventory.',
        RecipeMatchType.nearMatch => 'Almost there: only $missingCount ingredient(s) needed from the store.',
        RecipeMatchType.pantryFreestyle => 'Pantry Freestyle (creative AI output): flexible concept, not canonical.',
      };

  static List<String> _substitutionsFor(String ingredient) => switch (ingredient) {
        'eggs' => const ['Flax egg', 'Silken tofu'],
        'onion' => const ['Shallot', 'Leek'],
        'spinach' => const ['Kale', 'Frozen mixed greens'],
        'garlic' => const ['Garlic powder'],
        _ => const ['Use similar pantry ingredient'],
      };
}
