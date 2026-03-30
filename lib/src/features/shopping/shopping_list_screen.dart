import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../shared/widgets/primary_scaffold.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _list = ShoppingList(id: 'default', title: 'Missing ingredients', items: const [MissingIngredient(name: 'Eggs'), MissingIngredient(name: 'Tortillas')]);
  final Set<String> _checked = {};

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Shopping List',
      body: ListView(
        children: [
          ..._list.items.map(
            (item) => CheckboxListTile(
              value: _checked.contains(item.name),
              onChanged: (_) => setState(() => _checked.contains(item.name) ? _checked.remove(item.name) : _checked.add(item.name)),
              title: Text(item.name),
            ),
          ),
          ElevatedButton(onPressed: () {}, child: const Text('Export List')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('Order with Instacart (placeholder)')),
          OutlinedButton(onPressed: () {}, child: const Text('Open Amazon links (placeholder)')),
          OutlinedButton(onPressed: () {}, child: const Text('Delivery options (placeholder)')),
        ],
      ),
    );
  }
}
