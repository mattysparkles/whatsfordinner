import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/pantry_pilot_app.dart';
import 'src/infrastructure/persistence/hive_local_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveLocalPersistence.bootstrap();
  runApp(const ProviderScope(child: PantryPilotApp()));
}
