import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class FavoritesHistoryScreen extends StatelessWidget {
  const FavoritesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Favorites & History',
      adPlacement: AdPlacement.homeBanner,
      body: const Column(
        children: [
          PlaceholderFeatureCard(label: 'Saved recipes', todo: 'TODO: load and sort saved recipes.'),
          PlaceholderFeatureCard(label: 'Cook history', todo: 'TODO: store and replay recently cooked recipes.'),
          LockedFeatureTile(
            feature: PremiumFeature.expandedSavedHistory,
            title: 'Expanded saved history',
            subtitle: 'Longer retention window and richer search',
          ),
        ],
      ),
    );
  }
}
