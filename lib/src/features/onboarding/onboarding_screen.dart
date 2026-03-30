import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/primary_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Welcome to PantryPilot',
      body: ListView(
        children: [
          const SizedBox(height: 12),
          const Text('Set up your kitchen profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Household size, dietary preferences, allergies, aversions, and cooking style.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: const [Chip(label: Text('Quick Meals')), Chip(label: Text('Family Meals')), Chip(label: Text('Healthy')), Chip(label: Text('Fancy'))]),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Finish Setup')),
        ],
      ),
    );
  }
}
