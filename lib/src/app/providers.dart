import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/config/feature_flags.dart';
import '../core/models/app_models.dart' as core;
import '../core/models/auth_models.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/favorites_repository.dart';
import '../core/repositories/pantry_repository.dart';
import '../core/repositories/preferences_repository.dart';
import '../core/services/recipe_service.dart';
import '../core/services/vision_parsing_service.dart';
import '../core/services/vision_service.dart';
import '../core/services/pantry_intelligence_service.dart';
import '../core/services/analytics_service.dart';
import '../core/services/crash_reporting_service.dart';
import '../core/services/local_persistence_service.dart';
import '../core/services/user_error_messaging_service.dart';
import '../domain/models/models.dart';
import '../features/capture/application/capture_import_service.dart';
import '../features/cook_mode/domain/cook_mode_services.dart';
import '../features/cook_mode/infrastructure/device/device_cook_mode_services.dart';
import '../features/cook_mode/infrastructure/mock/mock_cook_mode_services.dart';
import '../features/monetization/domain/ad_placement.dart';
import '../features/monetization/domain/entitlements.dart';
import '../features/monetization/domain/subscription_state.dart';
import '../features/monetization/domain/monetization_models.dart';
import '../features/monetization/infrastructure/mock/mock_monetization_services.dart';
import '../features/monetization/infrastructure/revenuecat/revenuecat_subscription_service.dart';
import '../features/monetization/infrastructure/ads/google_mobile_ads_service.dart';
import '../features/monetization/services/ad_service.dart';
import '../features/monetization/services/subscription_service.dart';
import '../features/monetization/services/monetization_remote_config_service.dart';
import '../features/meal_planning/domain/meal_planning_controller.dart';
import '../features/shopping_list/domain/shopping_list_controller.dart';
import '../features/shopping_list/domain/shopping_services.dart';
import '../features/shopping_list/infrastructure/adapters/amazon_link_adapter.dart';
import '../features/shopping_list/infrastructure/adapters/instacart_link_adapter.dart';
import '../features/shopping_list/infrastructure/adapters/backend/backend_instacart_link_adapter.dart';
import '../features/shopping_list/infrastructure/adapters/shopping_link_service_impl.dart';
import '../features/shopping_list/infrastructure/adapters/web_fallback_adapter.dart';
import '../infrastructure/mock/mock_repositories.dart';
import '../infrastructure/mock/mock_services.dart';
import '../infrastructure/gateway/gateway_recipe_suggestion_service.dart';
import '../infrastructure/mock/mock_vision_parsing_service.dart';
import '../infrastructure/gateway/gateway_vision_parsing_service.dart';
import '../infrastructure/gateway/pantry_gateway_client.dart';
import '../infrastructure/auth/firebase_auth_repository.dart';
import '../infrastructure/auth/local_auth_repository.dart';
import '../infrastructure/cloud/account_sync_migration_service.dart';
import '../infrastructure/cloud/firestore_user_cloud_store.dart';
import '../infrastructure/cloud/synced_repositories.dart';
import '../infrastructure/persistence/hive_local_persistence.dart';
import '../infrastructure/persistence/local_favorites_repository.dart';
import '../infrastructure/persistence/local_pantry_repository.dart';
import '../infrastructure/persistence/local_preferences_repository.dart';
import 'app_router.dart';

export 'app_router.dart';

final appFeatureFlagsProvider = Provider<FeatureFlags>((ref) {
  final config = ref.watch(appConfigProvider);
  return FeatureFlags(
    useProductionAiServices: config.featureUseProductionAiServices,
    enableInstacartProvider: config.featureEnableInstacartProvider,
    enableAmazonProvider: config.featureEnableAmazonProvider,
    enableWebFallbackProvider: config.featureEnableWebFallbackProvider,
    enableAds: config.featureEnableAds,
    enablePremiumFeatures: config.featureEnablePremiumFeatures,
  );
});

final analyticsServiceProvider = Provider<AnalyticsService>((_) => const DebugAnalyticsService());
final crashReportingServiceProvider = Provider<CrashReportingService>((_) => const DebugCrashReportingService());
final userErrorMessagingServiceProvider = Provider<UserErrorMessagingService>((_) => const UserErrorMessagingService());

final visionServiceProvider = Provider<VisionService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockVisionService();
  throw UnsupportedError('VisionService is not wired for production yet. Set USE_MOCKS=true.');
});


final captureImportServiceProvider = Provider<CaptureImportService>((ref) => CaptureImportService());
final pantryIntelligenceServiceProvider = Provider<PantryIntelligenceService>((ref) => const PantryIntelligenceService());

