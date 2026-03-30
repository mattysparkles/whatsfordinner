import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMealType = ref.watch(selectedMealTypeProvider);

    return AppScaffold(
      title: 'PantryPilot',
      actions: [
        IconButton(
          onPressed: () => context.push(AppRoutes.preferences),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        children: [
          const Text('What are we making?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: MealType.values
                .map(
                  (mealType) => ChoiceChip(
                    label: Text(mealType.name),
                    selected: mealType == selectedMealType,
                    onSelected: (_) => ref.read(selectedMealTypeProvider.notifier).state = mealType,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _NavigationTile(label: 'Scan ingredients', route: AppRoutes.capture),
          _NavigationTile(label: 'Review pantry', route: AppRoutes.pantry),
          _NavigationTile(label: 'Recipe suggestions', route: AppRoutes.recipes),
          _NavigationTile(label: 'Cook mode', route: AppRoutes.cookMode),
          _NavigationTile(label: 'Shopping list', route: AppRoutes.shoppingList),
          _NavigationTile(label: 'Favorites & history', route: AppRoutes.favoritesHistory),
          _NavigationTile(label: 'Premium & monetization', route: AppRoutes.monetization),
        ],
      ),
    );
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
