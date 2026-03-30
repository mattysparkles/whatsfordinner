import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';

class FavoritesHistoryScreen extends StatelessWidget {
  const FavoritesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Favorites & History',
      body: Column(
        children: [
          PlaceholderFeatureCard(label: 'Saved recipes', todo: 'TODO: load and sort saved recipes.'),
          PlaceholderFeatureCard(label: 'Cook history', todo: 'TODO: store and replay recently cooked recipes.'),
        ],
      ),
    );
  }
}