final pantryGatewayClientProvider = Provider<PantryGatewayClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return PantryGatewayClient(baseUrl: config.gatewayApiBaseUrl);
});

final visionParsingServiceProvider = Provider<VisionParsingService>((ref) {
  final config = ref.watch(appConfigProvider);
  final flags = ref.watch(appFeatureFlagsProvider);
  if (config.useMocks || !flags.useProductionAiServices) return MockVisionParsingService();
  return GatewayVisionParsingService(client: ref.watch(pantryGatewayClientProvider));
});

final recipeServiceProvider = Provider<RecipeSuggestionService>((ref) {
  final config = ref.watch(appConfigProvider);
  final flags = ref.watch(appFeatureFlagsProvider);
  if (config.useMocks || !flags.useProductionAiServices) return MockRecipeSuggestionService();
  return GatewayRecipeSuggestionService(client: ref.watch(pantryGatewayClientProvider));
});


final _speechCommandBusProvider = Provider<InMemorySpeechCommandBus>((ref) {
  final bus = InMemorySpeechCommandBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockTextToSpeechService();
  return DeviceTextToSpeechService();
});

final speechCommandServiceProvider = Provider<SpeechCommandService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return ref.watch(_speechCommandBusProvider);
  final service = DeviceSpeechCommandService();
  ref.onDispose(service.dispose);
  return service;
});

final mockSpeechCommandEmitterProvider = Provider<MockSpeechCommandEmitter>((ref) {
  final service = ref.watch(speechCommandServiceProvider);
  if (service is MockSpeechCommandEmitter) return service;
  return ref.watch(_speechCommandBusProvider);
});

final keepScreenAwakeServiceProvider = Provider<KeepScreenAwakeService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockKeepScreenAwakeService();
  return DeviceKeepScreenAwakeService();
});

final localPantryRepositoryProvider = Provider<PantryRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return InMemoryPantryRepository();
  return LocalPantryRepository();
});
final localPersistenceProvider = Provider<LocalPersistenceService>((ref) => HiveLocalPersistence.instance);
final localPreferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return LocalPreferencesRepository(ref.watch(localPersistenceProvider));
});
final localFavoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return LocalFavoritesRepository(ref.watch(localPersistenceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  try {
    return FirebaseAuthRepository(FirebaseAuth.instance);
  } catch (_) {
    return LocalAuthRepository()..signInAnonymously();
  }
});

final authStateProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());
final firestoreUserCloudStoreProvider = Provider<FirestoreUserCloudStore>((ref) {
  final store = FirestoreUserCloudStore(FirebaseFirestore.instance);
  final config = ref.watch(appConfigProvider);
  unawaited(store.enableLocalCacheAndMaybeEmulator(useEmulator: config.useFirebaseEmulators));
  return store;
});

final migrationServiceProvider = Provider<AccountSyncMigrationService>((ref) {
  return AccountSyncMigrationService(
    pantryRepository: ref.watch(localPantryRepositoryProvider),
    preferencesRepository: ref.watch(localPreferencesRepositoryProvider),
    favoritesRepository: ref.watch(localFavoritesRepositoryProvider),
    cloudStore: ref.watch(firestoreUserCloudStoreProvider),
  );
});

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final local = ref.watch(localPantryRepositoryProvider);
  if (user == null || user.isAnonymous) return local;
  return SyncedPantryRepository(local: local, cloud: ref.watch(firestoreUserCloudStoreProvider), uid: user.uid);
});
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final local = ref.watch(localPreferencesRepositoryProvider);
  if (user == null || user.isAnonymous) return local;
  return SyncedPreferencesRepository(local: local, cloud: ref.watch(firestoreUserCloudStoreProvider), uid: user.uid);
});
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final local = ref.watch(localFavoritesRepositoryProvider);
  if (user == null || user.isAnonymous) return local;
  return SyncedFavoritesRepository(local: local, cloud: ref.watch(firestoreUserCloudStoreProvider), uid: user.uid);
});

final selectedRecipeProvider = StateProvider<core.RecipeSuggestion?>((_) => null);
final isDebugModeProvider = Provider<bool>((_) => kDebugMode);
final mealPlanningControllerProvider = StateNotifierProvider<MealPlanningController, MealPlanningState>(
  (ref) => MealPlanningController(ref.watch(localPersistenceProvider)),
);

