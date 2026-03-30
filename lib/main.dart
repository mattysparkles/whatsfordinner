import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/pantry_pilot_app.dart';
import 'src/core/services/crash_reporting_service.dart';
import 'src/infrastructure/persistence/hive_local_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveLocalPersistence.bootstrap();

  const crashReporting = DebugCrashReportingService();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashReporting.recordError(
      details.exception,
      details.stack ?? StackTrace.current,
      reason: 'Flutter framework error',
    );
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: PantryPilotApp())),
    (error, stackTrace) => crashReporting.recordError(
      error,
      stackTrace,
      reason: 'Uncaught zone error',
    ),
  );
}
