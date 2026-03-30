import '../../core/repositories/favorites_repository.dart';
import '../../core/repositories/pantry_repository.dart';
import '../../core/repositories/preferences_repository.dart';
import 'firestore_user_cloud_store.dart';

class AccountSyncMigrationService {
  AccountSyncMigrationService({
    required PantryRepository pantryRepository,
    required PreferencesRepository preferencesRepository,
    required FavoritesRepository favoritesRepository,
    required UserCloudStore cloudStore,
  })  : _pantryRepository = pantryRepository,
        _preferencesRepository = preferencesRepository,
        _favoritesRepository = favoritesRepository,
        _cloudStore = cloudStore;

  final PantryRepository _pantryRepository;
  final PreferencesRepository _preferencesRepository;
  final FavoritesRepository _favoritesRepository;
  final UserCloudStore _cloudStore;

  Future<void> migrateLocalDataToCloud(String uid) async {
    final pantry = await _pantryRepository.fetchAll();
    final preferences = await _preferencesRepository.fetch();
    final saved = await _favoritesRepository.fetchSaved();
    final history = await _favoritesRepository.fetchHistory();

    await Future.wait([
      _cloudStore.writePantry(uid, pantry),
      _cloudStore.writePreferences(uid, preferences),
      _cloudStore.writeSavedRecipes(uid, saved),
      _cloudStore.writeRecipeHistory(uid, history),
    ]);
  }
}