class AccountController extends StateNotifier<AsyncValue<AuthUser?>> {
  AccountController(this._ref) : super(const AsyncData(null)) {
    _subscription = _ref.listenManual<AsyncValue<AuthUser?>>(
      authStateProvider,
      (_, next) => state = next,
      fireImmediately: true,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AuthUser?>> _subscription;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);

  Future<void> signInGuest() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _auth.signInAnonymously());
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _auth.signInWithEmailPassword(email: email, password: password);
      await _ref.read(migrationServiceProvider).migrateLocalDataToCloud(user.uid);
      return user;
    });
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _auth.signUpWithEmailPassword(email: email, password: password);
      await _ref.read(migrationServiceProvider).migrateLocalDataToCloud(user.uid);
      return user;
    });
  }

  Future<void> upgradeGuestAccount(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _auth.upgradeAnonymousAccount(email: email, password: password);
      await _ref.read(migrationServiceProvider).migrateLocalDataToCloud(user.uid);
      return user;
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final accountControllerProvider = StateNotifierProvider<AccountController, AsyncValue<AuthUser?>>(
  (ref) => AccountController(ref),
);

class PreferencesController extends StateNotifier<AsyncValue<core.UserPreferences>> {
  PreferencesController(this._repo) : super(const AsyncLoading()) {
    load();
  }

  final PreferencesRepository _repo;

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetch);
  }

  Future<void> save(core.UserPreferences next) async {
    state = const AsyncLoading();
    await _repo.save(next);
    state = AsyncData(next);
  }
}

final preferencesControllerProvider = StateNotifierProvider<PreferencesController, AsyncValue<core.UserPreferences>>(
  (ref) => PreferencesController(ref.watch(preferencesRepositoryProvider)),
);

enum RecipeHistorySort { newest, oldest, title }

class FavoritesHistoryFilters {
  const FavoritesHistoryFilters({this.searchQuery = '', this.savedOnlyFreestyle = false, this.historyType, this.historySort = RecipeHistorySort.newest});

  final String searchQuery;
  final bool savedOnlyFreestyle;
  final core.HistoryEventType? historyType;
  final RecipeHistorySort historySort;

  FavoritesHistoryFilters copyWith({
    String? searchQuery,
    bool? savedOnlyFreestyle,
    core.HistoryEventType? historyType,
    RecipeHistorySort? historySort,
    bool clearHistoryType = false,
  }) {
    return FavoritesHistoryFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      savedOnlyFreestyle: savedOnlyFreestyle ?? this.savedOnlyFreestyle,
      historyType: clearHistoryType ? null : (historyType ?? this.historyType),
      historySort: historySort ?? this.historySort,
    );
  }
}

class FavoritesHistoryState {
  const FavoritesHistoryState({
    this.savedRecipes = const [],
    this.history = const [],
    this.filters = const FavoritesHistoryFilters(),
    this.isLoading = false,
  });

  final List<core.SavedRecipe> savedRecipes;
  final List<core.HistoryEvent> history;
  final FavoritesHistoryFilters filters;
  final bool isLoading;

  List<core.SavedRecipe> get filteredSaved {
    final query = filters.searchQuery.trim().toLowerCase();
    var items = savedRecipes.where((item) {
      final matchesText = query.isEmpty || item.recipeTitle.toLowerCase().contains(query);
      final matchesFreestyle = !filters.savedOnlyFreestyle || item.isPantryFreestyle;
      return matchesText && matchesFreestyle;
    }).toList(growable: false);
    if (filters.historySort == RecipeHistorySort.oldest) {
      items = [...items]..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    } else if (filters.historySort == RecipeHistorySort.title) {
      items = [...items]..sort((a, b) => a.recipeTitle.compareTo(b.recipeTitle));
    } else {
      items = [...items]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    }
    return items;
  }

  List<core.HistoryEvent> get filteredHistory {
    final query = filters.searchQuery.trim().toLowerCase();
    var items = history.where((item) {
      final matchesText = query.isEmpty || item.recipeTitle.toLowerCase().contains(query);
      final matchesType = filters.historyType == null || item.type == filters.historyType;
      return matchesText && matchesType;
    }).toList(growable: false);
    if (filters.historySort == RecipeHistorySort.oldest) {
      items = [...items]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    } else if (filters.historySort == RecipeHistorySort.title) {
      items = [...items]..sort((a, b) => a.recipeTitle.compareTo(b.recipeTitle));
    } else {
      items = [...items]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    }
    return items;
  }

