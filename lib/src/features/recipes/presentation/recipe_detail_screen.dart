import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/app_scaffold.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, this.seedRecipe});

  final RecipeSuggestion? seedRecipe;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _trackedOpen = false;
  late int _targetFeeds = widget.seedRecipe?.servings ?? 2;

  @override
  void initState() {
    super.initState();
    final seedRecipe = widget.seedRecipe;
    if (seedRecipe != null) {
      ref.read(selectedRecipeProvider.notifier).state = seedRecipe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.seedRecipe ?? ref.watch(selectedRecipeProvider);
    if (recipe == null) {
      return const AppScaffold(
        title: 'Recipe detail',
        body: Center(child: Text('No recipe selected.')),
      );
    }
    if (!_trackedOpen) {
      _trackedOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(favoritesHistoryControllerProvider.notifier).trackEvent(
              type: HistoryEventType.viewedRecipe,
              recipe: recipe,
            );
        await ref.read(analyticsServiceProvider).logEvent(
          AppAnalyticsEvent.recipeOpened,
          parameters: {'recipeId': recipe.id, 'matchType': recipe.matchType.name},
        );
      });
    }
    final historyState = ref.watch(favoritesHistoryControllerProvider);
    final isSaved = historyState.savedRecipes.any((item) => item.recipeId == recipe.id);
    return AppScaffold(
      title: recipe.title,
      body: ListView(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: recipe.heroImageUrl == null
                  ? Container(
                      color: Colors.orange.shade50,
                      child: const Center(child: Icon(Icons.restaurant, size: 44)),
                    )
                  : Image.network(
                      recipe.heroImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.orange.shade50,
                        child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 36)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(recipe.shortDescription),
          const SizedBox(height: 12),
          Text(_matchHeading(recipe), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(recipe.explanation.summary),
          if (recipe.matchType == RecipeMatchType.pantryFreestyle) ...[
            const SizedBox(height: 8),
            const Text(
              'Pantry Freestyle is creative AI output. Verify temps, doneness, and seasoning while cooking.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          const Divider(),
          Text('Feeds $_targetFeeds people', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            min: 1,
            max: 12,
            divisions: 11,
            value: _targetFeeds.toDouble(),
            label: '$_targetFeeds',
            onChanged: (value) => setState(() => _targetFeeds = value.round()),
          ),
          const Text('Scaled ingredient guidance', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.requirements.map((item) {
            final scaled = _scaledAmount(item.requiredAmount, recipe.servings, _targetFeeds);
            return ListTile(
              leading: const Icon(Icons.tune),
              title: Text(item.ingredientName),
              subtitle: Text('${scaled.toStringAsFixed(scaled == scaled.roundToDouble() ? 0 : 1)} ${item.unit}'),
            );
          }),
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
          const Text('Pairings', style: TextStyle(fontWeight: FontWeight.bold)),
          ...PairingCategory.values.map((category) {
            final items = recipe.suggestedPairings.where((item) => item.category == category).toList(growable: false);
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(_pairingTitle(category), style: const TextStyle(fontWeight: FontWeight.w600)),
                ...items.map((pairing) => ListTile(title: Text(pairing.title), subtitle: Text(pairing.description))),
              ],
            );
          }),
          const Divider(),
          const Text('Leftovers', style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.kitchen_outlined),
            title: const Text('Storage method'),
            subtitle: Text(recipe.leftoverGuidance.storageMethod),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Fridge duration'),
            subtitle: Text(recipe.leftoverGuidance.fridgeDuration),
          ),
          ListTile(
            leading: const Icon(Icons.ac_unit),
            title: const Text('Freezer duration'),
            subtitle: Text(recipe.leftoverGuidance.freezerDuration),
          ),
          ...recipe.leftoverGuidance.reheatingSuggestions.map(
            (tip) => ListTile(leading: const Icon(Icons.microwave_outlined), title: Text(tip)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(favoritesHistoryControllerProvider.notifier).toggleSaved(recipe);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(isSaved ? 'Removed from favorites.' : 'Saved to favorites.')));
                  }
                },
                icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
                label: Text(isSaved ? 'Saved' : 'Save favorite'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(shoppingListControllerProvider.notifier).createFromRecipe(recipe);
                  ref.read(analyticsServiceProvider).logEvent(
                    AppAnalyticsEvent.shoppingHandoffStarted,
                    parameters: {'recipeId': recipe.id, 'missingIngredients': recipe.missingIngredients.length},
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added missing ingredients to shopping list.')));
                  context.pushShoppingList();
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add missing to shopping list'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(favoritesHistoryControllerProvider.notifier).trackEvent(
                        type: HistoryEventType.startedCookMode,
                        recipe: recipe,
                      );
                  await ref.read(analyticsServiceProvider).logEvent(
                    AppAnalyticsEvent.cookModeStarted,
                    parameters: {'recipeId': recipe.id},
                  );
                  if (context.mounted) {
                    context.pushCookMode(recipe);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start cook mode'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _matchHeading(RecipeSuggestion recipe) => switch (recipe.matchType) {
        RecipeMatchType.exact => 'Exact match: ready with what you already have.',
        RecipeMatchType.nearMatch => 'Almost there: small grocery top-up needed.',
        RecipeMatchType.pantryFreestyle => 'Pantry Freestyle (creative AI output).',
      };

  String _pairingTitle(PairingCategory category) => switch (category) {
        PairingCategory.wine => 'Wine',
        PairingCategory.cocktail => 'Cocktail',
        PairingCategory.beer => 'Beer',
        PairingCategory.softDrink => 'Soft drink',
        PairingCategory.appetizerOrSide => 'Appetizer / side',
      };

  double _scaledAmount(double original, int baseServings, int targetServings) {
    if (baseServings <= 0) return original;
    return original * (targetServings / baseServings);
  }
}
