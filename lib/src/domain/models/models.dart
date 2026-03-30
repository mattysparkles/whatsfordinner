enum RecipeMatchType { exact, nearMatch, aiInvention }

enum MealType {
  breakfast,
  lunch,
  snack,
  dinner,
  dessert,
  drinks,
  appetizers,
  multiCourse,
}

enum CaptureCategory { pantry, fridge, freezer, spiceRack, groceryScreenshot }

enum CaptureInputMethod { camera, photoLibrary, screenshotUpload }

enum ParseConfidence { likely, possible, unclear }

enum IngredientCategory {
  produce,
  dairy,
  meatSeafood,
  grainsBread,
  cannedJarred,
  frozen,
  baking,
  spicesSeasonings,
  oilsCondiments,
  snacks,
  beverages,
  other,
}

enum PantrySourceType {
  manual,
  pantryPhoto,
  fridgePhoto,
  freezerPhoto,
  groceryScreenshot,
  aiImport,
}

enum FreshnessState { unknown, fresh, useSoon, expiring, expired }

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    this.normalizedName,
    this.searchAliases = const [],
  });

  final String id;
  final String name;
  final IngredientCategory category;
  final String? normalizedName;
  final List<String> searchAliases;

  Ingredient copyWith({
    String? id,
    String? name,
    IngredientCategory? category,
    String? normalizedName,
    List<String>? searchAliases,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      normalizedName: normalizedName ?? this.normalizedName,
      searchAliases: searchAliases ?? this.searchAliases,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'normalizedName': normalizedName,
        'searchAliases': searchAliases,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id'] as String,
        name: json['name'] as String,
        category: IngredientCategory.values.firstWhere(
          (value) => value.name == json['category'],
          orElse: () => IngredientCategory.other,
        ),
        normalizedName: json['normalizedName'] as String?,
        searchAliases: (json['searchAliases'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

class QuantityInfo {
  const QuantityInfo({this.amount, this.unit});

  final double? amount;
  final String? unit;

  bool get isUnknown => amount == null;

  String get displayText {
    if (amount == null) return 'Unknown quantity';
    final formatted = amount == amount!.roundToDouble() ? amount!.toInt().toString() : amount!.toString();
    return unit == null || unit!.trim().isEmpty ? formatted : '$formatted $unit';
  }

  QuantityInfo copyWith({double? amount, String? unit, bool clearAmount = false, bool clearUnit = false}) {
    return QuantityInfo(
      amount: clearAmount ? null : (amount ?? this.amount),
      unit: clearUnit ? null : (unit ?? this.unit),
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'unit': unit,
      };

  factory QuantityInfo.fromJson(Map<String, dynamic> json) => QuantityInfo(
        amount: (json['amount'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
      );
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.ingredient,
    this.quantityInfo = const QuantityInfo(),
    this.freshnessState = FreshnessState.unknown,
    this.confidence = 1,
    this.sourceType = PantrySourceType.manual,
    this.createdAt,
    this.updatedAt,
    this.notes,
  });

  final String id;
  final Ingredient ingredient;
  final QuantityInfo quantityInfo;
  final FreshnessState freshnessState;
  final double confidence;
  final PantrySourceType sourceType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;

  PantryItem copyWith({
    String? id,
    Ingredient? ingredient,
    QuantityInfo? quantityInfo,
    FreshnessState? freshnessState,
    double? confidence,
    PantrySourceType? sourceType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    bool clearNotes = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      ingredient: ingredient ?? this.ingredient,
      quantityInfo: quantityInfo ?? this.quantityInfo,
      freshnessState: freshnessState ?? this.freshnessState,
      confidence: confidence ?? this.confidence,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  bool get hasAiConfidence => sourceType != PantrySourceType.manual && confidence < 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredient': ingredient.toJson(),
        'quantityInfo': quantityInfo.toJson(),
        'freshnessState': freshnessState.name,
        'confidence': confidence,
        'sourceType': sourceType.name,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'notes': notes,
      };

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: json['id'] as String,
        ingredient: Ingredient.fromJson(json['ingredient'] as Map<String, dynamic>),
        quantityInfo: QuantityInfo.fromJson(json['quantityInfo'] as Map<String, dynamic>? ?? const {}),
        freshnessState: FreshnessState.values.firstWhere(
          (value) => value.name == json['freshnessState'],
          orElse: () => FreshnessState.unknown,
        ),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
        sourceType: PantrySourceType.values.firstWhere(
          (value) => value.name == json['sourceType'],
          orElse: () => PantrySourceType.manual,
        ),
        createdAt: json['createdAt'] == null ? null : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
        notes: json['notes'] as String?,
      );
}

class CapturedImage {
  const CapturedImage({
    required this.id,
    required this.path,
    required this.category,
    this.inputMethod = CaptureInputMethod.photoLibrary,
    this.createdAt,
    this.errorMessage,
  });

  final String id;
  final String path;
  final CaptureCategory category;
  final CaptureInputMethod inputMethod;
  final DateTime? createdAt;
  final String? errorMessage;

  CapturedImage copyWith({
    String? id,
    String? path,
    CaptureCategory? category,
    CaptureInputMethod? inputMethod,
    DateTime? createdAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CapturedImage(
      id: id ?? this.id,
      path: path ?? this.path,
      category: category ?? this.category,
      inputMethod: inputMethod ?? this.inputMethod,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ParsedIngredient {
  const ParsedIngredient({
    required this.id,
    required this.rawText,
    required this.suggestedName,
    required this.confidenceScore,
    required this.parseConfidence,
    required this.sourceImageId,
    this.category = IngredientCategory.other,
    this.whyDetected = 'Why we think this is here: placeholder explanation pending real AI integration.',
    this.inferredQuantity,
    this.inferredUnit,
    this.approved = true,
  });

  final String id;
  final String rawText;
  final String suggestedName;
  final double confidenceScore;
  final ParseConfidence parseConfidence;
  final String sourceImageId;
  final IngredientCategory category;
  final String whyDetected;
  final double? inferredQuantity;
  final String? inferredUnit;
  final bool approved;

  ParsedIngredient copyWith({
    String? id,
    String? rawText,
    String? suggestedName,
    double? confidenceScore,
    ParseConfidence? parseConfidence,
    String? sourceImageId,
    IngredientCategory? category,
    String? whyDetected,
    double? inferredQuantity,
    String? inferredUnit,
    bool? approved,
  }) {
    return ParsedIngredient(
      id: id ?? this.id,
      rawText: rawText ?? this.rawText,
      suggestedName: suggestedName ?? this.suggestedName,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      parseConfidence: parseConfidence ?? this.parseConfidence,
      sourceImageId: sourceImageId ?? this.sourceImageId,
      category: category ?? this.category,
      whyDetected: whyDetected ?? this.whyDetected,
      inferredQuantity: inferredQuantity ?? this.inferredQuantity,
      inferredUnit: inferredUnit ?? this.inferredUnit,
      approved: approved ?? this.approved,
    );
  }
}

class ParseSession {
  const ParseSession({
    required this.id,
    required this.images,
    required this.parsedIngredients,
    this.imageErrors = const [],
    this.createdAt,
  });

  final String id;
  final List<CapturedImage> images;
  final List<ParsedIngredient> parsedIngredients;
  final List<String> imageErrors;
  final DateTime? createdAt;

  bool get hasRecoverableErrors => imageErrors.isNotEmpty;
}

class RecipeIngredientRequirement {
  const RecipeIngredientRequirement({required this.name, required this.quantity, required this.unit});
  final String name;
  final double quantity;
  final String unit;
}

class MissingIngredient {
  const MissingIngredient({required this.name, this.substitutions = const []});
  final String name;
  final List<String> substitutions;
}

class CookingStep {
  const CookingStep({required this.order, required this.instruction, this.timerSeconds});
  final int order;
  final String instruction;
  final int? timerSeconds;
}

class PairingSuggestion {
  const PairingSuggestion({required this.title, required this.description});
  final String title;
  final String description;
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.matchType,
    required this.confidence,
    required this.whySuggested,
    required this.mealType,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.servings,
    required this.requirements,
    required this.availableIngredients,
    required this.missingIngredients,
    required this.substitutions,
    required this.steps,
    this.isAiCreated = false,
    this.dietaryTags = const [],
  });

  final String id;
  final String title;
  final String description;
  final RecipeMatchType matchType;
  final double confidence;
  final String whySuggested;
  final MealType mealType;
  final int prepMinutes;
  final int cookMinutes;
  final int servings;
  final List<RecipeIngredientRequirement> requirements;
  final List<String> availableIngredients;
  final List<MissingIngredient> missingIngredients;
  final Map<String, String> substitutions;
  final List<CookingStep> steps;
  final bool isAiCreated;
  final List<String> dietaryTags;

  int get totalMinutes => prepMinutes + cookMinutes;
}

class DietaryProfile {
  const DietaryProfile({
    this.restrictions = const [],
    this.allergies = const [],
    this.aversions = const [],
  });

  final List<String> restrictions;
  final List<String> allergies;
  final List<String> aversions;
}

class HouseholdProfile {
  const HouseholdProfile({required this.householdSize, required this.skillLevel, this.stylePreferences = const []});
  final int householdSize;
  final String skillLevel;
  final List<String> stylePreferences;
}

class ShoppingList {
  const ShoppingList({required this.id, required this.title, required this.items, this.checked = const {}});
  final String id;
  final String title;
  final List<MissingIngredient> items;
  final Set<String> checked;
}

class UserPreferences {
  const UserPreferences({
    required this.dietaryProfile,
    required this.householdProfile,
    this.preferredServings = 2,
    this.leftoverPreference = true,
    this.sodiumGoal,
    this.sugarGoal,
    this.calorieGoal,
  });

  final DietaryProfile dietaryProfile;
  final HouseholdProfile householdProfile;
  final int preferredServings;
  final bool leftoverPreference;
  final int? sodiumGoal;
  final int? sugarGoal;
  final int? calorieGoal;
}

class SavedRecipe {
  const SavedRecipe({required this.recipe, required this.savedAt});
  final RecipeSuggestion recipe;
  final DateTime savedAt;
}

class MealPlan {
  const MealPlan({required this.id, required this.day, required this.recipeIds});
  final String id;
  final DateTime day;
  final List<String> recipeIds;
}

class SubscriptionState {
  const SubscriptionState({required this.isPremium, this.tierName = 'free'});
  final bool isPremium;
  final String tierName;
}

class AdPlacement {
  const AdPlacement({required this.id, required this.placement, required this.enabled});
  final String id;
  final String placement;
  final bool enabled;
}
