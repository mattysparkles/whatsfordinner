import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/presentation/capture_screen.dart';
import '../features/cook_mode/presentation/cook_mode_screen.dart';
import '../features/favorites_history/presentation/favorites_history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/monetization/presentation/monetization_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/pantry/presentation/pantry_screen.dart';
import '../features/preferences/presentation/about_screen.dart';
import '../features/preferences/presentation/preferences_screen.dart';
import '../features/preferences/presentation/privacy_screen.dart';
import '../features/preferences/presentation/terms_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../features/shopping_list/presentation/shopping_list_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: AppRoutes.capture, builder: (_, _) => const CaptureScreen()),
      GoRoute(path: AppRoutes.pantry, builder: (_, _) => const PantryScreen()),
      GoRoute(path: AppRoutes.recipes, builder: (_, _) => const RecipesScreen()),
      GoRoute(path: AppRoutes.recipeDetail, builder: (_, _) => const RecipeDetailScreen()),
      GoRoute(path: AppRoutes.cookMode, builder: (_, _) => const CookModeScreen()),
      GoRoute(path: AppRoutes.shoppingList, builder: (_, _) => const ShoppingListScreen()),
      GoRoute(path: AppRoutes.preferences, builder: (_, _) => const PreferencesScreen()),
      GoRoute(path: AppRoutes.about, builder: (_, _) => const AboutScreen()),
      GoRoute(path: AppRoutes.privacy, builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: AppRoutes.terms, builder: (_, _) => const TermsScreen()),
      GoRoute(path: AppRoutes.favoritesHistory, builder: (_, _) => const FavoritesHistoryScreen()),
      GoRoute(path: AppRoutes.monetization, builder: (_, _) => const MonetizationScreen()),
    ],
  ),
);