  FavoritesHistoryState copyWith({
    List<core.SavedRecipe>? savedRecipes,
    List<core.HistoryEvent>? history,
    FavoritesHistoryFilters? filters,
    bool? isLoading,
  }) {
    return FavoritesHistoryState(
      savedRecipes: savedRecipes ?? this.savedRecipes,
      history: history ?? this.history,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoritesHistoryController extends StateNotifier<FavoritesHistoryState> {
  FavoritesHistoryController(this._repo) : super(const FavoritesHistoryState(isLoading: true)) {
    load();
  }

  final FavoritesRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final saved = await _repo.fetchSaved();
    final history = await _repo.fetchHistory();
    state = state.copyWith(savedRecipes: saved, history: history, isLoading: false);
  }

  Future<void> toggleSaved(core.RecipeSuggestion recipe) async {
    final existing = state.savedRecipes.any((item) => item.recipeId == recipe.id);
    if (existing) {
      await _repo.removeRecipe(recipe.id);
    } else {
      await _repo.saveRecipe(recipe);
      await trackEvent(type: core.HistoryEventType.savedRecipe, recipe: recipe);
    }
    await load();
  }

  Future<void> trackEvent({required core.HistoryEventType type, required core.RecipeSuggestion recipe}) async {
    final alreadyTrackedRecently = state.history.any(
      (entry) =>
          entry.type == type &&
          entry.recipeId == recipe.id &&
          DateTime.now().difference(entry.occurredAt).inMinutes < 30,
    );
    if (alreadyTrackedRecently) return;
    await _repo.addHistoryEvent(
      core.HistoryEvent(
        type: type,
        occurredAt: DateTime.now(),
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        isPantryFreestyle: recipe.isPantryFreestyle,
      ),
    );
    final history = await _repo.fetchHistory();
    state = state.copyWith(history: history);
  }

  void setSearch(String query) => state = state.copyWith(filters: state.filters.copyWith(searchQuery: query));
  void setSavedFreestyleOnly(bool enabled) =>
      state = state.copyWith(filters: state.filters.copyWith(savedOnlyFreestyle: enabled));
  void setHistoryType(core.HistoryEventType? type) =>
      state = state.copyWith(filters: state.filters.copyWith(historyType: type, clearHistoryType: type == null));
  void setSort(RecipeHistorySort sort) => state = state.copyWith(filters: state.filters.copyWith(historySort: sort));
}

final favoritesHistoryControllerProvider = StateNotifierProvider<FavoritesHistoryController, FavoritesHistoryState>(
  (ref) => FavoritesHistoryController(ref.watch(favoritesRepositoryProvider)),
);

class PantryFilters {
  const PantryFilters({this.category, this.sourceType, this.freshnessState});

  final IngredientCategory? category;
  final PantrySourceType? sourceType;
  final FreshnessState? freshnessState;

  PantryFilters copyWith({
    IngredientCategory? category,
    PantrySourceType? sourceType,
    FreshnessState? freshnessState,
    bool clearCategory = false,
    bool clearSource = false,
    bool clearFreshness = false,
  }) {
    return PantryFilters(
      category: clearCategory ? null : (category ?? this.category),
      sourceType: clearSource ? null : (sourceType ?? this.sourceType),
      freshnessState: clearFreshness ? null : (freshnessState ?? this.freshnessState),
    );
  }
}

class PantryState {
  const PantryState({
    this.items = const [],
    this.searchQuery = '',
    this.filters = const PantryFilters(),
    this.isLoading = false,
    this.errorMessage,
  });

  final List<PantryItem> items;
  final String searchQuery;
  final PantryFilters filters;
  final bool isLoading;
  final String? errorMessage;

  List<PantryItem> get filteredItems {
    return items.where((item) {
      final query = searchQuery.trim().toLowerCase();
      final categoryMatch = filters.category == null || item.ingredient.category == filters.category;
      final sourceMatch = filters.sourceType == null || item.sourceType == filters.sourceType;
      final freshnessMatch = filters.freshnessState == null || item.freshnessState == filters.freshnessState;
      final textMatch = query.isEmpty ||
          item.ingredient.name.toLowerCase().contains(query) ||
          item.ingredient.searchAliases.any((alias) => alias.toLowerCase().contains(query));
      return categoryMatch && sourceMatch && freshnessMatch && textMatch;
    }).toList(growable: false)
      ..sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
  }

  PantryState copyWith({
    List<PantryItem>? items,
    String? searchQuery,
    PantryFilters? filters,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PantryState(
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<IngredientCategory, List<PantryItem>> get groupedByCategory {
    final grouped = <IngredientCategory, List<PantryItem>>{};
    for (final item in filteredItems) {
      grouped.putIfAbsent(item.ingredient.category, () => <PantryItem>[]).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.name.compareTo(b.name));
    return {
      for (final key in sortedKeys)
        key: (grouped[key]!..sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name))),
    };
  }
}

class PantryController extends StateNotifier<PantryState> {
  PantryController(this._repo, this._intelligence) : super(const PantryState(isLoading: true)) {
    load();
  }

  final PantryRepository _repo;
  final PantryIntelligenceService _intelligence;
  static const _uuid = Uuid();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.fetchAll();
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: 'Unable to load pantry items. ${error.toString()}');
    }
  }

