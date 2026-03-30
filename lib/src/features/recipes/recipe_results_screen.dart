import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/primary_scaffold.dart';

class RecipeResultsScreen extends ConsumerWidget {
  const RecipeResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(recipeSuggestionsProvider);
    return PrimaryScaffold(
      title: 'Recipe Suggestions',
      body: suggestionsAsync.when(
        data: (suggestions) => DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const TabBar(tabs: [Tab(text: 'Best Matches'), Tab(text: 'Almost There'), Tab(text: 'AI Creations')]),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: 'fastest',
                isExpanded: true,
                items: const ['easiest', 'fastest', 'fewest missing ingredients', 'healthiest', 'family-friendly', 'fanciest']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              Expanded(
                child: ListView(
                  children: suggestions.map((recipe) => _RecipeCard(recipe: recipe)).toList(),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load suggestions.')),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});
  final RecipeSuggestion recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.restaurant_menu),
        title: Text(recipe.title),
        subtitle: Text('${recipe.mealType.name} · ${recipe.totalMinutes} min · missing ${recipe.missingIngredients.length}'),
        trailing: Chip(label: Text(recipe.matchType.name)),
        onTap: () => context.push('/recipe', extra: recipe),
      ),
    );
  }
}
