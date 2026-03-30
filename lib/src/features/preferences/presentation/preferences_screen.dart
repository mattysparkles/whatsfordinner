import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Preferences',
      adPlacement: AdPlacement.rewardsPrompt,
      body: Column(
        children: [
          const PlaceholderFeatureCard(label: 'Dietary preferences', todo: 'TODO: persist dietary profile and allergies.'),
          const PlaceholderFeatureCard(label: 'Household profile', todo: 'TODO: persist servings and cooking skill level.'),
          const LockedFeatureTile(
            feature: PremiumFeature.advancedHouseholdProfiles,
            title: 'Advanced household profiles',
            subtitle: 'Multiple profile presets, routines, and constraints',
          ),
          const PremiumUpsellCard(compact: true),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About PantryPilot'),
                  subtitle: const Text('Version, build info, and credits'),
                  onTap: () => context.push(AppRoutes.about),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of service'),
                  onTap: () => context.push(AppRoutes.terms),
                ),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Debug menu', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Mock/developer-only actions for faster demos.'),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref.read(pantryControllerProvider.notifier).resetWithSampleData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample pantry restored.')));
                      }
                    },
                    icon: const Icon(Icons.replay_circle_filled_outlined),
                    label: const Text('Reset sample pantry data'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => ref.read(recipeGenerationTickProvider.notifier).state++,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Refresh recipe mocks'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
