import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/branded_ui.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'PantryPilot',
      body: ListView(
        children: [
          const Text('Your warm kitchen co-pilot', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'Plan dinner from what you already have, with friendly guidance from scan to stovetop.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const BrandedIllustrationSlot(
            title: 'Bread-plane brand illustration slot',
            subtitle: 'Drop final hero art asset here (onboarding_hero.png).',
            icon: Icons.local_dining,
            height: 165,
          ),
          const SizedBox(height: 16),
          const _EducationCard(
            title: 'How Pantry Freestyle works',
            body:
                'Pantry Freestyle creates creative ideas from your pantry. It is perfect when you want inspiration, but still gives practical steps and substitutions.',
            icon: Icons.auto_awesome,
          ),
          const _EducationCard(
            title: 'Why image parsing needs review',
            body:
                'Photos can misread labels, portions, or similar-looking items. You always review and confirm detections before recipe generation.',
            icon: Icons.camera_alt_outlined,
          ),
          const _EducationCard(
            title: 'Exact vs Almost There',
            body:
                'Exact means you can cook now. Almost There means a short top-up list unlocks the recipe. Both are sorted for speed and fit.',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Start cooking with PantryPilot'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(pantryControllerProvider.notifier).resetWithSampleData();
              startDemoScriptMode(ref);
              if (context.mounted) {
                context.go(AppRoutes.home);
              }
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Run polished demo script'),
          ),
        ],
      ),
    );
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({required this.title, required this.body, required this.icon});

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(body),
        ),
      ),
    );
  }
}