  Future<void> addOrUpdateItem({
    String? id,
    required String ingredientName,
    required IngredientCategory category,
    double? amount,
    String? unit,
    PantrySourceType sourceType = PantrySourceType.manual,
    double confidence = 1,
    FreshnessState freshnessState = FreshnessState.unknown,
    PantryItemProvenanceType provenanceType = PantryItemProvenanceType.manual,
    String? provenanceSourceId,
    DateTime? purchasedAt,
    DateTime? storedAt,
    DateTime? useSoonBy,
    bool mergeCompatibleAliases = false,
  }) async {
    try {
      final now = DateTime.now();
      final normalized = _intelligence.normalizeRaw(ingredientName);
      final quantity = _intelligence.parseQuantity(ingredientName);
      final item = PantryItem(
        id: id ?? _uuid.v4(),
        ingredient: Ingredient(
          id: id == null ? _uuid.v4() : state.items.firstWhere((existing) => existing.id == id).ingredient.id,
          name: normalized.displayName,
          normalizedName: normalized.canonicalName,
          category: category,
          searchAliases: normalized.aliases,
        ),
        quantityInfo: quantity ??
            QuantityInfo(amount: amount, unit: (unit == null || unit.trim().isEmpty) ? null : unit.trim()),
        sourceType: sourceType,
        confidence: confidence,
        freshnessState: freshnessState,
        createdAt: id == null ? now : state.items.firstWhere((item) => item.id == id).createdAt,
        updatedAt: now,
        purchasedAt: purchasedAt,
        storedAt: storedAt ?? now,
        useSoonBy: useSoonBy,
        provenance: [
          PantryItemProvenance(
            type: provenanceType,
            sourceId: provenanceSourceId,
            recordedAt: now,
            confidence: confidence,
          ),
        ],
      );
      if (id != null) {
        await _repo.upsert(item);
        await load();
        return;
      }

      PantryItem? mergeTarget;
      for (final existing in state.items) {
        if (existing.ingredient.normalizedName == item.ingredient.normalizedName) {
          mergeTarget = existing;
          break;
        }
        if (mergeCompatibleAliases && _intelligence.isAliasCompatible(existing.ingredient.name, item.ingredient.name)) {
          mergeTarget = existing;
          break;
        }
      }

      await _repo.upsert(mergeTarget == null ? item : _intelligence.mergePantryItems(existing: mergeTarget, incoming: item));
      await load();
    } catch (error) {
      state = state.copyWith(errorMessage: 'Unable to save pantry item. ${error.toString()}');
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repo.deleteById(id);
      await load();
    } catch (error) {
      state = state.copyWith(errorMessage: 'Unable to delete pantry item. ${error.toString()}');
    }
  }

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void clearError() => state = state.copyWith(clearError: true);
  void setSourceFilter(PantrySourceType? sourceType) => state = state.copyWith(
    filters: state.filters.copyWith(sourceType: sourceType, clearSource: sourceType == null),
  );
  void setFreshnessFilter(FreshnessState? freshness) => state = state.copyWith(
    filters: state.filters.copyWith(freshnessState: freshness, clearFreshness: freshness == null),
  );
  void setCategoryFilter(IngredientCategory? category) => state = state.copyWith(
    filters: state.filters.copyWith(category: category, clearCategory: category == null),
  );

  Future<String> exportJsonPlaceholder() => _repo.exportToJson();

  Future<void> importJsonPlaceholder(String jsonPayload) async {
    try {
      await _repo.importFromJson(jsonPayload);
      await load();
    } catch (error) {
      state = state.copyWith(errorMessage: 'Unable to import pantry data. ${error.toString()}');
    }
  }

  Future<void> resetWithSampleData() async {
    await _repo.saveAll(_samplePantryItems());
    await load();
  }
}

final pantryControllerProvider = StateNotifierProvider<PantryController, PantryState>(
  (ref) => PantryController(ref.watch(pantryRepositoryProvider), ref.watch(pantryIntelligenceServiceProvider)),
);

