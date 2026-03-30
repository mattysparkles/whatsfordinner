import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract class AnalyticsService {
  Future<void> logEvent(AppAnalyticsEvent event, {Map<String, Object?> parameters = const {}});
}

enum AppAnalyticsEvent {
  captureSessionCreated,
  parseSessionCompleted,
  pantryItemApproved,
  recipeSuggestionsGenerated,
  recipeOpened,
  cookModeStarted,
  cookModeCompleted,
  shoppingHandoffStarted,
  premiumUpsellViewed,
}

class DebugAnalyticsService implements AnalyticsService {
  const DebugAnalyticsService();

  @override
  Future<void> logEvent(AppAnalyticsEvent event, {Map<String, Object?> parameters = const {}}) async {
    if (!kDebugMode) return;
    developer.log(
      'analytics:${event.name}',
      name: 'PantryPilot.Analytics',
      error: parameters.isEmpty ? null : parameters,
    );
  }
}
