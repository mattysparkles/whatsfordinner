import '../domain/ad_placement.dart';
import '../domain/subscription_state.dart';

abstract class AdService {
  bool canRenderPlacement({required AdPlacement placement, required SubscriptionState subscription});

  Future<void> preload(AdPlacement placement);
}
