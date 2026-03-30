import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/app_models.dart';

class ShoppingListState {
  const ShoppingListState({
    this.list,
    this.activeProviders = const [],
    this.linkResults = const [],
    this.linksByListId = const {},
  });

  final ShoppingList? list;
  final List<CommerceProvider> activeProviders;
  final List<ShoppingLinkResult> linkResults;
  final Map<String, List<ShoppingLinkResult>> linksByListId;

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
    Map<String, List<ShoppingLinkResult>>? linksByListId,
    bool clearList = false,
  }) {
    return ShoppingListState(
      list: clearList ? null : (list ?? this.list),
      activeProviders: activeProviders ?? this.activeProviders,
      linkResults: linkResults ?? this.linkResults,
      linksByListId: linksByListId ?? this.linksByListId,
    );
  }
}

class ShoppingListController extends StateNotifier<ShoppingListState> {
  ShoppingListController({required List<CommerceProvider> providers})
      : super(ShoppingListState(activeProviders: providers));

  static const _uuid = Uuid();

  void createFromRecipe(RecipeSuggestion recipe) {
    final mergedByName = <String, ShoppingListItem>{};
    for (final ingredient in recipe.missingIngredients) {
      final normalized = ingredient.ingredientName.trim().toLowerCase();
      final existing = mergedByName[normalized];
      final inferredNote = ingredient.suggestedSubstitutions.isEmpty
          ? null
          : 'Substitutions: ${ingredient.suggestedSubstitutions.join(', ')}';
      if (existing == null) {
        mergedByName[normalized] = ShoppingListItem(
          id: _uuid.v4(),
          ingredientName: ingredient.ingredientName.trim(),
          groupLabel: _inferGroup(ingredient.ingredientName),
          quantity: ingredient.shortageAmount,
          unit: ingredient.unit,
          note: inferredNote,
        );
        continue;
      }

      final sameUnit = existing.unit?.trim().toLowerCase() == ingredient.unit?.trim().toLowerCase();
      mergedByName[normalized] = existing.copyWith(
        quantity: sameUnit ? (existing.quantity ?? 0) + (ingredient.shortageAmount ?? 0) : existing.quantity,
        note: _mergeNotes(existing.note, inferredNote),
      );
    }
    final items = mergedByName.values.toList(growable: false);

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
    final listId = state.list?.id;
    final merged = <String, ShoppingLinkResult>{
      for (final existing in state.linkResults) existing.provider.id: existing,
      for (final next in links) next.provider.id: next,
    };
    final mergedLinks = merged.values.toList(growable: false)
      ..sort((a, b) => a.provider.name.compareTo(b.provider.name));

    if (listId == null) {
      state = state.copyWith(linkResults: mergedLinks);
      return;
    }

    final previousForList = state.linksByListId[listId] ?? const <ShoppingLinkResult>[];
    final mergedForList = <String, ShoppingLinkResult>{
      for (final existing in previousForList) existing.provider.id: existing,
      for (final next in links) next.provider.id: next,
    }.values.toList(growable: false)
      ..sort((a, b) => a.provider.name.compareTo(b.provider.name));

    final nextMap = {...state.linksByListId, listId: mergedForList};
    state = state.copyWith(linkResults: mergedLinks, linksByListId: nextMap);
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
    if (['frozen', 'ice cream'].any(value.contains)) return 'Frozen';
    return 'Other';
  }

  static String? _mergeNotes(String? a, String? b) {
    final values = [a?.trim(), b?.trim()].whereType<String>().where((value) => value.isNotEmpty).toSet().toList();
    if (values.isEmpty) return null;
    return values.join(' • ');
  }
}
