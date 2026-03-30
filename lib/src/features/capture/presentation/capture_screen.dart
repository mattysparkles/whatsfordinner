import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/placeholder_feature_card.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Capture',
      body: Column(
        children: [
          PlaceholderFeatureCard(label: 'Photo capture', todo: 'TODO: add camera/gallery integration.'),
          PlaceholderFeatureCard(label: 'OCR pipeline', todo: 'TODO: connect to VisionService and ingredient review flow.'),
        ],
      ),
    );
  }
}
