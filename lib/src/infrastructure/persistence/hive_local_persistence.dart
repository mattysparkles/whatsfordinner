import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/local_persistence_service.dart';

class HiveLocalPersistence implements LocalPersistenceService {
  HiveLocalPersistence._();

  static final HiveLocalPersistence instance = HiveLocalPersistence._();

  static Future<void> bootstrap() async {
    await instance.initialize();
  }

  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
  }

  @override
  Future<String?> readString(String key) async {
    final box = await Hive.openBox<String>('pantry_pilot_cache');
    return box.get(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    final box = await Hive.openBox<String>('pantry_pilot_cache');
    await box.put(key, value);
  }
}
