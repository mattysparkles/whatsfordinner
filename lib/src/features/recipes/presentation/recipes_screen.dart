import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(recipeSuggestionsProvider);
    final discovery = ref.watch(recipeDiscoveryProvider);

    return AppScaffold(
      title: 'Recipe suggestions',
      body: suggestionsAsync.when(
        data: (recipes) {
          final bestMatches = recipes.where((r) => r.matchType == RecipeMatchType.exact).toList(growable: false);
          final almostThere = recipes.where((r) => r.matchType == RecipeMatchType.nearMatch).toList(growable: false);
          final freestyle = recipes.where((r) => r.matchType == RecipeMatchType.pantryFreestyle).toList(growable: false);

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                DropdownButton<RecipeSortOption>(
                  value: discovery.sortOption,
                  isExpanded: true,
                  items: RecipeSortOption.values
                      .map((option) => DropdownMenuItem(value: option, child: Text(option.label)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(recipeDiscoveryProvider.notifier).setSortOption(value);
                    }
                  },
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Best Matches'),
                    Tab(text: 'Almost There'),
                    Tab(text: 'Pantry Freestyle'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _RecipeList(recipes: bestMatches),
                      _RecipeList(recipes: almostThere),
                      _RecipeList(recipes: freestyle),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load recipes: $error')),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes});

  final List<RecipeSuggestion> recipes;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(child: Text('No suggestions yet for this category.'));
    }
    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) => _RecipeCard(recipe: recipes[index]),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final RecipeSuggestion recipe;

  @override
  Widget build(BuildContext context) {
    final badgeText = recipe.isPantryFreestyle ? 'Pantry Freestyle (AI idea)' : recipe.matchType.label;
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.recipeDetail, extra: recipe),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(recipe.shortDescription),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('$badgeText')),
                  Chip(label: Text('${recipe.totalMinutes} min')),
                  Chip(label: Text('Serves ${recipe.servings}')),
                  Chip(label: Text('Missing ${recipe.missingIngredients.length}')),
                  ...recipe.dietaryTags.map((tag) => Chip(label: Text(tag))),
                ],
              ),
              const SizedBox(height: 8),
              Text('Why suggested: ${recipe.explanation.summary}'),
            ],
          ),
        ),
      ),
    );
  }
}
