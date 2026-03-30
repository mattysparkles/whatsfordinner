import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/app_scaffold.dart';

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pantryControllerProvider);

    return AppScaffold(
      title: 'Pantry',
      body: ListView(
        children: [
          for (final item in items)
            Card(
              child: ListTile(
                title: Text(item.name),
                subtitle: Text(item.quantity == null ? 'Quantity not set' : '${item.quantity} ${item.unit ?? ''}'),
              ),
            ),
        ],
      ),
    );
  }
}