final pantryQuickAddSuggestionsProvider = Provider<List<String>>((ref) {
  return const ['Eggs', 'Milk', 'Butter', 'Olive oil', 'Garlic', 'Onion', 'Rice', 'Pasta', 'Spinach', 'Tomatoes'];
});

List<PantryItem> _samplePantryItems() {
  const nowYear = 2026;
  return [
    PantryItem(
      id: 'sample-pasta',
      ingredient: const Ingredient(id: 'ingredient-pasta', name: 'Pasta', category: IngredientCategory.grainsBread),
      quantityInfo: const QuantityInfo(amount: 1, unit: 'box'),
      createdAt: DateTime(nowYear, 3, 1),
      updatedAt: DateTime(nowYear, 3, 1),
    ),
    PantryItem(
      id: 'sample-tomatoes',
      ingredient: const Ingredient(id: 'ingredient-tomatoes', name: 'Tomatoes', category: IngredientCategory.cannedJarred),
      quantityInfo: const QuantityInfo(amount: 2, unit: 'cans'),
      sourceType: PantrySourceType.aiImport,
      confidence: 0.84,
      createdAt: DateTime(nowYear, 3, 2),
      updatedAt: DateTime(nowYear, 3, 2),
    ),
    PantryItem(
      id: 'sample-garlic',
      ingredient: const Ingredient(id: 'ingredient-garlic', name: 'Garlic', category: IngredientCategory.produce),
      quantityInfo: const QuantityInfo(amount: 1, unit: 'head'),
      createdAt: DateTime(nowYear, 3, 3),
      updatedAt: DateTime(nowYear, 3, 3),
    ),
  ];
}

class RecipeDiscoveryState {
  const RecipeDiscoveryState({
    this.mealType = core.MealType.dinner,
    this.dietaryFilters = const {},
    this.preferenceFilters = const {},
    this.servings = 2,
    this.sortOption = core.RecipeSortOption.fastest,
  });

  final core.MealType mealType;
  final Set<String> dietaryFilters;
  final Set<String> preferenceFilters;
  final int servings;
  final core.RecipeSortOption sortOption;

