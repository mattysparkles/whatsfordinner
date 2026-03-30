import 'dart:convert';

import '../../core/models/app_models.dart';
import '../../core/repositories/favorites_repository.dart';
import '../../core/services/local_persistence_service.dart';

class LocalFavoritesRepository implements FavoritesRepository {
  LocalFavoritesRepository(this._persistence);

  final LocalPersistenceService _persistence;
  static const _savedKey = 'saved_recipes_v1';
  static const _historyKey = 'history_events_v1';

  @override
  Future<List<SavedRecipe>> fetchSaved() async {
    final raw = await _persistence.readString(_savedKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList(growable: false);
    return decoded.map(SavedRecipe.fromJson).toList(growable: false)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<void> saveRecipe(RecipeSuggestion recipe) async {
    final saved = [...await fetchSaved()]
      ..removeWhere((item) => item.recipeId == recipe.id)
      ..insert(
        0,
        SavedRecipe(
          recipeId: recipe.id,
          savedAt: DateTime.now(),
          recipeTitle: recipe.title,
          isPantryFreestyle: recipe.isPantryFreestyle,
        ),
      );
    await _persistSaved(saved);
  }

  @override
  Future<void> removeRecipe(String recipeId) async {
    final saved = (await fetchSaved()).where((item) => item.recipeId != recipeId).toList(growable: false);
    await _persistSaved(saved);
  }

  @override
  Future<List<HistoryEvent>> fetchHistory() async {
    final raw = await _persistence.readString(_historyKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList(growable: false);
    return decoded.map(HistoryEvent.fromJson).toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<void> addHistoryEvent(HistoryEvent event) async {
    final events = [event, ...await fetchHistory()];
    await _persistHistory(events.take(300).toList(growable: false));
  }

  Future<void> _persistSaved(List<SavedRecipe> saved) async {
    await _persistence.writeString(
      _savedKey,
      jsonEncode(saved.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  Future<void> _persistHistory(List<HistoryEvent> events) async {
    await _persistence.writeString(
      _historyKey,
      jsonEncode(events.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}
