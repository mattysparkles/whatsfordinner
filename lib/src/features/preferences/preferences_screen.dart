import 'package:flutter/material.dart';

import '../../shared/widgets/primary_scaffold.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Preferences',
      body: ListView(
        children: const [
          ListTile(title: Text('Dietary restrictions'), subtitle: Text('Vegetarian, vegan, keto, etc.')),
          ListTile(title: Text('Allergies'), subtitle: Text('Peanuts, shellfish, dairy...')),
          ListTile(title: Text('Aversions'), subtitle: Text('Ingredients to avoid.')),
          ListTile(title: Text('Serving count'), subtitle: Text('Default servings and leftovers preference.')),
          ListTile(title: Text('Nutrition goals'), subtitle: Text('Sodium / sugar / calorie placeholders.')),
          Card(child: ListTile(title: Text('Upgrade to Premium'), subtitle: Text('Ad-free, dinner party planner, AI chef mode'), trailing: Chip(label: Text('Placeholder')))),
        ],
      ),
    );
  }
}
