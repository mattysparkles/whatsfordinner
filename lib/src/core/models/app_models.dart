enum MealType { breakfast, lunch, snack, dinner, dessert }
enum CookingSkillLevel { beginner, intermediate, advanced }
enum LeftoverPreference { loveLeftovers, neutral, preferFresh }
enum HistoryEventType { viewedRecipe, savedRecipe, startedCookMode, completedCookMode, generatedFreestyleIdea }

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
    this.allergies = const [],
    this.aversions = const [],
    this.cookingSkillLevel = CookingSkillLevel.beginner,
    this.leftoverPreference = LeftoverPreference.neutral,
    this.lowSodium = false,
    this.lowSugar = false,
    this.lowerCalorie = false,
  });

  final List<MealType> preferredMealTypes;
  final int householdSize;
  final List<String> dietaryFilters;
  final List<String> preferenceFilters;
  final List<String> allergies;
  final List<String> aversions;
  final CookingSkillLevel cookingSkillLevel;
  final LeftoverPreference leftoverPreference;
  final bool lowSodium;
  final bool lowSugar;
  final bool lowerCalorie;

  UserPreferences copyWith({
    List<MealType>? preferredMealTypes,
    int? householdSize,
    List<String>? dietaryFilters,
    List<String>? preferenceFilters,
    List<String>? allergies,
    List<String>? aversions,
    CookingSkillLevel? cookingSkillLevel,
    LeftoverPreference? leftoverPreference,
    bool? lowSodium,
    bool? lowSugar,
    bool? lowerCalorie,
  }) {
    return UserPreferences(
      preferredMealTypes: preferredMealTypes ?? this.preferredMealTypes,
      householdSize: householdSize ?? this.householdSize,
      dietaryFilters: dietaryFilters ?? this.dietaryFilters,
      preferenceFilters: preferenceFilters ?? this.preferenceFilters,
      allergies: allergies ?? this.allergies,
      aversions: aversions ?? this.aversions,
      cookingSkillLevel: cookingSkillLevel ?? this.cookingSkillLevel,
      leftoverPreference: leftoverPreference ?? this.leftoverPreference,
      lowSodium: lowSodium ?? this.lowSodium,
      lowSugar: lowSugar ?? this.lowSugar,
      lowerCalorie: lowerCalorie ?? this.lowerCalorie,
    );
  }

  Map<String, dynamic> toJson() => {
        'preferredMealTypes': preferredMealTypes.map((item) => item.name).toList(growable: false),
        'householdSize': householdSize,
        'dietaryFilters': dietaryFilters,
        'preferenceFilters': preferenceFilters,
        'allergies': allergies,
        'aversions': aversions,
        'cookingSkillLevel': cookingSkillLevel.name,
        'leftoverPreference': leftoverPreference.name,
        'lowSodium': lowSodium,
        'lowSugar': lowSugar,
        'lowerCalorie': lowerCalorie,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final preferredMealTypes = (json['preferredMealTypes'] as List<dynamic>? ?? const [])
        .map(
          (item) => MealType.values.firstWhere(
            (value) => value.name == item,
            orElse: () => MealType.dinner,
          ),
        )
        .toList(growable: false);
    return UserPreferences(
      preferredMealTypes: preferredMealTypes.isEmpty ? const [MealType.dinner] : preferredMealTypes,
      householdSize: json['householdSize'] as int? ?? 2,
      dietaryFilters: (json['dietaryFilters'] as List<dynamic>? ?? const []).cast<String>(),
      preferenceFilters: (json['preferenceFilters'] as List<dynamic>? ?? const []).cast<String>(),
      allergies: (json['allergies'] as List<dynamic>? ?? const []).cast<String>(),
      aversions: (json['aversions'] as List<dynamic>? ?? const []).cast<String>(),
      cookingSkillLevel: CookingSkillLevel.values.firstWhere(
        (value) => value.name == json['cookingSkillLevel'],
        orElse: () => CookingSkillLevel.beginner,
      ),
      leftoverPreference: LeftoverPreference.values.firstWhere(
        (value) => value.name == json['leftoverPreference'],
        orElse: () => LeftoverPreference.neutral,
      ),
      lowSodium: json['lowSodium'] as bool? ?? false,
      lowSugar: json['lowSugar'] as bool? ?? false,
      lowerCalorie: json['lowerCalorie'] as bool? ?? false,
    );
  }
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
  const SavedRecipe({
    required this.recipeId,
    required this.savedAt,
    required this.recipeTitle,
    this.isPantryFreestyle = false,
  });

  final String recipeId;
  final DateTime savedAt;
  final String recipeTitle;
  final bool isPantryFreestyle;

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'savedAt': savedAt.toIso8601String(),
        'recipeTitle': recipeTitle,
        'isPantryFreestyle': isPantryFreestyle,
      };

  factory SavedRecipe.fromJson(Map<String, dynamic> json) {
    return SavedRecipe(
      recipeId: json['recipeId'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      recipeTitle: json['recipeTitle'] as String? ?? 'Recipe',
      isPantryFreestyle: json['isPantryFreestyle'] as bool? ?? false,
    );
  }
}

