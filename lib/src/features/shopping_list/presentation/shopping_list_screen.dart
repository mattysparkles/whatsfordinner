import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Shopping List',
      body: Column(
        children: [
          PlaceholderFeatureCard(label: 'Missing ingredients list', todo: 'TODO: derive from recipe and pantry match data.'),
          PlaceholderFeatureCard(label: 'Retail links', todo: 'TODO: wire provider-specific shopping integrations.'),
        ],
      ),
    );
  }
}
