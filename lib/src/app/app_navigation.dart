import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/models/app_models.dart';
import 'app_routes.dart';

class RecipeDetailRouteExtra {
  const RecipeDetailRouteExtra({required this.recipe});

  final RecipeSuggestion recipe;
}

class CookModeRouteExtra {
  const CookModeRouteExtra({required this.recipe});

  final RecipeSuggestion recipe;
}

extension AppNavigation on BuildContext {
  Future<T?> pushRecipeDetail<T>(RecipeSuggestion recipe) {
    return push<T>(AppRoutes.recipeDetail, extra: RecipeDetailRouteExtra(recipe: recipe));
  }

  Future<T?> pushCookMode<T>(RecipeSuggestion recipe) {
    return push<T>(AppRoutes.cookMode, extra: CookModeRouteExtra(recipe: recipe));
  }

  Future<T?> pushShoppingList<T>() {
    return push<T>(AppRoutes.shoppingList);
  }
}
