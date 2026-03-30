import '../models/app_models.dart';

abstract interface class PreferencesRepository {
  Future<UserPreferences> fetch();
  Future<void> save(UserPreferences preferences);
}
