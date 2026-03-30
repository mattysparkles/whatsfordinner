enum AdPlacementType { banner, native, rewardedPrompt }

enum AppScreenContext {
  home,
  recipes,
  shoppingList,
  favoritesHistory,
  preferences,
  monetization,
  cookMode,
}

class AdPlacement {
  const AdPlacement({
    required this.id,
    required this.type,
    required this.screenContext,
    this.description,
  });

  final String id;
  final AdPlacementType type;
  final AppScreenContext screenContext;
  final String? description;

  bool get isCookModePlacement => screenContext == AppScreenContext.cookMode;

  static const homeBanner = AdPlacement(
    id: 'home.banner.bottom',
    type: AdPlacementType.banner,
    screenContext: AppScreenContext.home,
    description: 'Tasteful bottom banner on home screen for free tier only.',
  );

  static const recipesNative = AdPlacement(
    id: 'recipes.native.inline',
    type: AdPlacementType.native,
    screenContext: AppScreenContext.recipes,
    description: 'Native recipe companion card in discovery list.',
  );

  static const shoppingBanner = AdPlacement(
    id: 'shopping.banner.bottom',
    type: AdPlacementType.banner,
    screenContext: AppScreenContext.shoppingList,
    description: 'Bottom banner in shopping workflow only for free tier.',
  );

  static const rewardsPrompt = AdPlacement(
    id: 'preferences.rewarded.prompt',
    type: AdPlacementType.rewardedPrompt,
    screenContext: AppScreenContext.preferences,
    description: 'Optional rewarded prompt placeholder for future perks.',
  );
}
