import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/local_persistence_service.dart';

class HiveLocalPersistence implements LocalPersistenceService {
  HiveLocalPersistence._();

  static final HiveLocalPersistence instance = HiveLocalPersistence._();
  static bool _hiveReady = false;
  static final Map<String, String> _memoryFallback = <String, String>{};

  static Future<bool> bootstrap() async {
    try {
      await instance.initialize();
      _hiveReady = true;
      return true;
    } catch (_) {
      _hiveReady = false;
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
  }

  @override
  Future<String?> readString(String key) async {
    if (!_hiveReady) {
      return _memoryFallback[key];
    }
    final box = await Hive.openBox<String>('pantry_pilot_cache');
    return box.get(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    if (!_hiveReady) {
      _memoryFallback[key] = value;
      return;
    }
    final box = await Hive.openBox<String>('pantry_pilot_cache');
    await box.put(key, value);
  }
}
