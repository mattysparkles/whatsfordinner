import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';

class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Monetization',
      body: Column(
        children: [
          PlaceholderFeatureCard(label: 'Premium plans', todo: 'TODO: integrate StoreKit/Play Billing subscription flow.'),
          PlaceholderFeatureCard(label: 'Ads strategy', todo: 'TODO: configure ad placements and ad-free premium handling.'),
        ],
      ),
    );
  }
}
