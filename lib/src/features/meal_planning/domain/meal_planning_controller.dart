import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/app_models.dart';
import '../../../core/services/local_persistence_service.dart';

class DinnerPartyBundle {
  const DinnerPartyBundle({
    required this.appetizer,
    required this.main,
    required this.dessert,
    required this.drink,
    this.isPremiumSuggestion = false,
  });

  final RecipeSuggestion appetizer;
  final RecipeSuggestion main;
  final RecipeSuggestion dessert;
  final PairingSuggestion drink;
  final bool isPremiumSuggestion;
}

class MealPlanningState {
  const MealPlanningState({
    this.entries = const [],
    this.planHistory = const [],
    this.recentlyReused = const [],
    this.lastGeneratedShoppingList,
  });

  final List<MealPlanItem> entries;
  final List<PlannedWeek> planHistory;
  final List<PlannedWeek> recentlyReused;
  final ShoppingList? lastGeneratedShoppingList;

  MealPlanningState copyWith({
    List<MealPlanItem>? entries,
    List<PlannedWeek>? planHistory,
    List<PlannedWeek>? recentlyReused,
    ShoppingList? lastGeneratedShoppingList,
  }) {
    return MealPlanningState(
      entries: entries ?? this.entries,
      planHistory: planHistory ?? this.planHistory,
      recentlyReused: recentlyReused ?? this.recentlyReused,
      lastGeneratedShoppingList: lastGeneratedShoppingList ?? this.lastGeneratedShoppingList,
    );
  }
}

class MealPlanningController extends StateNotifier<MealPlanningState> {
  MealPlanningController(this._persistence) : super(const MealPlanningState()) {
    unawaited(load());
  }

  final LocalPersistenceService _persistence;
  static const _uuid = Uuid();
  static const _entriesKey = 'meal_plan_entries_v1';
  static const _historyKey = 'meal_plan_history_v1';
  static const _reusedKey = 'meal_plan_reused_v1';

  Future<void> load() async {
    final entries = await _readList(_entriesKey, MealPlanItem.fromJson);
    final history = await _readList(_historyKey, PlannedWeek.fromJson);
    final reused = await _readList(_reusedKey, PlannedWeek.fromJson);
    state = state.copyWith(entries: entries, planHistory: history, recentlyReused: reused);
  }

