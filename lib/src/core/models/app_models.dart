enum MealType { breakfast, lunch, snack, dinner, dessert }

enum RecipeMatchType { exact, nearMatch, pantryFreestyle }

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
  });

  final List<MealType> preferredMealTypes;
  final int householdSize;
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.id,
    required this.title,
    required this.matchType,
    required this.prepMinutes,
    required this.cookMinutes,
    this.reason = '',
  });

  final String id;
  final String title;
  final RecipeMatchType matchType;
  final int prepMinutes;
  final int cookMinutes;
  final String reason;

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
