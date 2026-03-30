import '../models/models.dart';

abstract class VisionParsingService {
  Future<List<ParsedIngredient>> parseImages(List<CapturedImage> images);
}

abstract class IngredientNormalizationService {
  String normalize(String rawIngredient);
}

abstract class RecipeSuggestionService {
  Future<List<RecipeSuggestion>> suggestRecipes({
    required List<PantryItem> pantry,
    required MealType mealType,
    required UserPreferences preferences,
  });
}

abstract class PairingSuggestionService {
  Future<List<PairingSuggestion>> pairFor(RecipeSuggestion recipe);
}

abstract class ShoppingLinkService {
  Future<Map<String, Uri>> buildLinks(List<MissingIngredient> items);
}

abstract class TextToSpeechService {
  Future<void> speak(String text);
  Future<void> stop();
}

abstract class SpeechCommandService {
  Stream<String> commandStream();
}

abstract class SubscriptionService {
  Future<SubscriptionState> currentState();
  Future<void> mockUpgrade();
}

abstract class AdService {
  Future<List<AdPlacement>> placements();
}
