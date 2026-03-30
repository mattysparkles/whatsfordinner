import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pantry_pilot/src/app/providers.dart';
import 'package:pantry_pilot/src/app/app_navigation.dart';
import 'package:pantry_pilot/src/features/cook_mode/presentation/cook_mode_screen.dart';
import 'package:pantry_pilot/src/core/models/app_models.dart';
import 'package:pantry_pilot/src/features/cook_mode/infrastructure/mock/mock_cook_mode_services.dart';

void main() {
  RecipeSuggestion testRecipe() {
    return const RecipeSuggestion(
      id: 'r1',
      title: 'Test Soup',
      shortDescription: 'Simple soup for testing.',
      matchType: RecipeMatchType.exact,
      prepMinutes: 5,
      cookMinutes: 10,
      difficulty: 1,
      familyFriendlyScore: 3,
      healthScore: 3,
      fancyScore: 1,
      servings: 2,
      dietaryTags: const [],
      requirements: [
        RecipeIngredientRequirement(ingredientName: 'Onion', requiredAmount: 1, unit: 'count', isAvailable: true),
        RecipeIngredientRequirement(ingredientName: 'Broth', requiredAmount: 2, unit: 'cups', isAvailable: false),
      ],
      availableIngredients: ['Onion'],
      missingIngredients: [],
      steps: [
        CookingStep(order: 1, instruction: 'Chop the onion.'),
        CookingStep(order: 2, instruction: 'Simmer with broth.'),
        CookingStep(order: 3, instruction: 'Serve warm.'),
      ],
      suggestedPairings: const [],
      explanation: RecipeExplanation(summary: 'Test reasons', pantryHighlights: []),
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
    router.go('/cook', extra: CookModeRouteExtra(recipe: testRecipe()));
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
    router.go('/cook', extra: CookModeRouteExtra(recipe: testRecipe()));
    await tester.pumpAndSettle();

    expect(find.text('Ingredient checklist (1/2)'), findsOneWidget);
  });

  testWidgets('cook mode voice pause control toggles state label', (tester) async {
    final router = buildRouter();

    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    router.go('/cook', extra: CookModeRouteExtra(recipe: testRecipe()));
    await tester.pumpAndSettle();

    expect(find.text('Pause voice'), findsOneWidget);
    await tester.tap(find.text('Pause voice'));
    await tester.pumpAndSettle();
    expect(find.text('Resume voice'), findsOneWidget);
  });

  testWidgets('voice chips trigger state transitions and auto narration on entry', (tester) async {
    final router = buildRouter();
    final tts = MockTextToSpeechService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [textToSpeechServiceProvider.overrideWithValue(tts)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/cook', extra: CookModeRouteExtra(recipe: testRecipe()));
    await tester.pumpAndSettle();

    expect(tts.lastSpoken, 'Chop the onion.');

    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(tts.lastSpoken, 'Simmer with broth.');

    await tester.tap(find.text('Repeat that'));
    await tester.pumpAndSettle();
    expect(tts.lastSpoken, 'Simmer with broth.');

    await tester.tap(find.text('Pause voice'));
    await tester.pumpAndSettle();
    expect(find.text('Resume voice'), findsOneWidget);

    await tester.tap(find.text('Resume voice').first);
    await tester.pumpAndSettle();
    expect(find.text('Pause voice'), findsWidgets);
  });
}
