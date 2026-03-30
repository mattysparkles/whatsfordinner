import '../domain/subscription_state.dart';
import '../domain/monetization_models.dart';

abstract class SubscriptionService {
  Stream<SubscriptionState> watchSubscription();
  Future<SubscriptionState> fetchCurrent();
  Future<List<PremiumProduct>> loadOfferings();
  Future<void> startPremiumCheckout(PremiumPlanProduct plan);
  Future<void> restorePurchases();
}
