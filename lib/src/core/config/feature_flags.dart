class FeatureFlags {
  const FeatureFlags({
    required this.useProductionAiServices,
    required this.enableInstacartProvider,
    required this.enableAmazonProvider,
    required this.enableWebFallbackProvider,
    required this.enableAds,
    required this.enablePremiumFeatures,
  });

  final bool useProductionAiServices;
  final bool enableInstacartProvider;
  final bool enableAmazonProvider;
  final bool enableWebFallbackProvider;
  final bool enableAds;
  final bool enablePremiumFeatures;
}
