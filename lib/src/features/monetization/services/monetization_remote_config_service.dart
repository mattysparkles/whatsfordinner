import 'package:firebase_remote_config/firebase_remote_config.dart';

class MonetizationRemoteFlags {
  const MonetizationRemoteFlags({
    required this.enableAds,
    required this.enablePremium,
    required this.enablePurchases,
  });

  final bool enableAds;
  final bool enablePremium;
  final bool enablePurchases;

  static const safeDefaults = MonetizationRemoteFlags(
    enableAds: false,
    enablePremium: true,
    enablePurchases: false,
  );
}

abstract class MonetizationRemoteConfigService {
  Future<MonetizationRemoteFlags> fetchFlags();
}

class FirebaseMonetizationRemoteConfigService implements MonetizationRemoteConfigService {
  FirebaseMonetizationRemoteConfigService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<MonetizationRemoteFlags> fetchFlags() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 4),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _remoteConfig.setDefaults(const {
        'monetization_ads_enabled': false,
        'monetization_premium_enabled': true,
        'monetization_purchases_enabled': false,
      });
      await _remoteConfig.fetchAndActivate();
      return MonetizationRemoteFlags(
        enableAds: _remoteConfig.getBool('monetization_ads_enabled'),
        enablePremium: _remoteConfig.getBool('monetization_premium_enabled'),
        enablePurchases: _remoteConfig.getBool('monetization_purchases_enabled'),
      );
    } catch (_) {
      return MonetizationRemoteFlags.safeDefaults;
    }
  }
}

class LocalMonetizationRemoteConfigService implements MonetizationRemoteConfigService {
  const LocalMonetizationRemoteConfigService(this.flags);

  final MonetizationRemoteFlags flags;

  @override
  Future<MonetizationRemoteFlags> fetchFlags() async => flags;
}
