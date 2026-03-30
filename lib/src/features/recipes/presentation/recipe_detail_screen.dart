import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = GoRouterState.of(context).extra as RecipeSuggestion?;
    if (recipe == null) {
      return const AppScaffold(
        title: 'Recipe detail',
        body: Center(child: Text('No recipe selected.')),
      );
    }

    return AppScaffold(
      title: recipe.title,
      body: ListView(
        children: [
          Text(recipe.shortDescription),
          const SizedBox(height: 8),
          Text('Why this was suggested: ${recipe.explanation.summary}'),
          const Divider(),
          const Text('Available ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.availableIngredients.map((item) => ListTile(leading: const Icon(Icons.check_circle), title: Text(item))),
          const Divider(),
          const Text('Missing ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
          if (recipe.missingIngredients.isEmpty)
            const ListTile(title: Text('None. You can make this now.')),
          ...recipe.missingIngredients.map(
            (item) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(item.ingredientName),
              subtitle: Text('Substitutions: ${item.suggestedSubstitutions.join(', ')}'),
            ),
          ),
          const Divider(),
          const Text('Suggested substitutions', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.missingIngredients.expand(
            (item) => item.suggestedSubstitutions
                .map((sub) => ListTile(title: Text('${item.ingredientName} → $sub')))
                .toList(growable: false),
          ),
          const Divider(),
          const Text('Pairings (placeholder)', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.suggestedPairings.map((pairing) => ListTile(title: Text(pairing.title), subtitle: Text(pairing.description))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(favoritesRepositoryProvider).saveRecipe(recipe.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to favorites.')));
                  }
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('Save favorite'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(shoppingListControllerProvider.notifier).createFromRecipe(recipe);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added missing ingredients to shopping list.')));
                  context.push(AppRoutes.shoppingList);
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add missing to shopping list'),
              ),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.cookMode),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start cook mode'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
