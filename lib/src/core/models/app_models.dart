enum MealType { breakfast, lunch, snack, dinner, dessert }

enum RecipeMatchType {
  exact,
  nearMatch,
  pantryFreestyle;

  String get label => switch (this) {
        RecipeMatchType.exact => 'Exact match',
        RecipeMatchType.nearMatch => 'Near match',
        RecipeMatchType.pantryFreestyle => 'Pantry Freestyle',
      };
}

enum RecipeSortOption {
  fastest,
  easiest,
  fewestMissingIngredients,
  familyFriendly,
  healthier,
  fancy;

  String get label => switch (this) {
        RecipeSortOption.fastest => 'Fastest',
        RecipeSortOption.easiest => 'Easiest',
        RecipeSortOption.fewestMissingIngredients => 'Fewest missing ingredients',
        RecipeSortOption.familyFriendly => 'Family friendly',
        RecipeSortOption.healthier => 'Healthier',
        RecipeSortOption.fancy => 'Fancy',
      };
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
  });

  final String id;
  final String name;
  final double? quantity;
  final String? unit;
}

class UserPreferences {
  const UserPreferences({
    this.preferredMealTypes = const [MealType.dinner],
    this.householdSize = 2,
    this.dietaryFilters = const [],
    this.preferenceFilters = const [],
  });

  final List<MealType> preferredMealTypes;
  final int householdSize;
  final List<String> dietaryFilters;
  final List<String> preferenceFilters;
}

class RecipeIngredientRequirement {
  const RecipeIngredientRequirement({
    required this.ingredientName,
    required this.requiredAmount,
    required this.unit,
    required this.isAvailable,
    this.availableAmount,
  });

  final String ingredientName;
  final double requiredAmount;
  final String unit;
  final bool isAvailable;
  final double? availableAmount;
}

class MissingIngredient {
  const MissingIngredient({
    required this.ingredientName,
    this.shortageAmount,
    this.unit,
    this.suggestedSubstitutions = const [],
  });

  final String ingredientName;
  final double? shortageAmount;
  final String? unit;
  final List<String> suggestedSubstitutions;
}

class CookingStep {
  const CookingStep({
    required this.order,
    required this.instruction,
    this.estimatedMinutes,
  });

  final int order;
  final String instruction;
  final int? estimatedMinutes;
}

class PairingSuggestion {
  const PairingSuggestion({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class RecipeExplanation {
  const RecipeExplanation({
    required this.summary,
    required this.pantryHighlights,
    this.nutritionAngle,
  });

  final String summary;
  final List<String> pantryHighlights;
  final String? nutritionAngle;
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.matchType,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.familyFriendlyScore,
    required this.healthScore,
    required this.fancyScore,
    required this.servings,
    required this.dietaryTags,
    required this.requirements,
    required this.missingIngredients,
    required this.availableIngredients,
    required this.steps,
    required this.suggestedPairings,
    required this.explanation,
    this.isPantryFreestyle = false,
  });

  final String id;
  final String title;
  final String shortDescription;
  final RecipeMatchType matchType;
  final int prepMinutes;
  final int cookMinutes;
  final int difficulty;
  final int familyFriendlyScore;
  final int healthScore;
  final int fancyScore;
  final int servings;
  final List<String> dietaryTags;
  final List<RecipeIngredientRequirement> requirements;
  final List<MissingIngredient> missingIngredients;
  final List<String> availableIngredients;
  final List<CookingStep> steps;
  final List<PairingSuggestion> suggestedPairings;
  final RecipeExplanation explanation;
  final bool isPantryFreestyle;

  int get totalMinutes => prepMinutes + cookMinutes;
}

class ParsedIngredient {
  const ParsedIngredient({
    required this.rawText,
    required this.normalizedName,
    required this.confidence,
  });

  final String rawText;
  final String normalizedName;
  final double confidence;
}

class SavedRecipe {
  const SavedRecipe({required this.recipeId, required this.savedAt});

  final String recipeId;
  final DateTime savedAt;
}
