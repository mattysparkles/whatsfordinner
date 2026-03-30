enum SubscriptionPlan { free, premium }

enum BillingState { inactive, trialing, active, gracePeriod, canceled, expired }

class SubscriptionState {
  const SubscriptionState({
    required this.plan,
    required this.billingState,
    this.productId,
    this.renewalDate,
    this.lastUpdated,
  });

  final SubscriptionPlan plan;
  final BillingState billingState;
  final String? productId;
  final DateTime? renewalDate;
  final DateTime? lastUpdated;

  bool get isPremium => plan == SubscriptionPlan.premium &&
      billingState != BillingState.expired &&
      billingState != BillingState.inactive;

  bool get isFreeTier => !isPremium;

  SubscriptionState copyWith({
    SubscriptionPlan? plan,
    BillingState? billingState,
    String? productId,
    DateTime? renewalDate,
    DateTime? lastUpdated,
  }) {
    return SubscriptionState(
      plan: plan ?? this.plan,
      billingState: billingState ?? this.billingState,
      productId: productId ?? this.productId,
      renewalDate: renewalDate ?? this.renewalDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static SubscriptionState free() => const SubscriptionState(
        plan: SubscriptionPlan.free,
        billingState: BillingState.inactive,
      );
}
