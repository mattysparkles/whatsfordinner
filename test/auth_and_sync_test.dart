import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';
import 'package:pantry_pilot/src/infrastructure/auth/local_auth_repository.dart';
import 'package:pantry_pilot/src/infrastructure/cloud/account_sync_migration_service.dart';
import 'package:pantry_pilot/src/infrastructure/cloud/firestore_user_cloud_store.dart';
import 'package:pantry_pilot/src/infrastructure/cloud/synced_repositories.dart';
import 'package:pantry_pilot/src/infrastructure/mock/mock_repositories.dart';

void main() {
  group('LocalAuthRepository', () {
    test('supports guest -> upgrade -> sign out flow', () async {
      final repo = LocalAuthRepository();

      final guest = await repo.signInAnonymously();
      expect(guest.isAnonymous, isTrue);

      final upgraded = await repo.upgradeAnonymousAccount(email: 'cook@example.com', password: 'secret123');
      expect(upgraded.isAnonymous, isFalse);
      expect(upgraded.email, 'cook@example.com');

      await repo.signOut();
      expect(repo.currentUser, isNull);
    });
  });

  group('AccountSyncMigrationService', () {
    test('uploads local pantry/preferences/favorites/history to cloud store after sign in', () async {
      final pantry = InMemoryPantryRepository();
      final preferences = InMemoryPreferencesRepository();
      final favorites = InMemoryFavoritesRepository();
      final cloud = _FakeUserCloudStore();
      final service = AccountSyncMigrationService(
        pantryRepository: pantry,
        preferencesRepository: preferences,
        favoritesRepository: favorites,
        cloudStore: cloud,
      );

      await preferences.save(const UserPreferences(householdSize: 4));
      await favorites.addHistoryEvent(
        HistoryEvent(
          type: HistoryEventType.generatedFreestyleIdea,
          occurredAt: DateTime.utc(2025, 1, 1),
          recipeId: 'r1',
          recipeTitle: 'Pantry Pasta',
        ),
      );

      await service.migrateLocalDataToCloud('uid-123');

      expect(cloud.savedPantry['uid-123'], isNotNull);
      expect(cloud.savedPreferences['uid-123']?.householdSize, 4);
      expect(cloud.savedHistory['uid-123']?.length, 1);
    });
  });

  group('SyncedPreferencesRepository', () {
    test('writes local and cloud on save', () async {
      final local = InMemoryPreferencesRepository();
      final cloud = _FakeUserCloudStore();
      final repo = SyncedPreferencesRepository(local: local, cloud: cloud, uid: 'u1');

      await repo.save(const UserPreferences(householdSize: 5));

      expect((await local.fetch()).householdSize, 5);
      expect(cloud.savedPreferences['u1']?.householdSize, 5);
    });
  });
}

class _FakeUserCloudStore implements UserCloudStore {
  final Map<String, List<PantryItem>> savedPantry = {};
  final Map<String, UserPreferences> savedPreferences = {};
  final Map<String, List<SavedRecipe>> savedRecipes = {};
  final Map<String, List<HistoryEvent>> savedHistory = {};

  @override
  Future<List<PantryItem>?> readPantry(String uid) async => savedPantry[uid];

  @override
  Future<UserPreferences?> readPreferences(String uid) async => savedPreferences[uid];

  @override
  Future<List<HistoryEvent>?> readRecipeHistory(String uid) async => savedHistory[uid];

  @override
  Future<List<SavedRecipe>?> readSavedRecipes(String uid) async => savedRecipes[uid];

  @override
  Future<void> writeActiveCookSession(String uid, Map<String, dynamic>? session) async {}

  @override
  Future<void> writePantry(String uid, List<PantryItem> items) async {
    savedPantry[uid] = items;
  }

  @override
  Future<void> writePreferences(String uid, UserPreferences preferences) async {
    savedPreferences[uid] = preferences;
  }

  @override
  Future<void> writeRecipeHistory(String uid, List<HistoryEvent> history) async {
    savedHistory[uid] = history;
  }

  @override
  Future<void> writeSavedRecipes(String uid, List<SavedRecipe> recipes) async {
    savedRecipes[uid] = recipes;
  }

  @override
  Future<void> writeShoppingList(String uid, ShoppingList? list) async {}
}
