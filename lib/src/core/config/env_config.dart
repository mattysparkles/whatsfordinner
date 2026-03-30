enum AppEnvironment { dev, staging, prod }

class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.useMocks,
    required this.gatewayApiBaseUrl,
    required this.recipeApiBaseUrl,
    required this.visionApiBaseUrl,
    required this.featureUseProductionAiServices,
    required this.featureEnableInstacartProvider,
    required this.featureEnableAmazonProvider,
    required this.featureEnableWebFallbackProvider,
    required this.featureEnableAds,
    required this.featureEnablePremiumFeatures,
    required this.useFirebaseEmulators,
    required this.revenueCatApiKey,
    required this.googleAdsBannerUnitId,
    required this.googleAdsNativeUnitId,
    required this.googleAdsNativeFactoryId,
    this.recipeApiKey = '',
    this.visionApiKey = '',
    this.visionModel = 'gpt-4.1-mini',
    this.visionRequestTimeoutMs = 30000,
    this.visionMaxRetries = 2,
    this.visionLogEnabled = false,
    this.recipeModel = 'gpt-4.1-mini',
    this.recipeRequestTimeoutMs = 25000,
    this.recipeMaxRetries = 2,
    this.recipeCacheTtl = const Duration(minutes: 10),
  });

  final AppEnvironment environment;
  final bool useMocks;
  final String gatewayApiBaseUrl;
  final String recipeApiBaseUrl;
  final String visionApiBaseUrl;
  final String recipeApiKey;
  final String visionApiKey;
  final String visionModel;
  final int visionRequestTimeoutMs;
  final int visionMaxRetries;
  final bool visionLogEnabled;
  final String recipeModel;
  final int recipeRequestTimeoutMs;
  final int recipeMaxRetries;
  final Duration recipeCacheTtl;
  final bool featureUseProductionAiServices;
  final bool featureEnableInstacartProvider;
  final bool featureEnableAmazonProvider;
  final bool featureEnableWebFallbackProvider;
  final bool featureEnableAds;
  final bool featureEnablePremiumFeatures;
  final bool useFirebaseEmulators;
  final String revenueCatApiKey;
  final String googleAdsBannerUnitId;
  final String googleAdsNativeUnitId;
  final String googleAdsNativeFactoryId;

  static EnvConfig fromDartDefines() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

    return EnvConfig(
      environment: AppEnvironment.values.firstWhere(
        (value) => value.name == env,
        orElse: () => AppEnvironment.dev,
      ),
      useMocks: useMocks,
      gatewayApiBaseUrl: const String.fromEnvironment(
        'GATEWAY_API_BASE_URL',
        defaultValue: 'http://localhost:8000',
      ),
      recipeApiBaseUrl: const String.fromEnvironment(
        'RECIPE_API_BASE_URL',
        defaultValue: 'https://example.com/recipes',
      ),
      visionApiBaseUrl: const String.fromEnvironment(
        'VISION_API_BASE_URL',
        defaultValue: 'https://api.openai.com/v1',
      ),
      recipeApiKey: const String.fromEnvironment('RECIPE_API_KEY'),
      visionApiKey: const String.fromEnvironment('VISION_API_KEY'),
      visionModel: const String.fromEnvironment('VISION_MODEL', defaultValue: 'gpt-4.1-mini'),
      visionRequestTimeoutMs: int.fromEnvironment('VISION_TIMEOUT_MS', defaultValue: 30000),
      visionMaxRetries: int.fromEnvironment('VISION_MAX_RETRIES', defaultValue: 2),
      visionLogEnabled: bool.fromEnvironment('VISION_LOGGING_ENABLED', defaultValue: false),
      recipeModel: const String.fromEnvironment('RECIPE_MODEL', defaultValue: 'gpt-4.1-mini'),
      recipeRequestTimeoutMs: int.fromEnvironment('RECIPE_TIMEOUT_MS', defaultValue: 25000),
      recipeMaxRetries: int.fromEnvironment('RECIPE_MAX_RETRIES', defaultValue: 2),
      recipeCacheTtl: Duration(seconds: int.fromEnvironment('RECIPE_CACHE_TTL_SECONDS', defaultValue: 600)),
      featureUseProductionAiServices: bool.fromEnvironment('FEATURE_USE_PRODUCTION_AI_SERVICES', defaultValue: false),
      featureEnableInstacartProvider: bool.fromEnvironment('FEATURE_SHOPPING_INSTACART', defaultValue: true),
      featureEnableAmazonProvider: bool.fromEnvironment('FEATURE_SHOPPING_AMAZON', defaultValue: true),
      featureEnableWebFallbackProvider: bool.fromEnvironment('FEATURE_SHOPPING_WEB_FALLBACK', defaultValue: true),
      featureEnableAds: bool.fromEnvironment('FEATURE_ADS_ENABLED', defaultValue: true),
      featureEnablePremiumFeatures: bool.fromEnvironment('FEATURE_PREMIUM_ENABLED', defaultValue: true),
      useFirebaseEmulators: bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false),
      revenueCatApiKey: const String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: ''),
      googleAdsBannerUnitId: const String.fromEnvironment(
        'ADS_BANNER_UNIT_ID',
        defaultValue: 'ca-app-pub-3940256099942544/6300978111',
      ),
      googleAdsNativeUnitId: const String.fromEnvironment(
        'ADS_NATIVE_UNIT_ID',
        defaultValue: 'ca-app-pub-3940256099942544/2247696110',
      ),
      googleAdsNativeFactoryId: const String.fromEnvironment('ADS_NATIVE_FACTORY_ID', defaultValue: ''),
    );
  }
}
