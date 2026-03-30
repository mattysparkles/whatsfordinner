import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/models/app_models.dart';
import '../core/repositories/favorites_repository.dart';
import '../core/repositories/pantry_repository.dart';
import '../core/repositories/preferences_repository.dart';
import '../core/services/recipe_service.dart';
import '../core/services/vision_service.dart';
import '../infrastructure/mock/mock_repositories.dart';
import '../infrastructure/mock/mock_services.dart';
import 'app_router.dart';

export 'app_router.dart';

final visionServiceProvider = Provider<VisionService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockVisionService();
  // TODO(api): wire production OCR/vision client.
  return MockVisionService();
});

final recipeServiceProvider = Provider<RecipeService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockRecipeService();
  // TODO(api): wire production recipe suggestion provider.
  return MockRecipeService();
});

final pantryRepositoryProvider = Provider<PantryRepository>((ref) => InMemoryPantryRepository());
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) => InMemoryPreferencesRepository());
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => InMemoryFavoritesRepository());

class PantryController extends StateNotifier<List<PantryItem>> {
  PantryController(this._repo) : super(const []) {
    load();
  }

  final PantryRepository _repo;

  Future<void> load() async => state = await _repo.fetchAll();

  Future<void> add(PantryItem item) async {
    state = [...state, item];
    await _repo.saveAll(state);
  }
}

final pantryControllerProvider = StateNotifierProvider<PantryController, List<PantryItem>>(
  (ref) => PantryController(ref.watch(pantryRepositoryProvider)),
);

final selectedMealTypeProvider = StateProvider<MealType>((_) => MealType.dinner);

final recipeSuggestionsProvider = FutureProvider<List<RecipeSuggestion>>((ref) async {
  final pantryItems = ref.watch(pantryControllerProvider);
  final mealType = ref.watch(selectedMealTypeProvider);
  final preferences = await ref.watch(preferencesRepositoryProvider).fetch();
  final service = ref.watch(recipeServiceProvider);
  return service.suggestRecipes(pantryItems: pantryItems, mealType: mealType, preferences: preferences);
});
