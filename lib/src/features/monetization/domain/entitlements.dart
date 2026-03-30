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

  EntitlementSet resolve(SubscriptionState state) {
    if (!state.isPremium) {
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
}
