import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Preferences',
      body: Column(
        children: [
          PlaceholderFeatureCard(label: 'Dietary preferences', todo: 'TODO: persist dietary profile and allergies.'),
          PlaceholderFeatureCard(label: 'Household profile', todo: 'TODO: persist servings and cooking skill level.'),
        ],
      ),
    );
  }
}
