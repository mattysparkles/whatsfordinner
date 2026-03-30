import '../../core/models/app_models.dart' as core;
import '../../core/repositories/favorites_repository.dart';
import '../../core/repositories/pantry_repository.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../domain/models/models.dart' as domain;
import 'firestore_user_cloud_store.dart';

class SyncedPantryRepository implements PantryRepository {
  SyncedPantryRepository({
    required PantryRepository local,
    required UserCloudStore cloud,
    required String uid,
  })  : _local = local,
        _cloud = cloud,
        _uid = uid;

  final PantryRepository _local;
  final UserCloudStore _cloud;
  final String _uid;

  @override
  Future<void> deleteById(String id) async {
    await _local.deleteById(id);
    await _syncToCloud();
  }

  @override
  Future<String> exportToJson() => _local.exportToJson();

  @override
  Future<List<domain.PantryItem>> fetchAll() async {
    final localItems = await _local.fetchAll();
    _syncToCloud();
    return localItems;
  }

  @override
  Future<void> importFromJson(String json) async {
    await _local.importFromJson(json);
    await _syncToCloud();
  }

  @override
  Future<void> saveAll(List<domain.PantryItem> items) async {
    await _local.saveAll(items);
    await _syncToCloud();
  }

  @override
  Future<void> upsert(domain.PantryItem item) async {
    await _local.upsert(item);
    await _syncToCloud();
  }

  Future<void> pullFromCloud() async {
    final cloudItems = await _cloud.readPantry(_uid);
    if (cloudItems != null && cloudItems.isNotEmpty) {
      await _local.saveAll(cloudItems);
    }
  }

  Future<void> _syncToCloud() async {
    final latest = await _local.fetchAll();
    await _cloud.writePantry(_uid, latest);
  }
}

class SyncedPreferencesRepository implements PreferencesRepository {
  SyncedPreferencesRepository({required PreferencesRepository local, required UserCloudStore cloud, required String uid})
      : _local = local,
        _cloud = cloud,
        _uid = uid;

  final PreferencesRepository _local;
  final UserCloudStore _cloud;
  final String _uid;

  @override
  Future<core.UserPreferences> fetch() async {
    final localPrefs = await _local.fetch();
    _cloud.writePreferences(_uid, localPrefs);
    return localPrefs;
  }

  @override
  Future<void> save(core.UserPreferences preferences) async {
    await _local.save(preferences);
    await _cloud.writePreferences(_uid, preferences);
  }

  Future<void> pullFromCloud() async {
    final cloud = await _cloud.readPreferences(_uid);
    if (cloud != null) {
      await _local.save(cloud);
    }
  }
}

class SyncedFavoritesRepository implements FavoritesRepository {
  SyncedFavoritesRepository({required FavoritesRepository local, required UserCloudStore cloud, required String uid})
      : _local = local,
        _cloud = cloud,
        _uid = uid;

  final FavoritesRepository _local;
  final UserCloudStore _cloud;
  final String _uid;

  @override
  Future<void> addHistoryEvent(core.HistoryEvent event) async {
    await _local.addHistoryEvent(event);
    await _syncHistory();
  }

  @override
  Future<List<core.HistoryEvent>> fetchHistory() async {
    final history = await _local.fetchHistory();
    _cloud.writeRecipeHistory(_uid, history);
    return history;
  }

  @override
  Future<List<core.SavedRecipe>> fetchSaved() async {
    final saved = await _local.fetchSaved();
    _cloud.writeSavedRecipes(_uid, saved);
    return saved;
  }

  @override
  Future<void> removeRecipe(String recipeId) async {
    await _local.removeRecipe(recipeId);
    await _syncSaved();
  }

  @override
  Future<void> saveRecipe(core.RecipeSuggestion recipe) async {
    await _local.saveRecipe(recipe);
    await _syncSaved();
  }

  Future<void> pullFromCloud() async {
    final cloudSaved = await _cloud.readSavedRecipes(_uid);
    if (cloudSaved != null) {
      for (final recipe in cloudSaved.reversed) {
        await _local.saveRecipe(
          core.RecipeSuggestion(
            id: recipe.recipeId,
            title: recipe.recipeTitle,
            shortDescription: 'Synced recipe',
            matchType: core.RecipeMatchType.pantryFreestyle,
            prepMinutes: 0,
            cookMinutes: 0,
            difficulty: 1,
            familyFriendlyScore: 0,
            healthScore: 0,
            fancyScore: 0,
            servings: 1,
            dietaryTags: const [],
            requirements: const [],
            missingIngredients: const [],
            availableIngredients: const [],
            steps: const [],
            suggestedPairings: const [],
            explanation: const core.RecipeExplanation(summary: 'Synced from cloud', pantryHighlights: []),
          ),
        );
      }
    }
  }

  Future<void> _syncSaved() async {
    await _cloud.writeSavedRecipes(_uid, await _local.fetchSaved());
  }

  Future<void> _syncHistory() async {
    await _cloud.writeRecipeHistory(_uid, await _local.fetchHistory());
  }
}
