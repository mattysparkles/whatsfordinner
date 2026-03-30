import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class MealPlanningScreen extends ConsumerStatefulWidget {
  const MealPlanningScreen({super.key});

  @override
  ConsumerState<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends ConsumerState<MealPlanningScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(recipeSuggestionsProvider).valueOrNull ?? const <RecipeSuggestion>[];
    final favorites = ref.watch(favoritesHistoryControllerProvider).savedRecipes;
    final planning = ref.watch(mealPlanningControllerProvider);
    final monetization = ref.watch(monetizationPolicyProvider);
    final canUseAdvancedDinnerParty = monetization.hasFeature(PremiumFeature.advancedDinnerPartyPlanner);

    return AppScaffold(
      title: 'Meal planning',
      body: ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Selected day: ${DateFormat.yMMMMd().format(_selectedDate)}'),
              subtitle: const Text('Pick a date, then assign a saved recipe or suggestion.'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: _selectedDate,
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: const Text('Pick date'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Assign recipe', style: TextStyle(fontWeight: FontWeight.bold)),
          if (favorites.isEmpty && suggestions.isEmpty)
            const Card(child: ListTile(title: Text('Generate recipe suggestions first to start planning.'))),
          ...favorites.take(6).map(
                (saved) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.redAccent),
                    title: Text(saved.recipeTitle),
                    subtitle: const Text('Saved recipe'),
                    trailing: FilledButton(
                      onPressed: () {
                        final recipe = suggestions.firstWhere(
                          (item) => item.id == saved.recipeId,
                          orElse: () => RecipeSuggestion(
                            id: saved.recipeId,
                            title: saved.recipeTitle,
                            shortDescription: 'Saved recipe for planning.',
                            matchType: RecipeMatchType.nearMatch,
                            prepMinutes: 10,
                            cookMinutes: 20,
                            difficulty: 2,
                            familyFriendlyScore: 4,
                            healthScore: 3,
                            fancyScore: 2,
                            servings: 2,
                            dietaryTags: const [],
                            requirements: const [],
                            missingIngredients: const [],
                            availableIngredients: const [],
                            steps: const [],
                            suggestedPairings: const [],
                            explanation: const RecipeExplanation(summary: 'Saved favorite.', pantryHighlights: []),
                          ),
                        );
                        ref.read(mealPlanningControllerProvider.notifier).assignRecipe(
                              date: _selectedDate,
                              recipe: recipe,
                              sourceLabel: 'saved',
                            );
                      },
                      child: const Text('Assign'),
                    ),
                  ),
                ),
              ),
          ...suggestions.take(6).map(
                (recipe) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text(recipe.title),
                    subtitle: Text(recipe.matchType == RecipeMatchType.pantryFreestyle
                        ? 'Pantry Freestyle (creative AI output)'
                        : recipe.matchType.label),
                    trailing: FilledButton(
                      onPressed: () => ref.read(mealPlanningControllerProvider.notifier).assignRecipe(
                            date: _selectedDate,
                            recipe: recipe,
                            sourceLabel: 'suggestion',
                          ),
                      child: const Text('Assign'),
                    ),
                  ),
                ),
              ),
          const Divider(),
          const Text('Current plan', style: TextStyle(fontWeight: FontWeight.bold)),
          ...planning.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(entry.recipeTitle),
              subtitle: Text('${DateFormat.EEE().add_MMMd().format(entry.date)} • ${entry.sourceLabel}'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => ref.read(mealPlanningControllerProvider.notifier).commitCurrentPlan(),
                icon: const Icon(Icons.save),
                label: const Text('Save plan snapshot'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final list = ref.read(mealPlanningControllerProvider.notifier).generateShoppingListFromPlan(recipes: suggestions);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Generated shopping list with ${list.items.length} items.')),
                  );
                },
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Generate shopping list'),
              ),
            ],
          ),
          const Divider(),
          const Text('Dinner party mode', style: TextStyle(fontWeight: FontWeight.bold)),
          if (!canUseAdvancedDinnerParty)
            const LockedFeatureTile(
              feature: PremiumFeature.advancedDinnerPartyPlanner,
              title: 'Advanced dinner party bundles',
              subtitle: 'Upgrade for premium-ready course pacing and custom drink flights.',
            ),
          if (suggestions.isNotEmpty)
            Builder(
              builder: (_) {
                final bundle = ref.read(mealPlanningControllerProvider.notifier).suggestDinnerPartyBundle(
                      suggestions: suggestions,
                      hasPremium: canUseAdvancedDinnerParty,
                    );
                return Card(
                  child: ListTile(
                    title: Text(bundle.isPremiumSuggestion
                        ? 'Starter dinner party bundle (basic)'
                        : 'Dinner party bundle'),
                    subtitle: Text(
                      'Appetizer: ${bundle.appetizer.title}\nMain: ${bundle.main.title}\nDessert: ${bundle.dessert.title}\nDrink: ${bundle.drink.title}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          const Divider(),
          const Text('Planning history', style: TextStyle(fontWeight: FontWeight.bold)),
          ...planning.planHistory.take(5).map(
                (plan) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(plan.label),
                  subtitle: Text('${DateFormat.yMMMd().format(plan.createdAt)} • ${plan.items.length} meals'),
                  trailing: TextButton(
                    onPressed: () => ref.read(mealPlanningControllerProvider.notifier).markPlanReused(plan),
                    child: const Text('Reuse'),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          const Text('Recently reused', style: TextStyle(fontWeight: FontWeight.bold)),
          ...planning.recentlyReused.map(
            (plan) => ListTile(
              leading: const Icon(Icons.replay),
              title: Text(plan.label),
              subtitle: Text('${plan.items.length} meals'),
            ),
          ),
        ],
      ),
    );
  }
}
