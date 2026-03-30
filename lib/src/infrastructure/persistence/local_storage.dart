import 'package:hive_flutter/hive_flutter.dart';

/// Hive bootstrap placeholder for local persistence.
/// TODO: add strongly typed adapters or migrate to Drift once schema grows.
class LocalStorage {
  static Future<void> init() async {
    await Hive.initFlutter();
  }
}
