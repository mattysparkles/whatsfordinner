import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/pantry_pilot_app.dart';
import 'src/infrastructure/persistence/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  runApp(const ProviderScope(child: PantryPilotApp()));
}
