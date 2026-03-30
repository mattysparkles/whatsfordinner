import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../domain/ad_placement.dart';
import '../../domain/entitlements.dart';
import 'mock_ad_widgets.dart';

class AdPlacementSlot extends ConsumerWidget {
  const AdPlacementSlot({required this.placement, super.key});

  final AdPlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(monetizationPolicyProvider);
    if (!policy.shouldShowAd(placement)) return const SizedBox.shrink();

    return switch (placement.type) {
      AdPlacementType.banner => const MockBannerAdWidget(),
      AdPlacementType.native => const MockNativeAdWidget(),
      AdPlacementType.rewardedPrompt => const MockRewardedPromptWidget(),
    };
  }
}

class PremiumUpsellCard extends ConsumerStatefulWidget {
  const PremiumUpsellCard({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<PremiumUpsellCard> createState() => _PremiumUpsellCardState();
}

class _PremiumUpsellCardState extends ConsumerState<PremiumUpsellCard> {
  bool _tracked = false;

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(monetizationPolicyProvider);
    final isPremium = policy.subscription.isPremium;

    if (!_tracked && !isPremium) {
      _tracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(analyticsServiceProvider).logEvent(
              AppAnalyticsEvent.premiumUpsellViewed,
              parameters: {'compact': widget.compact},
            );
      });
    }

    if (isPremium) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.verified_outlined),
          title: const Text('PantryPilot Premium active'),
          subtitle: const Text('Ads removed and premium features are unlocked.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Ad-free experience and future advanced planning features.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(label: Text('Ad free')),
                Chip(label: Text('Dinner party planner')),
                Chip(label: Text('Expanded history')),
                Chip(label: Text('Household profiles')),
                Chip(label: Text('Premium AI chef mode')),
              ],
            ),
            if (!widget.compact) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => ref.read(subscriptionControllerProvider.notifier).upgradeToPremium(),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Preview Premium unlock'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LockedFeatureTile extends ConsumerWidget {
  const LockedFeatureTile({
    required this.feature,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final PremiumFeature feature;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(monetizationPolicyProvider);
    final unlocked = policy.hasFeature(feature);

    return Card(
      child: ListTile(
        leading: Icon(unlocked ? Icons.lock_open : Icons.lock_outline),
        title: Text(title),
        subtitle: Text(unlocked ? '$subtitle (Unlocked)' : '$subtitle (Premium)'),
        trailing: unlocked
            ? const Chip(label: Text('Enabled'))
            : TextButton(
                onPressed: () => ref.read(subscriptionControllerProvider.notifier).upgradeToPremium(),
                child: const Text('Upgrade'),
              ),
      ),
    );
  }
}
