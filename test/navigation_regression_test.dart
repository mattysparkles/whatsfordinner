import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pantry_pilot/src/app/app_navigation.dart';
import 'package:pantry_pilot/src/app/app_routes.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/features/capture/presentation/capture_screen.dart';
import 'package:pantry_pilot/src/features/pantry/presentation/pantry_screen.dart';
import 'package:pantry_pilot/src/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:pantry_pilot/src/features/shopping_list/presentation/shopping_list_screen.dart';
import 'package:pantry_pilot/src/features/cook_mode/presentation/cook_mode_screen.dart';

void main() {
  const recipe = RecipeSuggestion(
    id: 'recipe-1',
    title: 'Weeknight Pasta',
    shortDescription: 'Simple dinner',
    matchType: RecipeMatchType.nearMatch,
    prepMinutes: 10,
    cookMinutes: 15,
    difficulty: 1,
    familyFriendlyScore: 4,
    healthScore: 3,
    fancyScore: 1,
    servings: 2,
    dietaryTags: [],
    requirements: [
      RecipeIngredientRequirement(
        ingredientName: 'Onion',
        requiredAmount: 1,
        unit: 'count',
        isAvailable: true,
      ),
      RecipeIngredientRequirement(
        ingredientName: 'Milk',
        requiredAmount: 1,
        unit: 'cup',
        isAvailable: false,
      ),
    ],
    missingIngredients: [
      MissingIngredient(ingredientName: 'Milk', shortageAmount: 1, unit: 'cup'),
    ],
    availableIngredients: ['Onion'],
    steps: [CookingStep(order: 1, instruction: 'Boil water.')],
    suggestedPairings: [],
    explanation: RecipeExplanation(summary: 'mock', pantryHighlights: []),
  );

  testWidgets('recipe detail to cook mode keeps selected recipe', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.recipeDetail,
      routes: [
        GoRoute(
          path: AppRoutes.recipeDetail,
          builder: (_, state) => RecipeDetailScreen(
            seedRecipe: (state.extra as RecipeDetailRouteExtra?)?.recipe ?? recipe,
          ),
        ),
        GoRoute(
          path: AppRoutes.cookMode,
          builder: (_, state) => CookModeScreen(seedRecipe: (state.extra as CookModeRouteExtra).recipe),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start cook mode'));
    await tester.pumpAndSettle();

    expect(find.text('Weeknight Pasta'), findsOneWidget);
    expect(find.text('Boil water.'), findsOneWidget);
  });

  testWidgets('capture review approval returns to pantry route', (tester) async {
    final router = GoRouter(
      initialLocation: '/review',
      routes: [
        GoRoute(
          path: '/review',
          builder: (_, __) => ParseReviewScreen(
            session: ParseSession(
              id: 'session-1',
              images: const [],
              imageErrors: const [],
              parsedIngredients: const [
                ParsedIngredient(
                  id: '1',
                  rawText: 'milk',
                  suggestedName: 'Milk',
                  confidenceScore: 0.95,
                  parseConfidence: ParseConfidence.likely,
                  sourceImageId: 'img-1',
                  category: IngredientCategory.dairy,
                ),
              ],
            ),
            onApprove: (_) async {},
          ),
        ),
        GoRoute(path: AppRoutes.pantry, builder: (_, __) => const PantryScreen()),
      ],
    );

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send approved items to inventory'));
    await tester.pumpAndSettle();

    expect(find.text('Pantry Inventory'), findsOneWidget);
  });

  testWidgets('recipe detail can create shopping list and navigate', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.recipeDetail,
      routes: [
        GoRoute(path: AppRoutes.recipeDetail, builder: (_, __) => const RecipeDetailScreen(seedRecipe: recipe)),
        GoRoute(path: AppRoutes.shoppingList, builder: (_, __) => const ShoppingListScreen()),
      ],
    );

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add missing to shopping list'));
    await tester.pumpAndSettle();

    expect(find.text('Shopping List'), findsOneWidget);
    expect(find.text('From recipe: Weeknight Pasta'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
  });
}
