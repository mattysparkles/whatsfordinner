import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  int _index = 0;
  bool _voiceOn = false;

  @override
  Widget build(BuildContext context) {
    final recipe = GoRouterState.of(context).extra as RecipeSuggestion?;
    final steps = recipe?.steps ?? const [CookingStep(order: 1, instruction: 'Choose a recipe to start cook mode.')];
    final current = steps[_index.clamp(0, steps.length - 1)];

    return Scaffold(
      appBar: AppBar(title: const Text('Cook Mode')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              LinearProgressIndicator(value: (_index + 1) / steps.length),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(current.instruction, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _index == 0 ? null : () => setState(() => _index--), child: const Text('Back'))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(onPressed: _index >= steps.length - 1 ? null : () => setState(() => _index++), child: const Text('Next'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      value: _voiceOn,
                      onChanged: (value) => setState(() => _voiceOn = value),
                      title: const Text('Voice narration'),
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.timer_outlined), tooltip: 'Timer placeholder'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
