import '../domain/ad_placement.dart';
import '../domain/subscription_state.dart';

abstract class AdService {
  bool canRenderPlacement({required AdPlacement placement, required SubscriptionState subscription});

  Future<void> preload(AdPlacement placement);
}

class NoOpAdService implements AdService {
  const NoOpAdService();

  @override
  bool canRenderPlacement({required AdPlacement placement, required SubscriptionState subscription}) => false;

  @override
  Future<void> preload(AdPlacement placement) async {}
}
