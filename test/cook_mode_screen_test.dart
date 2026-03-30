import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pantry_pilot/src/features/cook_mode/presentation/cook_mode_screen.dart';

import 'package:pantry_pilot/src/domain/models/models.dart';

void main() {
  RecipeSuggestion testRecipe() {
    return const RecipeSuggestion(
      id: 'r1',
      title: 'Test Soup',
      description: 'Simple soup for testing.',
      matchType: RecipeMatchType.exact,
      confidence: 0.9,
      whySuggested: 'Test reasons',
      mealType: MealType.dinner,
      prepMinutes: 5,
      cookMinutes: 10,
      servings: 2,
      requirements: [
        RecipeIngredientRequirement(name: 'Onion', quantity: 1, unit: 'count'),
        RecipeIngredientRequirement(name: 'Broth', quantity: 2, unit: 'cups'),
      ],
      availableIngredients: ['Onion'],
      missingIngredients: [],
      substitutions: {},
      steps: [
        CookingStep(order: 1, instruction: 'Chop the onion.'),
        CookingStep(order: 2, instruction: 'Simmer with broth.'),
        CookingStep(order: 3, instruction: 'Serve warm.'),
      ],
    );
  }

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(path: '/cook', builder: (_, _) => const CookModeScreen()),
      ],
    );
  }

  testWidgets('cook mode next and previous controls navigate between steps', (tester) async {
    final router = buildRouter();

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    router.go('/cook', extra: testRecipe());
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Chop the onion.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Simmer with broth.'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('cook mode renders ingredient checklist summary counts', (tester) async {
    final router = buildRouter();

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    router.go('/cook', extra: testRecipe());
    await tester.pumpAndSettle();

    expect(find.text('Ingredient checklist (1/2)'), findsOneWidget);
  });

  testWidgets('cook mode voice pause control toggles state label', (tester) async {
    final router = buildRouter();

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    router.go('/cook', extra: testRecipe());
    await tester.pumpAndSettle();

    expect(find.text('Pause voice'), findsOneWidget);
    await tester.tap(find.text('Pause voice'));
    await tester.pumpAndSettle();
    expect(find.text('Resume voice'), findsOneWidget);
  });
}
