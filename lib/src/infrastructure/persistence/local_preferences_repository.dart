import 'dart:convert';

import '../../core/models/app_models.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/services/local_persistence_service.dart';

class LocalPreferencesRepository implements PreferencesRepository {
  LocalPreferencesRepository(this._persistence);

  final LocalPersistenceService _persistence;
  static const _key = 'user_preferences_v1';

  @override
  Future<UserPreferences> fetch() async {
    final raw = await _persistence.readString(_key);
    if (raw == null || raw.trim().isEmpty) return const UserPreferences();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return UserPreferences.fromJson(json);
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    await _persistence.writeString(_key, jsonEncode(preferences.toJson()));
  }
}
