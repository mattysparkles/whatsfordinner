import 'package:flutter/material.dart';

import '../../features/monetization/domain/ad_placement.dart';
import '../../features/monetization/presentation/widgets/monetization_widgets.dart';
import '../theme/design_tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
    this.floatingActionButton,
    this.adPlacement,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final AdPlacement? adPlacement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMd),
          child: Column(
            children: [
              Expanded(child: body),
              if (adPlacement != null) ...[
                const SizedBox(height: 12),
                AdPlacementSlot(placement: adPlacement!),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
