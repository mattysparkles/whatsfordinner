import 'package:flutter/material.dart';

import 'presentation/pantry_screen.dart';

@Deprecated('Use PantryScreen from presentation folder.')
class PantryInventoryScreen extends StatelessWidget {
  const PantryInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const PantryScreen();
}
