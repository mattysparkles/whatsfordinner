import '../domain/subscription_state.dart';

abstract class SubscriptionService {
  Stream<SubscriptionState> watchSubscription();
  Future<SubscriptionState> fetchCurrent();
  Future<void> startPremiumCheckout();
  Future<void> restorePurchases();
}
