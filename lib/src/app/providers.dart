import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/models/app_models.dart' as core;
import '../core/repositories/favorites_repository.dart';
import '../core/repositories/pantry_repository.dart';
import '../core/repositories/preferences_repository.dart';
import '../core/services/recipe_service.dart';
import '../core/services/vision_parsing_service.dart';
import '../core/services/vision_service.dart';
import '../domain/models/models.dart';
import '../features/cook_mode/domain/cook_mode_services.dart';
import '../features/cook_mode/infrastructure/mock/mock_cook_mode_services.dart';
import '../features/monetization/domain/ad_placement.dart';
import '../features/monetization/domain/entitlements.dart';
import '../features/monetization/domain/subscription_state.dart';
import '../features/monetization/infrastructure/mock/mock_monetization_services.dart';
import '../features/monetization/services/ad_service.dart';
import '../features/monetization/services/subscription_service.dart';
import '../features/shopping_list/domain/shopping_list_controller.dart';
import '../features/shopping_list/domain/shopping_services.dart';
import '../features/shopping_list/infrastructure/mock/mock_shopping_link_service.dart';
import '../infrastructure/mock/mock_repositories.dart';
import '../infrastructure/mock/mock_services.dart';
import '../infrastructure/mock/mock_vision_parsing_service.dart';
import '../infrastructure/persistence/local_pantry_repository.dart';
import 'app_router.dart';

export 'app_router.dart';

final visionServiceProvider = Provider<VisionService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockVisionService();
  return MockVisionService();
});

final visionParsingServiceProvider = Provider<VisionParsingService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockVisionParsingService();
  return MockVisionParsingService();
});

final recipeServiceProvider = Provider<RecipeSuggestionService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return MockRecipeSuggestionService();
  return MockRecipeSuggestionService();
});


final _speechCommandBusProvider = Provider<InMemorySpeechCommandBus>((ref) {
  final bus = InMemorySpeechCommandBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) => MockTextToSpeechService());

final speechCommandServiceProvider = Provider<SpeechCommandService>((ref) => ref.watch(_speechCommandBusProvider));

final mockSpeechCommandEmitterProvider = Provider<MockSpeechCommandEmitter>((
  ref,
) => ref.watch(_speechCommandBusProvider));

final keepScreenAwakeServiceProvider = Provider<KeepScreenAwakeService>((ref) => MockKeepScreenAwakeService());

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMocks) return InMemoryPantryRepository();
  return LocalPantryRepository();
});
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) => InMemoryPreferencesRepository());
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => InMemoryFavoritesRepository());

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
  PantryController(this._repo) : super(const PantryState(isLoading: true)) {
    load();
  }

  final PantryRepository _repo;
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
  }) async {
    try {
      final now = DateTime.now();
      final ingredientId = id == null ? _uuid.v4() : state.items.firstWhere((item) => item.id == id).ingredient.id;
      final item = PantryItem(
        id: id ?? _uuid.v4(),
        ingredient: Ingredient(
          id: ingredientId,
          name: ingredientName.trim(),
          normalizedName: ingredientName.trim().toLowerCase(),
          category: category,
        ),
        quantityInfo: QuantityInfo(amount: amount, unit: (unit == null || unit.trim().isEmpty) ? null : unit.trim()),
        sourceType: sourceType,
        confidence: confidence,
        freshnessState: freshnessState,
        createdAt: id == null ? now : state.items.firstWhere((item) => item.id == id).createdAt,
        updatedAt: now,
      );
      await _repo.upsert(item);
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
  (ref) => PantryController(ref.watch(pantryRepositoryProvider)),
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
    preferredMealTypes: [discovery.mealType],
    householdSize: discovery.servings,
    dietaryFilters: discovery.dietaryFilters.toList(),
    preferenceFilters: [...stored.preferenceFilters, ...discovery.preferenceFilters].toSet().toList(),
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

final shoppingLinkServiceProvider = Provider<ShoppingLinkService>((ref) => MockShoppingLinkService());

final shoppingProvidersProvider = Provider<List<core.CommerceProvider>>((ref) {
  return const [
    core.CommerceProvider(
      id: 'instacart',
      name: 'Instacart',
      capabilityLabel: core.ProviderCapabilityLabel.availableNow,
      supportsAffiliateTracking: true,
      notes: 'Mock handoff only; no direct account sync.',
    ),
    core.CommerceProvider(
      id: 'amazon',
      name: 'Amazon',
      capabilityLabel: core.ProviderCapabilityLabel.availableNow,
      supportsAffiliateTracking: true,
      notes: 'Product search links now, affiliate enhancements later.',
    ),
    core.CommerceProvider(
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

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = MockSubscriptionService();
  ref.onDispose(service.dispose);
  return service;
});

final adServiceProvider = Provider<AdService>((ref) => const MockAdService());

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(this._service) : super(SubscriptionState.free()) {
    _init();
  }

  final SubscriptionService _service;
  StreamSubscription<SubscriptionState>? _subscription;

  Future<void> _init() async {
    state = await _service.fetchCurrent();
    _subscription = _service.watchSubscription().listen((next) => state = next);
  }

  Future<void> upgradeToPremium() => _service.startPremiumCheckout();

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
  });

  final SubscriptionState subscription;
  final EntitlementSet entitlements;
  final AdService adService;

  bool hasFeature(PremiumFeature feature) => entitlements.has(feature);

  bool shouldShowAd(AdPlacement placement) {
    return adService.canRenderPlacement(placement: placement, subscription: subscription);
  }
}

final monetizationPolicyProvider = Provider<MonetizationPolicy>((ref) {
  final subscription = ref.watch(subscriptionControllerProvider);
  final entitlements = const EntitlementPolicy().resolve(subscription);
  final adService = ref.watch(adServiceProvider);
  return MonetizationPolicy(subscription: subscription, entitlements: entitlements, adService: adService);
});
