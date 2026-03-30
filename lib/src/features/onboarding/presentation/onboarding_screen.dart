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
          const Text('Turn pantry chaos into dinner plans.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            '1) Capture ingredients\n'
            '2) Approve what was detected\n'
            '3) Get practical recipes you can cook tonight',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Beta note: some experiences are mocked so demos remain stable while production integrations are finalized.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Start beta walkthrough'),
          ),
        ],
      ),
    );
  }
}
