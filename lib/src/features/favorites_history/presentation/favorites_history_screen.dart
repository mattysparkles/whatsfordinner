import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class FavoritesHistoryScreen extends ConsumerWidget {
  const FavoritesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesHistoryControllerProvider);
    final controller = ref.read(favoritesHistoryControllerProvider.notifier);
    final policy = ref.watch(monetizationPolicyProvider);
    final expandedHistory = policy.hasFeature(PremiumFeature.expandedSavedHistory);

    final visibleSaved = expandedHistory ? state.filteredSaved : state.filteredSaved.take(10).toList(growable: false);
    final visibleHistory = expandedHistory ? state.filteredHistory : state.filteredHistory.take(15).toList(growable: false);

    return AppScaffold(
      title: 'Favorites & History',
      adPlacement: AdPlacement.homeBanner,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search recipes',
                          ),
                          onChanged: controller.setSearch,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<RecipeHistorySort>(
                                initialValue: state.filters.historySort,
                                decoration: const InputDecoration(labelText: 'Sort'),
                                items: RecipeHistorySort.values
                                    .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value != null) controller.setSort(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<HistoryEventType?>(
                                initialValue: state.filters.historyType,
                                decoration: const InputDecoration(labelText: 'History type'),
                                items: [
                                  const DropdownMenuItem<HistoryEventType?>(value: null, child: Text('All events')),
                                  ...HistoryEventType.values
                                      .map((item) => DropdownMenuItem<HistoryEventType?>(value: item, child: Text(item.name))),
                                ],
                                onChanged: controller.setHistoryType,
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          value: state.filters.savedOnlyFreestyle,
                          onChanged: controller.setSavedFreestyleOnly,
                          title: const Text('Favorites: Pantry Freestyle only'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                _Section(
                  title: 'Saved recipes',
                  emptyText: 'No favorites yet. Save recipes you want to cook again.',
                  children: visibleSaved
                      .map(
                        (item) => ListTile(
                          leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                          title: Text(item.recipeTitle),
                          subtitle: Text('Saved ${DateFormat.yMMMd().add_jm().format(item.savedAt.toLocal())}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => controller.toggleSaved(
                              RecipeSuggestion(
                                id: item.recipeId,
                                title: item.recipeTitle,
                                shortDescription: '',
                                matchType: RecipeMatchType.nearMatch,
                                prepMinutes: 0,
                                cookMinutes: 0,
                                difficulty: 1,
                                familyFriendlyScore: 0,
                                healthScore: 0,
                                fancyScore: 0,
                                servings: 1,
                                dietaryTags: const [],
                                requirements: const [],
                                missingIngredients: const [],
                                availableIngredients: const [],
                                steps: const [],
                                suggestedPairings: const [],
                                explanation: const RecipeExplanation(summary: '', pantryHighlights: []),
                                isPantryFreestyle: item.isPantryFreestyle,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                _Section(
                  title: 'Recent history',
                  emptyText: 'Your activity will show up here as you explore and cook.',
                  children: visibleHistory
                      .map(
                        (item) => ListTile(
                          leading: Icon(_historyIcon(item.type)),
                          title: Text(item.recipeTitle),
                          subtitle: Text('${item.type.name} • ${DateFormat.yMMMd().add_jm().format(item.occurredAt.toLocal())}'),
                          trailing: item.isPantryFreestyle ? const Chip(label: Text('Freestyle')) : null,
                        ),
                      )
                      .toList(growable: false),
                ),
                if (!expandedHistory) ...[
                  const LockedFeatureTile(
                    feature: PremiumFeature.expandedSavedHistory,
                    title: 'Expanded saved history',
                    subtitle: 'Unlock longer retention and more detailed history',
                  ),
                  const PremiumUpsellCard(compact: true),
                ],
              ],
            ),
    );
  }

  IconData _historyIcon(HistoryEventType type) {
    return switch (type) {
      HistoryEventType.viewedRecipe => Icons.visibility_outlined,
      HistoryEventType.savedRecipe => Icons.favorite_border,
      HistoryEventType.startedCookMode => Icons.play_circle_outline,
      HistoryEventType.completedCookMode => Icons.check_circle_outline,
      HistoryEventType.generatedFreestyleIdea => Icons.auto_awesome,
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.emptyText, required this.children});

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(emptyText),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
