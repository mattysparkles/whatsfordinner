import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/primary_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMeal = ref.watch(mealTypeProvider);
    return PrimaryScaffold(
      title: 'PantryPilot',
      body: ListView(
        children: [
          const SizedBox(height: 12),
          const Text('What are we making?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: MealType.values
                .map((meal) => ChoiceChip(
                      label: Text(meal.name),
                      selected: currentMeal == meal,
                      onSelected: (_) => ref.read(mealTypeProvider.notifier).state = meal,
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _QuickAction(label: 'Scan ingredients', route: '/capture'),
          _QuickAction(label: 'Upload grocery screenshot', route: '/capture'),
          _QuickAction(label: 'Browse from pantry', route: '/pantry'),
          _QuickAction(label: 'Cook favorites', route: '/favorites'),
          _QuickAction(label: 'Plan dinner party', route: '/results', premium: true),
          const Card(child: ListTile(title: Text('Pantry confidence: Medium'), subtitle: Text('Some items need your review.'))),
        ],
      ),
      actions: [IconButton(onPressed: () => context.push('/preferences'), icon: const Icon(Icons.tune))],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.route, this.premium = false});
  final String label;
  final String route;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: premium ? const Chip(label: Text('Premium')) : null,
        onTap: () => context.push(route),
      ),
    );
  }
}
