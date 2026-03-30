import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Welcome to PantryPilot',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cook smarter with what you already have.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('Capture pantry items, review recognized ingredients, then get exact, near-match, or Pantry Freestyle recipes.'),
          const Spacer(),
          FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Get started'),
          ),
        ],
      ),
    );
  }
}
