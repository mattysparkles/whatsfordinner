import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';

class CookModeScreen extends StatelessWidget {
  const CookModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Cook Mode',
      body: Column(
        children: [
          PlaceholderFeatureCard(label: 'Step-by-step mode', todo: 'TODO: implement guided cooking UI and timers.'),
          PlaceholderFeatureCard(label: 'Voice controls', todo: 'TODO: integrate speech commands and TTS services.'),
        ],
      ),
    );
  }
}
