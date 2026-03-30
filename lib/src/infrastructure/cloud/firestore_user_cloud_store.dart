import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../domain/models/models.dart';

abstract interface class UserCloudStore {
  Future<void> writePantry(String uid, List<PantryItem> items);
  Future<List<PantryItem>?> readPantry(String uid);
  Future<void> writePreferences(String uid, UserPreferences preferences);
  Future<UserPreferences?> readPreferences(String uid);
  Future<void> writeSavedRecipes(String uid, List<SavedRecipe> recipes);
  Future<List<SavedRecipe>?> readSavedRecipes(String uid);
  Future<void> writeRecipeHistory(String uid, List<HistoryEvent> history);
  Future<List<HistoryEvent>?> readRecipeHistory(String uid);
  Future<void> writeShoppingList(String uid, ShoppingList? list);
  Future<void> writeActiveCookSession(String uid, Map<String, dynamic>? session);
}

class FirestoreUserCloudStore implements UserCloudStore {
  FirestoreUserCloudStore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userRoot(String uid) {
    return _firestore.collection('users').doc(uid).collection('state');
  }

  Future<void> writePantry(String uid, List<PantryItem> items) {
    return _userRoot(uid).doc('pantry_inventory').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'items': items.map((item) => item.toJson()).toList(growable: false),
    });
  }

  Future<List<PantryItem>?> readPantry(String uid) async {
    final snapshot = await _userRoot(uid).doc('pantry_inventory').get();
    final data = snapshot.data();
    if (data == null) return null;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((item) => PantryItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    return items;
  }

  Future<void> writePreferences(String uid, UserPreferences preferences) {
    return _userRoot(uid).doc('preferences').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'value': preferences.toJson(),
    });
  }

  Future<UserPreferences?> readPreferences(String uid) async {
    final snapshot = await _userRoot(uid).doc('preferences').get();
    final value = snapshot.data()?['value'];
    if (value is! Map<String, dynamic>) return null;
    return UserPreferences.fromJson(value);
  }

  Future<void> writeSavedRecipes(String uid, List<SavedRecipe> recipes) {
    return _userRoot(uid).doc('saved_recipes').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'recipes': recipes.map((item) => item.toJson()).toList(growable: false),
    });
  }

  Future<List<SavedRecipe>?> readSavedRecipes(String uid) async {
    final data = (await _userRoot(uid).doc('saved_recipes').get()).data();
    if (data == null) return null;
    return (data['recipes'] as List<dynamic>? ?? const [])
        .map((item) => SavedRecipe.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> writeRecipeHistory(String uid, List<HistoryEvent> history) {
    return _userRoot(uid).doc('recipe_history').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'events': history.map((item) => item.toJson()).toList(growable: false),
    });
  }

  Future<List<HistoryEvent>?> readRecipeHistory(String uid) async {
    final data = (await _userRoot(uid).doc('recipe_history').get()).data();
    if (data == null) return null;
    return (data['events'] as List<dynamic>? ?? const [])
        .map((item) => HistoryEvent.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> writeShoppingList(String uid, ShoppingList? list) {
    return _userRoot(uid).doc('shopping_list').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'value': list == null ? null : _shoppingListToJson(list),
    });
  }

  Future<void> writeActiveCookSession(String uid, Map<String, dynamic>? session) {
    return _userRoot(uid).doc('active_cook_session').set({
      'updatedAt': FieldValue.serverTimestamp(),
      'value': session,
    });
  }

  static Map<String, dynamic> _shoppingListToJson(ShoppingList list) {
    return {
      'id': list.id,
      'title': list.title,
      'createdAt': list.createdAt.toIso8601String(),
      'recipeId': list.recipeId,
      'recipeTitle': list.recipeTitle,
      'items': list.items
          .map(
            (item) => {
              'id': item.id,
              'ingredientName': item.ingredientName,
              'groupLabel': item.groupLabel,
              'quantity': item.quantity,
              'unit': item.unit,
              'note': item.note,
              'isChecked': item.isChecked,
            },
          )
          .toList(growable: false),
    };
  }

  Future<void> enableLocalCacheAndMaybeEmulator({required bool useEmulator}) async {
    _firestore.settings = const Settings(persistenceEnabled: true);
    if (useEmulator && !kIsWeb) {
      _firestore.useFirestoreEmulator('localhost', 8080);
    }
  }
}
