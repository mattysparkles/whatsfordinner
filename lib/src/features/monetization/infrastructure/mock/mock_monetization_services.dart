import 'dart:async';

import '../../domain/ad_placement.dart';
import '../../domain/monetization_models.dart';
import '../../domain/subscription_state.dart';
import '../../services/ad_service.dart';
import '../../services/subscription_service.dart';

class MockSubscriptionService implements SubscriptionService {
  MockSubscriptionService({SubscriptionState? initial}) : _state = initial ?? SubscriptionState.free();

  final _controller = StreamController<SubscriptionState>.broadcast();
  SubscriptionState _state;

  @override
  Future<SubscriptionState> fetchCurrent() async => _state;

  @override
  Future<void> restorePurchases() async {
    _emit(_state);
  }

  @override
  Future<List<PremiumProduct>> loadOfferings() async {
    return const [
      PremiumProduct(
        plan: PremiumPlanProduct.monthly,
        productId: 'pantrypilot_premium_monthly',
        displayName: 'PantryPilot Premium Monthly',
        priceLabel: '\$4.99',
        description: 'Ad-free PantryPilot billed monthly.',
      ),
      PremiumProduct(
        plan: PremiumPlanProduct.yearly,
        productId: 'pantrypilot_premium_yearly',
        displayName: 'PantryPilot Premium Yearly',
        priceLabel: '\$39.99',
        description: 'Ad-free PantryPilot billed yearly.',
      ),
    ];
  }

  @override
  Future<void> startPremiumCheckout(PremiumPlanProduct plan) async {
    _emit(
      SubscriptionState(
        plan: SubscriptionPlan.premium,
        billingState: BillingState.active,
        productId: plan == PremiumPlanProduct.monthly ? 'pantrypilot_premium_monthly' : 'pantrypilot_premium_yearly',
        renewalDate: DateTime.now().add(const Duration(days: 30)),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  @override
  Stream<SubscriptionState> watchSubscription() async* {
    yield _state;
    yield* _controller.stream;
  }

  Future<void> debugDowngradeToFree() async {
    _emit(SubscriptionState.free().copyWith(lastUpdated: DateTime.now()));
  }

  void dispose() {
    _controller.close();
  }

  void _emit(SubscriptionState next) {
    _state = next;
    _controller.add(next);
  }
}

class MockAdService implements AdService {
  const MockAdService();

  @override
  bool canRenderPlacement({required AdPlacement placement, required SubscriptionState subscription}) {
    if (placement.isCookModePlacement) {
      return false;
    }
    if (subscription.isPremium) {
      return false;
    }
    return true;
  }

  @override
  Future<void> preload(AdPlacement placement) async {
    if (placement.isCookModePlacement) {
      throw StateError('Cook Mode is ad-free by policy.');
    }
  }
}
