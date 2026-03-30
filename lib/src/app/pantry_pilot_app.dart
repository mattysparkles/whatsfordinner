import 'package:flutter/material.dart';

import '../core/design/app_theme.dart';
import 'app_router.dart';

class PantryPilotApp extends StatelessWidget {
  const PantryPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PantryPilot',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
