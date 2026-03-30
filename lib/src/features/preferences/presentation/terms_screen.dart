import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Terms of service',
      adPlacement: AdPlacement.rewardsPrompt,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Terms of service placeholder.\n\n'
          'Ship with approved legal copy and links to account/deletion policies before public launch.',
        ),
      ),
    );
  }
}
