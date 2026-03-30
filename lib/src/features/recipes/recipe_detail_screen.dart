import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../../shared/widgets/primary_scaffold.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipe = GoRouterState.of(context).extra as RecipeSuggestion?;
    if (recipe == null) {
      return const PrimaryScaffold(title: 'Recipe', body: Center(child: Text('Select a recipe from results first.')));
    }

    return PrimaryScaffold(
      title: recipe.title,
      body: ListView(
        children: [
          Container(height: 180, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Chip(label: Text(recipe.matchType.name)),
          Text(recipe.description),
          const SizedBox(height: 8),
          Text('Why suggested: ${recipe.whySuggested}'),
          const Divider(),
          const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.requirements.map((e) => CheckboxListTile(value: true, onChanged: (_) {}, title: Text('${e.name} (${e.quantity} ${e.unit})'))),
          const Divider(),
          const Text('Missing items', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.missingIngredients.map((e) => ListTile(title: Text(e.name), subtitle: Text('subs: ${e.substitutions.join(', ')}'))),
          ElevatedButton(onPressed: () => context.push('/shopping'), child: const Text('Add missing to shopping list')),
          ElevatedButton(onPressed: () => context.push('/cook', extra: recipe), child: const Text('Start cook mode')),
        ],
      ),
    );
  }
}
