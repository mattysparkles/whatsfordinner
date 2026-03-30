import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/ad_placement.dart';
import '../domain/entitlements.dart';
import 'widgets/monetization_widgets.dart';

class MonetizationScreen extends ConsumerWidget {
  const MonetizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionControllerProvider);

    return AppScaffold(
      title: 'Premium & Monetization',
      adPlacement: AdPlacement.homeBanner,
      body: ListView(
        children: [
          Card(
            child: ListTile(
              leading: Icon(subscription.isPremium ? Icons.workspace_premium : Icons.eco_outlined),
              title: Text(subscription.isPremium ? 'Premium plan' : 'Free plan'),
              subtitle: Text(
                subscription.isPremium
                    ? 'Ad-free and premium placeholders unlocked.'
                    : 'Ads may appear outside Cook Mode only.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const PremiumUpsellCard(),
          const SizedBox(height: 8),
          const Text('Premium placeholders', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const LockedFeatureTile(
            feature: PremiumFeature.adFree,
            title: 'Ad free',
            subtitle: 'Removes ads from all non-cooking screens',
          ),
          const LockedFeatureTile(
            feature: PremiumFeature.advancedDinnerPartyPlanner,
            title: 'Advanced dinner party planner',
            subtitle: 'Plan multi-course timing and prep windows',
          ),
          const LockedFeatureTile(
            feature: PremiumFeature.expandedSavedHistory,
            title: 'Expanded saved history',
            subtitle: 'Long-term pantry and recipe memory',
          ),
          const LockedFeatureTile(
            feature: PremiumFeature.advancedHouseholdProfiles,
            title: 'Advanced household profiles',
            subtitle: 'Richer profile segmentation and preferences',
          ),
          const LockedFeatureTile(
            feature: PremiumFeature.premiumAiChefMode,
            title: 'Premium AI chef mode',
            subtitle: 'Advanced coaching and adaptive cooking assistant',
          ),
          const SizedBox(height: 8),
          const Text('Ad placement mocks', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const AdPlacementSlot(placement: AdPlacement.homeBanner),
          const SizedBox(height: 8),
          const AdPlacementSlot(placement: AdPlacement.recipesNative),
          const SizedBox(height: 8),
          const AdPlacementSlot(placement: AdPlacement.rewardsPrompt),
        ],
      ),
    );
  }
}
