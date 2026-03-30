import 'subscription_state.dart';

enum PremiumFeature {
  adFree,
  advancedDinnerPartyPlanner,
  expandedSavedHistory,
  advancedHouseholdProfiles,
  premiumAiChefMode,
}

class EntitlementSet {
  const EntitlementSet(this._features);

  final Set<PremiumFeature> _features;

  bool has(PremiumFeature feature) => _features.contains(feature);

  Set<PremiumFeature> get all => _features;
}

class EntitlementPolicy {
  const EntitlementPolicy();

  static const premiumEntitlementId = 'pantrypilot_premium';
  static const monthlyProductId = 'pantrypilot_premium_monthly';
  static const yearlyProductId = 'pantrypilot_premium_yearly';

  EntitlementSet resolve(SubscriptionState state) {
    if (!state.isPremium || !_isKnownPremiumProduct(state.productId)) {
      return const EntitlementSet({});
    }

    return const EntitlementSet({
      PremiumFeature.adFree,
      PremiumFeature.advancedDinnerPartyPlanner,
      PremiumFeature.expandedSavedHistory,
      PremiumFeature.advancedHouseholdProfiles,
      PremiumFeature.premiumAiChefMode,
    });
  }

  bool _isKnownPremiumProduct(String? productId) {
    if (productId == null) return true;
    return productId == monthlyProductId || productId == yearlyProductId;
  }
}
