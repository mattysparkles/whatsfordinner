import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/app_models.dart';

class ShoppingListState {
  const ShoppingListState({
    this.list,
    this.activeProviders = const [],
    this.linkResults = const [],
  });

  final ShoppingList? list;
  final List<CommerceProvider> activeProviders;
  final List<ShoppingLinkResult> linkResults;

  bool get hasList => list != null && list!.items.isNotEmpty;

  Map<String, List<ShoppingListItem>> get groupedItems {
    final current = list;
    if (current == null) return const {};
    final buckets = <String, List<ShoppingListItem>>{};
    for (final item in current.items) {
      buckets.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    final sortedKeys = buckets.keys.toList()..sort((a, b) => a.compareTo(b));
    return {
      for (final key in sortedKeys)
        key: (buckets[key]!..sort((a, b) => a.ingredientName.compareTo(b.ingredientName))),
    };
  }

  ShoppingListState copyWith({
    ShoppingList? list,
    List<CommerceProvider>? activeProviders,
    List<ShoppingLinkResult>? linkResults,
    bool clearList = false,
  }) {
    return ShoppingListState(
      list: clearList ? null : (list ?? this.list),
      activeProviders: activeProviders ?? this.activeProviders,
      linkResults: linkResults ?? this.linkResults,
    );
  }
}

class ShoppingListController extends StateNotifier<ShoppingListState> {
  ShoppingListController({required List<CommerceProvider> providers})
      : super(ShoppingListState(activeProviders: providers));

  static const _uuid = Uuid();

  void createFromRecipe(RecipeSuggestion recipe) {
    final items = recipe.missingIngredients
        .map(
          (ingredient) => ShoppingListItem(
            id: _uuid.v4(),
            ingredientName: ingredient.ingredientName,
            groupLabel: _inferGroup(ingredient.ingredientName),
            quantity: ingredient.shortageAmount,
            unit: ingredient.unit,
          ),
        )
        .toList(growable: false);

    state = state.copyWith(
      list: ShoppingList(
        id: _uuid.v4(),
        title: '${recipe.title} shopping list',
        createdAt: DateTime.now(),
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        items: items,
      ),
      linkResults: const [],
    );
  }

  void toggleChecked(String itemId) {
    final list = state.list;
    if (list == null) return;
    state = state.copyWith(
      list: list.copyWith(
        items: list.items
            .map((item) => item.id == itemId ? item.copyWith(isChecked: !item.isChecked) : item)
            .toList(growable: false),
      ),
    );
  }

  void updateQuantity(String itemId, String text) {
    final list = state.list;
    if (list == null) return;
    final parsed = double.tryParse(text.trim());
    state = state.copyWith(
      list: list.copyWith(
        items: list.items
            .map((item) => item.id == itemId
                ? (parsed == null ? item.copyWith(clearQuantity: true) : item.copyWith(quantity: parsed))
                : item)
            .toList(growable: false),
      ),
    );
  }

  void updateNotes(String itemId, String notes) {
    final list = state.list;
    if (list == null) return;
    final cleaned = notes.trim();
    state = state.copyWith(
      list: list.copyWith(
        items: list.items
            .map((item) => item.id == itemId
                ? (cleaned.isEmpty ? item.copyWith(clearNote: true) : item.copyWith(note: cleaned))
                : item)
            .toList(growable: false),
      ),
    );
  }

  void removeItem(String itemId) {
    final list = state.list;
    if (list == null) return;
    state = state.copyWith(list: list.copyWith(items: list.items.where((item) => item.id != itemId).toList(growable: false)));
  }

  void setLinkResults(List<ShoppingLinkResult> links) {
    state = state.copyWith(linkResults: links);
  }

  static String _inferGroup(String name) {
    final value = name.toLowerCase();
    if (['lettuce', 'onion', 'garlic', 'spinach', 'pepper', 'tomato'].any(value.contains)) return 'Produce';
    if (['milk', 'cheese', 'butter', 'yogurt', 'egg'].any(value.contains)) return 'Dairy & Eggs';
    if (['beef', 'chicken', 'fish', 'shrimp', 'salmon'].any(value.contains)) return 'Protein';
    if (['rice', 'pasta', 'bread', 'tortilla', 'flour'].any(value.contains)) return 'Pantry & Grains';
    return 'Other';
  }
}
