import 'package:go_router/go_router.dart';

import '../features/capture/capture_screen.dart';
import '../features/cook_mode/cook_mode_screen.dart';
import '../features/favorites/favorites_history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/pantry/pantry_inventory_screen.dart';
import '../features/preferences/preferences_screen.dart';
import '../features/recipes/recipe_detail_screen.dart';
import '../features/recipes/recipe_results_screen.dart';
import '../features/shopping/shopping_list_screen.dart';

final router = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/capture', builder: (_, __) => const CaptureScreen()),
    GoRoute(path: '/pantry', builder: (_, __) => const PantryInventoryScreen()),
    GoRoute(path: '/results', builder: (_, __) => const RecipeResultsScreen()),
    GoRoute(path: '/recipe', builder: (_, __) => const RecipeDetailScreen()),
    GoRoute(path: '/cook', builder: (_, __) => const CookModeScreen()),
    GoRoute(path: '/shopping', builder: (_, __) => const ShoppingListScreen()),
    GoRoute(path: '/preferences', builder: (_, __) => const PreferencesScreen()),
    GoRoute(path: '/favorites', builder: (_, __) => const FavoritesAndHistoryScreen()),
  ],
);
