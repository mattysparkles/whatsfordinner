import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../domain/models/models.dart';
import '../../shared/widgets/primary_scaffold.dart';

class PantryInventoryScreen extends ConsumerWidget {
  const PantryInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pantryControllerProvider);
    return PrimaryScaffold(
      title: 'Pantry Inventory',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(pantryControllerProvider.notifier).addItem(
              PantryItem(
                id: const Uuid().v4(),
                ingredient: Ingredient(id: const Uuid().v4(), name: 'New ingredient'),
                confidence: 1,
              ),
            ),
        label: const Text('Add Item'),
      ),
      body: Column(
        children: [
          const TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search ingredients')),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No pantry items yet. Scan or add manually.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => Card(
                      child: ListTile(
                        title: Text(items[i].ingredient.name),
                        subtitle: Text('Confidence ${(items[i].confidence * 100).round()}% · freshness placeholder'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
