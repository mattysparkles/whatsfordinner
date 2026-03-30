import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../domain/ad_placement.dart';
import '../../domain/subscription_state.dart';
import '../../services/ad_service.dart';

class GoogleMobileAdsService implements AdService {
  GoogleMobileAdsService() {
    MobileAds.instance.initialize();
  }

  @override
  bool canRenderPlacement({required AdPlacement placement, required SubscriptionState subscription}) {
    if (placement.isCookModePlacement) return false;
    if (placement.type == AdPlacementType.rewardedPrompt) return false;
    return !subscription.isPremium;
  }

  @override
  Future<void> preload(AdPlacement placement) async {
    if (placement.isCookModePlacement) {
      throw StateError('Cook Mode is ad-free by policy.');
    }
  }
}
