import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/core/config/feature_flags.dart';
import 'package:pantry_pilot/src/features/monetization/domain/ad_placement.dart';
import 'package:pantry_pilot/src/features/monetization/domain/entitlements.dart';
import 'package:pantry_pilot/src/features/monetization/domain/subscription_state.dart';
import 'package:pantry_pilot/src/features/monetization/infrastructure/mock/mock_monetization_services.dart';
import 'package:pantry_pilot/src/features/monetization/services/monetization_remote_config_service.dart';

void main() {
  const featureFlags = FeatureFlags(
    useProductionAiServices: false,
    enableInstacartProvider: true,
    enableAmazonProvider: true,
    enableWebFallbackProvider: true,
    enableAds: true,
    enablePremiumFeatures: true,
  );

  test('known monthly premium product unlocks premium entitlements', () {
    final entitlements = const EntitlementPolicy().resolve(
      const SubscriptionState(
        plan: SubscriptionPlan.premium,
        billingState: BillingState.active,
        productId: EntitlementPolicy.monthlyProductId,
      ),
    );

    expect(entitlements.has(PremiumFeature.adFree), isTrue);
    expect(entitlements.has(PremiumFeature.premiumAiChefMode), isTrue);
  });

  test('unknown premium product does not unlock premium entitlements', () {
    final entitlements = const EntitlementPolicy().resolve(
      const SubscriptionState(
        plan: SubscriptionPlan.premium,
        billingState: BillingState.active,
        productId: 'legacy_plan',
      ),
    );

    expect(entitlements.all, isEmpty);
  });

  test('policy blocks ads when remote config disables ads', () {
    final policy = MonetizationPolicy(
      subscription: SubscriptionState.free(),
      entitlements: const EntitlementSet({}),
      adService: const MockAdService(),
      featureFlags: featureFlags,
      remoteFlags: MonetizationRemoteFlags.safeDefaults,
    );

    expect(policy.shouldShowAd(AdPlacement.homeBanner), isFalse);
  });
}
