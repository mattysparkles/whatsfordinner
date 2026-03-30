import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/app_scaffold.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(recipeSuggestionsProvider);

    return AppScaffold(
      title: 'Recipes',
      body: suggestionsAsync.when(
        data: (recipes) => ListView(
          children: recipes
              .map(
                (recipe) => Card(
                  child: ListTile(
                    title: Text(recipe.title),
                    subtitle: Text('${recipe.matchType.name} • ${recipe.totalMinutes} mins'),
                  ),
                ),
              )
              .toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load recipes: $error')),
      ),
    );
  }
}
