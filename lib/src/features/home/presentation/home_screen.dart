import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/branded_ui.dart';
import '../../monetization/domain/ad_placement.dart';
import '../../monetization/domain/entitlements.dart';
import '../../monetization/presentation/widgets/monetization_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _dietaryFilters = ['vegetarian', 'vegan', 'gluten-free', 'dairy-free'];
  static const _preferenceFilters = ['family friendly', 'healthier', 'fancy', 'easy cleanup'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(recipeDiscoveryProvider);
    final pantryItems = ref.watch(pantryControllerProvider).items;
    final demoMode = ref.watch(demoScriptModeProvider);
    final demoStep = ref.watch(demoScriptStepProvider);

    return AppScaffold(
      title: 'PantryPilot',
      adPlacement: AdPlacement.homeBanner,
      actions: [
        IconButton(
          onPressed: () => context.push(AppRoutes.preferences),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        children: [
          const Text('What are we making tonight?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (demoMode)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Demo Script Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_demoNarration(demoStep)),
                trailing: Text('Step ${demoStep + 1}/5'),
              ),
            ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: pantryItems.isEmpty
                ? Card(
                    key: const ValueKey('empty-pantry-home'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandedIllustrationSlot(
                            title: 'Pantry waiting for ingredients',
                            subtitle: 'Replace with branded empty-state artwork: empty_pantry.png',
                            icon: Icons.flight,
                          ),
                          const SizedBox(height: 10),
                          const Text('Start here: add ingredients to unlock better suggestions.'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.capture),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Scan pantry items'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: MealType.values
                .map(
                  (mealType) => ChoiceChip(
                    label: Text(mealType.name),
                    selected: mealType == discovery.mealType,
                    onSelected: (_) => ref.read(recipeDiscoveryProvider.notifier).setMealType(mealType),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Dietary filters', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: _dietaryFilters
                .map(
                  (filter) => FilterChip(
                    label: Text(filter),
                    selected: discovery.dietaryFilters.contains(filter),
                    onSelected: (_) => ref.read(recipeDiscoveryProvider.notifier).toggleDietaryFilter(filter),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text('Cooking preferences', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: _preferenceFilters
                .map(
                  (filter) => FilterChip(
                    label: Text(filter),
                    selected: discovery.preferenceFilters.contains(filter),
                    onSelected: (_) => ref.read(recipeDiscoveryProvider.notifier).togglePreferenceFilter(filter),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Servings', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: '${discovery.servings}',
                  value: discovery.servings.toDouble(),
                  onChanged: (value) => ref.read(recipeDiscoveryProvider.notifier).setServings(value.toInt()),
                ),
              ),
              Text('${discovery.servings}'),
            ],
          ),
          FilledButton.icon(
            onPressed: () {
              ref.read(recipeGenerationTickProvider.notifier).state++;
              if (demoMode) {
                advanceDemoScriptStep(ref);
              }
              context.push(AppRoutes.recipes);
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate suggestions'),
          ),
          const SizedBox(height: 16),
          _NavigationTile(label: 'Scan ingredients', route: AppRoutes.capture),
          _NavigationTile(label: 'Review pantry', route: AppRoutes.pantry),
          _NavigationTile(label: 'Shopping handoff', route: AppRoutes.shoppingList),
          _NavigationTile(label: 'Meal planning', route: AppRoutes.mealPlanning),
          _NavigationTile(label: 'Favorites & history', route: AppRoutes.favoritesHistory),
          _NavigationTile(label: 'Premium & monetization', route: AppRoutes.monetization),
          const LockedFeatureTile(
            feature: PremiumFeature.premiumAiChefMode,
            title: 'Premium AI chef mode',
            subtitle: 'Hands-on adaptive chef guidance (coming later)',
          ),
        ],
      ),
    );
  }

  String _demoNarration(int step) {
    return switch (step) {
      0 => 'Welcome moment: pantry is pre-seeded so you can jump directly into value.',
      1 => 'Capture review story: confirm parsed items and clean up anything uncertain.',
      2 => 'Discovery story: compare Exact, Almost There, and Pantry Freestyle.',
      3 => 'Execution story: open recipe detail then start cook mode.',
      _ => 'Handoff story: send missing items to shopping and finish confident.',
    };
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
