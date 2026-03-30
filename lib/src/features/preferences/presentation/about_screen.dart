import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');
  static const _buildDate = String.fromEnvironment('BUILD_DATE', defaultValue: 'local-dev');

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'About PantryPilot',
      adPlacement: AdPlacement.rewardsPrompt,
      body: ListView(
        children: const [
          ListTile(
            title: Text('PantryPilot'),
            subtitle: Text('Plan meals with what you already have.'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.tag),
            title: Text('Version'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            leading: Icon(Icons.build_circle_outlined),
            title: Text('Build date'),
            subtitle: Text(_buildDate),
          ),
          ListTile(
            leading: Icon(Icons.code_outlined),
            title: Text('Architecture'),
            subtitle: Text('Feature-first presentation, domain contracts, and swappable infrastructure adapters.'),
          ),
        ],
      ),
    );
  }
}