  Future<void> assignRecipe({required DateTime date, required RecipeSuggestion recipe, required String sourceLabel}) async {
    final normalizedDay = DateTime(date.year, date.month, date.day);
    final nextEntries = [
      ...state.entries.where((item) => item.date != normalizedDay),
      MealPlanItem(
        id: _uuid.v4(),
        date: normalizedDay,
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        sourceLabel: sourceLabel,
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    state = state.copyWith(entries: nextEntries);
    await _writeList(_entriesKey, nextEntries);
  }

  Future<void> commitCurrentPlan({String label = 'Weekly meal plan'}) async {
    if (state.entries.isEmpty) return;
    final snapshot = PlannedWeek(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      label: label,
      items: state.entries,
    );
    final nextHistory = [snapshot, ...state.planHistory].take(24).toList(growable: false);
    state = state.copyWith(planHistory: nextHistory);
    await _writeList(_historyKey, nextHistory);
  }

  Future<void> markPlanReused(PlannedWeek plan) async {
    final deduped = [plan, ...state.recentlyReused.where((item) => item.id != plan.id)].take(10).toList(growable: false);
    state = state.copyWith(recentlyReused: deduped);
    await _writeList(_reusedKey, deduped);
  }

  ShoppingList generateShoppingListFromPlan({required List<RecipeSuggestion> recipes}) {
    final byId = {for (final recipe in recipes) recipe.id: recipe};
    final merged = <String, ShoppingListItem>{};

    for (final entry in state.entries) {
      final recipe = byId[entry.recipeId];
      if (recipe == null) continue;
      for (final missing in recipe.missingIngredients) {
        final key = '${missing.ingredientName.trim().toLowerCase()}::${missing.unit?.trim().toLowerCase() ?? 'unitless'}';
        final current = merged[key];
        if (current == null) {
          merged[key] = ShoppingListItem(
            id: _uuid.v4(),
            ingredientName: missing.ingredientName,
            groupLabel: _inferGroup(missing.ingredientName),
            quantity: missing.shortageAmount,
            unit: missing.unit,
            note: missing.suggestedSubstitutions.isEmpty ? null : 'Subs: ${missing.suggestedSubstitutions.join(', ')}',
          );
          continue;
        }
        merged[key] = current.copyWith(
          quantity: (current.quantity ?? 0) + (missing.shortageAmount ?? 0),
          note: _mergeNotes(current.note, missing.suggestedSubstitutions.isEmpty ? null : 'Subs: ${missing.suggestedSubstitutions.join(', ')}'),
        );
      }
    }

    final shoppingList = ShoppingList(
      id: _uuid.v4(),
      title: 'Meal plan shopping list',
      createdAt: DateTime.now(),
      items: merged.values.toList(growable: false),
    );
    state = state.copyWith(lastGeneratedShoppingList: shoppingList);
    return shoppingList;
  }

  DinnerPartyBundle suggestDinnerPartyBundle({
    required List<RecipeSuggestion> suggestions,
    required bool hasPremium,
  }) {
    final appetizer = suggestions.firstWhere(
      (item) => item.dietaryTags.any((tag) => tag.toLowerCase().contains('appetizer')) || item.totalMinutes <= 20,
      orElse: () => suggestions.first,
    );
    final main = suggestions.firstWhere(
      (item) => item.matchType == RecipeMatchType.exact,
      orElse: () => suggestions.first,
    );
    final dessert = suggestions.firstWhere(
      (item) => item.dietaryTags.any((tag) => tag.toLowerCase().contains('dessert')),
      orElse: () => suggestions.last,
    );
    final drink = main.suggestedPairings.firstWhere(
      (pairing) => pairing.category == PairingCategory.wine || pairing.category == PairingCategory.cocktail,
      orElse: () => const PairingSuggestion(
        category: PairingCategory.softDrink,
        title: 'Sparkling citrus punch',
        description: 'Family-friendly drink that fits most menus.',
      ),
    );
    return DinnerPartyBundle(
      appetizer: appetizer,
      main: main,
      dessert: dessert,
      drink: drink,
      isPremiumSuggestion: !hasPremium,
    );
  }

  Future<List<T>> _readList<T>(String key, T Function(Map<String, dynamic>) decoder) async {
    final raw = await _persistence.readString(key);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(decoder).toList(growable: false);
  }

  Future<void> _writeList<T>(String key, List<T> values) async {
    final payload = values
        .map((item) => (item as dynamic).toJson() as Map<String, dynamic>)
        .toList(growable: false);
    await _persistence.writeString(key, jsonEncode(payload));
  }

  static String _inferGroup(String name) {
    final value = name.toLowerCase();
    if (['lettuce', 'onion', 'garlic', 'spinach', 'pepper', 'tomato', 'lemon', 'lime', 'cilantro', 'potato']
        .any(value.contains)) {
      return 'Produce';
    }
    if (['milk', 'cheese', 'butter', 'yogurt', 'egg', 'cream'].any(value.contains)) return 'Dairy & Eggs';
    if (['beef', 'chicken', 'fish', 'shrimp', 'salmon', 'pork', 'turkey'].any(value.contains)) return 'Protein';
    if (['rice', 'pasta', 'bread', 'tortilla', 'flour', 'salt', 'sugar', 'oil', 'vinegar', 'spice']
        .any(value.contains)) {
      return 'Pantry & Grains';
    }
    return 'Other';
  }

  static String? _mergeNotes(String? a, String? b) {
    final notes = [a?.trim(), b?.trim()].whereType<String>().where((value) => value.isNotEmpty).toSet().toList(growable: false);
    if (notes.isEmpty) return null;
    return notes.join(' • ');
  }
}