  RecipeDiscoveryState copyWith({
    core.MealType? mealType,
    Set<String>? dietaryFilters,
    Set<String>? preferenceFilters,
    int? servings,
    core.RecipeSortOption? sortOption,
  }) {
    return RecipeDiscoveryState(
      mealType: mealType ?? this.mealType,
      dietaryFilters: dietaryFilters ?? this.dietaryFilters,
      preferenceFilters: preferenceFilters ?? this.preferenceFilters,
      servings: servings ?? this.servings,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

class RecipeDiscoveryController extends StateNotifier<RecipeDiscoveryState> {
  RecipeDiscoveryController() : super(const RecipeDiscoveryState());

  void setMealType(core.MealType type) => state = state.copyWith(mealType: type);

  void toggleDietaryFilter(String tag) {
    final next = {...state.dietaryFilters};
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    state = state.copyWith(dietaryFilters: next);
  }

  void togglePreferenceFilter(String tag) {
    final next = {...state.preferenceFilters};
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    state = state.copyWith(preferenceFilters: next);
  }

  void setServings(int servings) => state = state.copyWith(servings: servings);
  void setSortOption(core.RecipeSortOption option) => state = state.copyWith(sortOption: option);
}

final recipeDiscoveryProvider = StateNotifierProvider<RecipeDiscoveryController, RecipeDiscoveryState>(
  (ref) => RecipeDiscoveryController(),
);

final recipeGenerationTickProvider = StateProvider<int>((_) => 0);

final recipeSuggestionsProvider = FutureProvider<List<core.RecipeSuggestion>>((ref) async {
  ref.watch(recipeGenerationTickProvider);
  final pantryItems = ref.watch(pantryControllerProvider).items;
  final discovery = ref.watch(recipeDiscoveryProvider);
  final preferencesRepo = ref.watch(preferencesRepositoryProvider);
  final stored = await preferencesRepo.fetch();
  final preferences = core.UserPreferences(
    preferredMealTypes: [discovery.mealType, ...stored.preferredMealTypes].toSet().toList(growable: false),
    householdSize: discovery.servings,
    dietaryFilters: [...stored.dietaryFilters, ...discovery.dietaryFilters].toSet().toList(growable: false),
    preferenceFilters: [
      ...stored.preferenceFilters,
      ...discovery.preferenceFilters,
      if (stored.lowSodium) 'low-sodium',
      if (stored.lowSugar) 'low-sugar',
      if (stored.lowerCalorie) 'lower-calorie',
    ].toSet().toList(growable: false),
    allergies: stored.allergies,
    aversions: stored.aversions,
    cookingSkillLevel: stored.cookingSkillLevel,
    leftoverPreference: stored.leftoverPreference,
    lowSodium: stored.lowSodium,
    lowSugar: stored.lowSugar,
    lowerCalorie: stored.lowerCalorie,
    showMockControlsInDebug: stored.showMockControlsInDebug,
    analyticsConsentPlaceholder: stored.analyticsConsentPlaceholder,
    aiVoiceDisclosureAcknowledged: stored.aiVoiceDisclosureAcknowledged,
  );
  final service = ref.watch(recipeServiceProvider);
  final mappedItems = pantryItems
      .map(
        (item) => core.PantryItem(
          id: item.id,
          name: item.ingredient.name.toLowerCase(),
          quantity: item.quantityInfo.amount,
          unit: item.quantityInfo.unit,
        ),
      )
      .toList(growable: false);

  final suggestions = await service.suggestRecipes(
    pantryItems: mappedItems,
    mealType: discovery.mealType,
    preferences: preferences,
    servings: discovery.servings,
  );
  final historyController = ref.read(favoritesHistoryControllerProvider.notifier);
  for (final idea in suggestions.where((item) => item.isPantryFreestyle)) {
    await historyController.trackEvent(type: core.HistoryEventType.generatedFreestyleIdea, recipe: idea);
  }
  await ref.read(analyticsServiceProvider).logEvent(
    AppAnalyticsEvent.recipeSuggestionsGenerated,
    parameters: {
      'total': suggestions.length,
      'pantryFreestyleCount': suggestions.where((item) => item.isPantryFreestyle).length,
      'mealType': discovery.mealType.name,
    },
  );
  return _sortSuggestions(suggestions, discovery.sortOption);
});

List<core.RecipeSuggestion> _sortSuggestions(List<core.RecipeSuggestion> suggestions, core.RecipeSortOption sortOption) {
  final sorted = [...suggestions];
  sorted.sort((a, b) {
    return switch (sortOption) {
      core.RecipeSortOption.fastest => a.totalMinutes.compareTo(b.totalMinutes),
      core.RecipeSortOption.easiest => a.difficulty.compareTo(b.difficulty),
      core.RecipeSortOption.fewestMissingIngredients => a.missingIngredients.length.compareTo(b.missingIngredients.length),
      core.RecipeSortOption.familyFriendly => b.familyFriendlyScore.compareTo(a.familyFriendlyScore),
      core.RecipeSortOption.healthier => b.healthScore.compareTo(a.healthScore),
      core.RecipeSortOption.fancy => b.fancyScore.compareTo(a.fancyScore),
    };
  });
  return sorted;
}

final shoppingLinkServiceProvider = Provider<ShoppingLinkService>((ref) {
  final flags = ref.watch(appFeatureFlagsProvider);
  final config = ref.watch(appConfigProvider);
  final adapters = <ShoppingProviderAdapter>[
    if (flags.enableInstacartProvider)
      (config.useMocks || !flags.useProductionAiServices
          ? InstacartLinkAdapter()
          : BackendInstacartLinkAdapter(client: ref.watch(pantryGatewayClientProvider))),
    if (flags.enableAmazonProvider) AmazonLinkAdapter(),
    if (flags.enableWebFallbackProvider) WebFallbackAdapter(),
  ];
  return ShoppingLinkServiceImpl(adapters: adapters);
});

final shoppingProvidersProvider = Provider<List<core.CommerceProvider>>((ref) {
  final flags = ref.watch(appFeatureFlagsProvider);
  return [
    if (flags.enableInstacartProvider)
      const core.CommerceProvider(
        id: 'instacart',
        name: 'Instacart',
        capabilityLabel: core.ProviderCapabilityLabel.active,
        supportsAffiliateTracking: true,
        notes: 'Open in Instacart with prefilled list context.',
      ),
    if (flags.enableAmazonProvider)
      const core.CommerceProvider(
        id: 'amazon',
        name: 'Amazon',
        capabilityLabel: core.ProviderCapabilityLabel.configuredButUnavailable,
        supportsAffiliateTracking: true,
        notes: 'Configured fallback for item-by-item product searches.',
      ),
    if (flags.enableWebFallbackProvider)
      const core.CommerceProvider(
        id: 'web-fallback',
        name: 'Web Search',
        capabilityLabel: core.ProviderCapabilityLabel.comingLater,
        notes: 'Generic fallback adapter intentionally marked as coming later.',
      ),
  ];
});

final shoppingListControllerProvider = StateNotifierProvider<ShoppingListController, ShoppingListState>(
  (ref) => ShoppingListController(providers: ref.watch(shoppingProvidersProvider)),
);

final shoppingLinkGenerationStateProvider = StateProvider<AsyncValue<void>>((_) => const AsyncData(null));
final shoppingLinkLaunchStateProvider = StateProvider<(bool, String)?>((
  _,
) => null);

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) {
    final service = MockSubscriptionService();
    ref.onDispose(service.dispose);
    return service;
  }
  final service = RevenueCatSubscriptionService(apiKey: config.revenueCatApiKey);
  ref.onDispose(service.dispose);
  return service;
});

