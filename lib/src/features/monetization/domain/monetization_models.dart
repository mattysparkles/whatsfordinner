enum PremiumPlanProduct { monthly, yearly }

enum PurchaseFailureReason { serviceUnavailable, cancelled, pending, unknown }

class PurchaseFailure implements Exception {
  const PurchaseFailure(this.reason, {this.message});

  final PurchaseFailureReason reason;
  final String? message;
}

class PremiumProduct {
  const PremiumProduct({
    required this.plan,
    required this.productId,
    required this.displayName,
    required this.priceLabel,
    required this.description,
  });

  final PremiumPlanProduct plan;
  final String productId;
  final String displayName;
  final String priceLabel;
  final String description;
}
