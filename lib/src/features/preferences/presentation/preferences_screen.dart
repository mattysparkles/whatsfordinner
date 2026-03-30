import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Preferences',
      adPlacement: AdPlacement.rewardsPrompt,
      body: const Column(
        children: [
          PlaceholderFeatureCard(label: 'Dietary preferences', todo: 'TODO: persist dietary profile and allergies.'),
          PlaceholderFeatureCard(label: 'Household profile', todo: 'TODO: persist servings and cooking skill level.'),
          LockedFeatureTile(
            feature: PremiumFeature.advancedHouseholdProfiles,
            title: 'Advanced household profiles',
            subtitle: 'Multiple profile presets, routines, and constraints',
          ),
          PremiumUpsellCard(compact: true),
        ],
      ),
    );
  }
}
