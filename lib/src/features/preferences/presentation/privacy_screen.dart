import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Privacy policy',
      adPlacement: AdPlacement.homeBanner,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Privacy policy placeholder.\n\n'
          'This screen is intentionally lightweight for MVP demos. '
          'Replace this content with production legal text before release.',
        ),
      ),
    );
  }
}
