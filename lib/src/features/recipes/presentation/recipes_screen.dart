import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/branded_ui.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(recipeSuggestionsProvider);
    final discovery = ref.watch(recipeDiscoveryProvider);

    return AppScaffold(
      title: 'Recipe suggestions',
      adPlacement: AdPlacement.homeBanner,
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
                    Tab(text: 'Exact'),
                    Tab(text: 'Almost There'),
                    Tab(text: 'Pantry Freestyle'),
                  ],
                ),
                const SizedBox(height: 8),
                const _MatchEducationBanner(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _RecipeList(recipes: bestMatches, showNativeAd: true),
                      _RecipeList(recipes: almostThere),
                      _RecipeList(recipes: freestyle),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SingleChildScrollView(
          child: Column(
            children: [
              BrandedIllustrationSlot(
                title: 'PantryPilot is prepping ideas',
                subtitle: 'Matching your pantry to dinner possibilities.',
                icon: Icons.ramen_dining_outlined,
              ),
              SizedBox(height: 12),
              BrandedLoadingSkeleton(rows: 5),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 36),
                const SizedBox(height: 8),
                Text('Unable to load recipes: $error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.read(recipeGenerationTickProvider.notifier).state++,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes, this.showNativeAd = false});

  final List<RecipeSuggestion> recipes;
  final bool showNativeAd;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: BrandedIllustrationSlot(
            title: 'No picks in this lane yet',
            subtitle: 'Try another tab or adjust filters for broader suggestions.',
            icon: Icons.menu_book_outlined,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: recipes.length + (showNativeAd ? 1 : 0),
      itemBuilder: (context, index) {
        if (showNativeAd && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: AdPlacementSlot(placement: AdPlacement.recipesNative),
          );
        }
        final recipeIndex = showNativeAd ? index - 1 : index;
        return _RecipeCard(recipe: recipes[recipeIndex]);
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final RecipeSuggestion recipe;

  @override
  Widget build(BuildContext context) {
    final badgeText = recipe.isPantryFreestyle ? 'Pantry Freestyle (Creative AI)' : recipe.matchType.label;
    return Card(
      child: InkWell(
        onTap: () => context.pushRecipeDetail(recipe),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: recipe.heroImageUrl == null
                      ? Container(
                          color: Colors.orange.shade50,
                          child: const Center(child: Icon(Icons.restaurant_menu, size: 36)),
                        )
                      : Image.network(
                          recipe.heroImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.orange.shade50,
                            child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 32)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
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
              Text(_explanationLabel(recipe.matchType), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(recipe.explanation.summary),
            ],
          ),
        ),
      ),
    );
  }

  String _explanationLabel(RecipeMatchType matchType) => switch (matchType) {
        RecipeMatchType.exact => 'Exact match',
        RecipeMatchType.nearMatch => 'Almost there',
        RecipeMatchType.pantryFreestyle => 'Pantry Freestyle (creative AI output)',
      };
}

class _MatchEducationBanner extends StatelessWidget {
  const _MatchEducationBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('How matches work', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Exact: you can cook now. Almost There: quick top-up trip. Pantry Freestyle: creative mode for fresh ideas.'),
          ],
        ),
      ),
    );
  }
}
