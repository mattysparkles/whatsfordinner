import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract class CrashReportingService {
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'Unhandled error',
    Map<String, Object?> context = const {},
  });
}

class DebugCrashReportingService implements CrashReportingService {
  const DebugCrashReportingService();

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'Unhandled error',
    Map<String, Object?> context = const {},
  }) async {
    if (!kDebugMode) return;
    developer.log(
      reason,
      name: 'PantryPilot.CrashReporting',
      error: {'error': error.toString(), 'context': context},
      stackTrace: stackTrace,
    );
  }
}