final monetizationRemoteConfigServiceProvider = Provider<MonetizationRemoteConfigService>((ref) {
  final config = ref.watch(appConfigProvider);
  final flags = ref.watch(appFeatureFlagsProvider);
  if (config.useMocks) {
    return LocalMonetizationRemoteConfigService(
      MonetizationRemoteFlags(
        enableAds: flags.enableAds,
        enablePremium: flags.enablePremiumFeatures,
        enablePurchases: flags.enablePremiumFeatures,
      ),
    );
  }
  return FirebaseMonetizationRemoteConfigService(FirebaseRemoteConfig.instance);
});

class MonetizationRemoteFlagsController extends StateNotifier<MonetizationRemoteFlags> {
  MonetizationRemoteFlagsController(this._service) : super(MonetizationRemoteFlags.safeDefaults) {
    load();
  }

  final MonetizationRemoteConfigService _service;

  Future<void> load() async {
    state = await _service.fetchFlags();
  }
}

final monetizationRemoteFlagsProvider = StateNotifierProvider<MonetizationRemoteFlagsController, MonetizationRemoteFlags>(
  (ref) => MonetizationRemoteFlagsController(ref.watch(monetizationRemoteConfigServiceProvider)),
);

final adServiceProvider = Provider<AdService>((ref) {
  final config = ref.watch(appConfigProvider);
  final flags = ref.watch(monetizationRemoteFlagsProvider);
  if (!flags.enableAds) return const NoOpAdService();
  if (config.useMocks) return const MockAdService();
  return GoogleMobileAdsService();
});

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(this._service) : super(SubscriptionState.free()) {
    _init();
  }

  final SubscriptionService _service;
  StreamSubscription<SubscriptionState>? _subscription;
  List<PremiumProduct> offerings = const [];

  Future<void> _init() async {
    state = await _service.fetchCurrent();
    _subscription = _service.watchSubscription().listen((next) => state = next);
    offerings = await _service.loadOfferings().catchError((_) => <PremiumProduct>[]);
  }

  Future<List<PremiumProduct>> loadOfferings() async {
    offerings = await _service.loadOfferings();
    return offerings;
  }

  Future<void> upgradeToPremium(PremiumPlanProduct plan) => _service.startPremiumCheckout(plan);

  Future<void> restorePurchases() => _service.restorePurchases();

  Future<void> downgradeToFree() async {
    final service = _service;
    if (service is MockSubscriptionService) {
      await service.debugDowngradeToFree();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final subscriptionControllerProvider = StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (ref) => SubscriptionController(ref.watch(subscriptionServiceProvider)),
);

class MonetizationPolicy {
  MonetizationPolicy({
    required this.subscription,
    required this.entitlements,
    required this.adService,
    required this.featureFlags,
    required this.remoteFlags,
  });

  final SubscriptionState subscription;
  final EntitlementSet entitlements;
  final AdService adService;
  final FeatureFlags featureFlags;
  final MonetizationRemoteFlags remoteFlags;

  bool hasFeature(PremiumFeature feature) {
    if (!featureFlags.enablePremiumFeatures || !remoteFlags.enablePremium) return false;
    return entitlements.has(feature);
  }

  bool shouldShowAd(AdPlacement placement) {
    if (!remoteFlags.enableAds) return false;
    return adService.canRenderPlacement(placement: placement, subscription: subscription);
  }
}

final monetizationPolicyProvider = Provider<MonetizationPolicy>((ref) {
  final subscription = ref.watch(subscriptionControllerProvider);
  final entitlements = const EntitlementPolicy().resolve(subscription);
  final adService = ref.watch(adServiceProvider);
  final featureFlags = ref.watch(appFeatureFlagsProvider);
  final remoteFlags = ref.watch(monetizationRemoteFlagsProvider);
  return MonetizationPolicy(
    subscription: subscription,
    entitlements: entitlements,
    adService: adService,
    featureFlags: featureFlags,
    remoteFlags: remoteFlags,
  );
});