class HistoryEvent {
  const HistoryEvent({
    required this.type,
    required this.occurredAt,
    required this.recipeId,
    required this.recipeTitle,
    this.isPantryFreestyle = false,
  });

  final HistoryEventType type;
  final DateTime occurredAt;
  final String recipeId;
  final String recipeTitle;
  final bool isPantryFreestyle;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'occurredAt': occurredAt.toIso8601String(),
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'isPantryFreestyle': isPantryFreestyle,
      };

  factory HistoryEvent.fromJson(Map<String, dynamic> json) {
    return HistoryEvent(
      type: HistoryEventType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => HistoryEventType.viewedRecipe,
      ),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      recipeId: json['recipeId'] as String,
      recipeTitle: json['recipeTitle'] as String? ?? 'Recipe',
      isPantryFreestyle: json['isPantryFreestyle'] as bool? ?? false,
    );
  }
}

enum ProviderCapabilityLabel {
  availableNow,
  comingLater;

  String get label => switch (this) {
        ProviderCapabilityLabel.availableNow => 'Available now',
        ProviderCapabilityLabel.comingLater => 'Coming later',
      };
}

class CommerceProvider {
  const CommerceProvider({
    required this.id,
    required this.name,
    required this.capabilityLabel,
    this.supportsAffiliateTracking = false,
    this.notes,
  });

  final String id;
  final String name;
  final ProviderCapabilityLabel capabilityLabel;
  final bool supportsAffiliateTracking;
  final String? notes;
}

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.ingredientName,
    required this.groupLabel,
    this.quantity,
    this.unit,
    this.note,
    this.isChecked = false,
  });

  final String id;
  final String ingredientName;
  final String groupLabel;
  final double? quantity;
  final String? unit;
  final String? note;
  final bool isChecked;

  ShoppingListItem copyWith({
    String? id,
    String? ingredientName,
    String? groupLabel,
    double? quantity,
    String? unit,
    String? note,
    bool? isChecked,
    bool clearQuantity = false,
    bool clearUnit = false,
    bool clearNote = false,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      ingredientName: ingredientName ?? this.ingredientName,
      groupLabel: groupLabel ?? this.groupLabel,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      unit: clearUnit ? null : (unit ?? this.unit),
      note: clearNote ? null : (note ?? this.note),
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.title,
    required this.items,
    required this.createdAt,
    this.recipeId,
    this.recipeTitle,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String? recipeId;
  final String? recipeTitle;
  final List<ShoppingListItem> items;

  ShoppingList copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? recipeId,
    String? recipeTitle,
    List<ShoppingListItem>? items,
    bool clearRecipeId = false,
    bool clearRecipeTitle = false,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      recipeId: clearRecipeId ? null : (recipeId ?? this.recipeId),
      recipeTitle: clearRecipeTitle ? null : (recipeTitle ?? this.recipeTitle),
      items: items ?? this.items,
    );
  }
}

class ShoppingLinkResult {
  const ShoppingLinkResult({
    required this.provider,
    required this.message,
    this.checkoutUri,
    this.itemUris = const [],
    this.canOpenNow = true,
  });

  final CommerceProvider provider;
  final Uri? checkoutUri;
  final List<Uri> itemUris;
  final String message;
  final bool canOpenNow;
}
