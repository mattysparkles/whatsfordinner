import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../app/providers.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/analytics_service.dart';
import '../../domain/ad_placement.dart';
import '../../domain/entitlements.dart';
import '../../domain/monetization_models.dart';
import 'mock_ad_widgets.dart';

class AdPlacementSlot extends ConsumerWidget {
  const AdPlacementSlot({required this.placement, super.key});

  final AdPlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(monetizationPolicyProvider);
    if (!policy.shouldShowAd(placement)) return const SizedBox.shrink();

    final config = ref.watch(appConfigProvider);
    if (config.useMocks || placement.type == AdPlacementType.rewardedPrompt) {
      return switch (placement.type) {
        AdPlacementType.banner => const MockBannerAdWidget(),
        AdPlacementType.native => const MockNativeAdWidget(),
        AdPlacementType.rewardedPrompt => const MockRewardedPromptWidget(),
      };
    }

    return switch (placement.type) {
      AdPlacementType.banner => _LiveBannerAd(unitId: config.googleAdsBannerUnitId, placement: placement),
      AdPlacementType.native => _LiveNativeAd(
          unitId: config.googleAdsNativeUnitId,
          factoryId: config.googleAdsNativeFactoryId,
          placement: placement,
        ),
      AdPlacementType.rewardedPrompt => const SizedBox.shrink(),
    };
  }
}

class _LiveBannerAd extends StatefulWidget {
  const _LiveBannerAd({required this.unitId, required this.placement});

  final String unitId;
  final AdPlacement placement;

  @override
  State<_LiveBannerAd> createState() => _LiveBannerAdState();
}

class _LiveBannerAdState extends State<_LiveBannerAd> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: widget.unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdImpression: (ad) {
          if (!mounted) return;
          final container = ProviderScope.containerOf(context, listen: false);
          container.read(analyticsServiceProvider).logEvent(
                AppAnalyticsEvent.adImpression,
                parameters: {'placement': widget.placement.id, 'type': 'banner'},
              );
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(height: ad.size.height.toDouble(), width: ad.size.width.toDouble(), child: AdWidget(ad: ad));
  }
}

class _LiveNativeAd extends StatefulWidget {
  const _LiveNativeAd({required this.unitId, required this.factoryId, required this.placement});

  final String unitId;
  final String factoryId;
  final AdPlacement placement;

  @override
  State<_LiveNativeAd> createState() => _LiveNativeAdState();
}

class _LiveNativeAdState extends State<_LiveNativeAd> {
  NativeAd? _ad;

  @override
  void initState() {
    super.initState();
    if (widget.factoryId.isEmpty) return;
    _ad = NativeAd(
      adUnitId: widget.unitId,
      factoryId: widget.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdImpression: (ad) {
          if (!mounted) return;
          final container = ProviderScope.containerOf(context, listen: false);
          container.read(analyticsServiceProvider).logEvent(
                AppAnalyticsEvent.adImpression,
                parameters: {'placement': widget.placement.id, 'type': 'native'},
              );
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const MockNativeAdWidget();
    return SizedBox(height: 100, child: AdWidget(ad: ad));
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
  bool _loading = false;
  String? _error;
  List<PremiumProduct> _products = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_products.isEmpty) {
      ref.read(subscriptionControllerProvider.notifier).loadOfferings().then((value) {
        if (mounted) setState(() => _products = value);
      }).catchError((_) {
        if (mounted) setState(() => _error = 'Could not load plans right now.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(monetizationPolicyProvider);
    final isPremium = policy.subscription.isPremium;
    final purchasesEnabled = policy.remoteFlags.enablePurchases;

    if (!_tracked && !isPremium) {
      _tracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(analyticsServiceProvider).logEvent(AppAnalyticsEvent.paywallViewed, parameters: {'compact': widget.compact});
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
            const Text('Ad-free experience and advanced planning features.'),
            const SizedBox(height: 8),
            for (final product in _products)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${product.displayName} • ${product.priceLabel}'),
                subtitle: Text(product.description),
                trailing: FilledButton(
                  onPressed: _loading || !purchasesEnabled
                      ? null
                      : () async {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          try {
                            await ref.read(analyticsServiceProvider).logEvent(
                                  AppAnalyticsEvent.purchaseStarted,
                                  parameters: {'product_id': product.productId},
                                );
                            await ref.read(subscriptionControllerProvider.notifier).upgradeToPremium(product.plan);
                            await ref.read(analyticsServiceProvider).logEvent(
                                  AppAnalyticsEvent.purchaseSucceeded,
                                  parameters: {'product_id': product.productId},
                                );
                          } catch (e) {
                            setState(() => _error = 'Purchase failed. Please try again.');
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  child: const Text('Choose'),
                ),
              ),
            TextButton.icon(
              onPressed: _loading || !purchasesEnabled
                  ? null
                  : () async {
                      await ref.read(subscriptionControllerProvider.notifier).restorePurchases();
                      await ref.read(analyticsServiceProvider).logEvent(AppAnalyticsEvent.purchaseRestore);
                    },
              icon: const Icon(Icons.restore),
              label: const Text('Restore purchases'),
            ),
            if (!purchasesEnabled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Purchases are temporarily unavailable. Please try again later.'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
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
      ),
    );
  }
}
