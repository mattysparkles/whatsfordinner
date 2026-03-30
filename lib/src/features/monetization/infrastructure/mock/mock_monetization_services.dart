import 'dart:async';

import '../../domain/ad_placement.dart';
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
  Future<void> startPremiumCheckout() async {
    _emit(
      SubscriptionState(
        plan: SubscriptionPlan.premium,
        billingState: BillingState.active,
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
