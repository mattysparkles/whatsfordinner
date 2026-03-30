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

class Ingredient {
  const Ingredient({required this.id, required this.name, this.normalizedName});
  final String id;
  final String name;
  final String? normalizedName;
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.ingredient,
    this.quantity,
    this.unit,
    this.confidence = 1,
    this.source,
    this.notes,
  });

  final String id;
  final Ingredient ingredient;
  final double? quantity;
  final String? unit;
  final double confidence;
  final String? source;
  final String? notes;
}

class CapturedImage {
  const CapturedImage({required this.id, required this.path, required this.category});
  final String id;
  final String path;
  final CaptureCategory category;
}

class ParsedIngredient {
  const ParsedIngredient({required this.rawText, required this.suggestedName, required this.confidence});
  final String rawText;
  final String suggestedName;
  final double confidence;
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
