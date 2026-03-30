import 'package:flutter/material.dart';

import '../../shared/widgets/primary_scaffold.dart';

class FavoritesAndHistoryScreen extends StatelessWidget {
  const FavoritesAndHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Favorites & History',
      body: ListView(
        children: const [
          Card(child: ListTile(title: Text('Saved recipes'), subtitle: Text('Your hearted go-to meals'))),
          Card(child: ListTile(title: Text('Recent meals'), subtitle: Text('What you cooked this week'))),
          Card(child: ListTile(title: Text('Past AI inventions'), subtitle: Text('Your creative experiments'))),
          Card(child: ListTile(title: Text('Pinned family favorites'), subtitle: Text('Top-loved recipes'))),
        ],
      ),
    );
  }
}
