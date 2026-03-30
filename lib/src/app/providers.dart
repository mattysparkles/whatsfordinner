import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/models.dart';
import '../domain/repositories/repository_interfaces.dart';
import '../domain/services/service_interfaces.dart';
import '../infrastructure/mock/mock_services.dart';

final visionServiceProvider = Provider<VisionParsingService>((ref) => MockVisionParsingService());
final normalizationServiceProvider = Provider<IngredientNormalizationService>((ref) => MockIngredientNormalizationService());
final recipeServiceProvider = Provider<RecipeSuggestionService>((ref) => MockRecipeSuggestionService());
final pairingServiceProvider = Provider<PairingSuggestionService>((ref) => MockPairingSuggestionService());
final shoppingLinkServiceProvider = Provider<ShoppingLinkService>((ref) => MockShoppingLinkService());
final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) => MockTextToSpeechService());
final speechCommandServiceProvider = Provider<SpeechCommandService>((ref) => MockSpeechCommandService());
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) => MockSubscriptionService());
final adServiceProvider = Provider<AdService>((ref) => MockAdService());

final pantryRepositoryProvider = Provider<PantryRepository>((ref) => InMemoryPantryRepository());
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => InMemoryFavoritesRepository());
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) => InMemoryPreferencesRepository());

class PantryController extends StateNotifier<List<PantryItem>> {
  PantryController(this._repo) : super([]) {
    load();
  }

  final PantryRepository _repo;

  Future<void> load() async => state = await _repo.getItems();

  Future<void> addItem(PantryItem item) async {
    state = [...state, item];
    await _repo.saveItems(state);
  }
}

final pantryControllerProvider = StateNotifierProvider<PantryController, List<PantryItem>>(
  (ref) => PantryController(ref.watch(pantryRepositoryProvider)),
);

final mealTypeProvider = StateProvider<MealType>((ref) => MealType.dinner);

final recipeSuggestionsProvider = FutureProvider<List<RecipeSuggestion>>((ref) async {
  final service = ref.watch(recipeServiceProvider);
  final pantry = ref.watch(pantryControllerProvider);
  final prefs = await ref.watch(preferencesRepositoryProvider).getPreferences();
  final mealType = ref.watch(mealTypeProvider);
  return service.suggestRecipes(pantry: pantry, mealType: mealType, preferences: prefs);
});
