import 'package:flutter/material.dart';

class PlaceholderFeatureCard extends StatelessWidget {
  const PlaceholderFeatureCard({required this.label, this.todo, super.key});

  final String label;
  final String? todo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: todo == null ? null : Text(todo!),
      ),
    );
  }
}
