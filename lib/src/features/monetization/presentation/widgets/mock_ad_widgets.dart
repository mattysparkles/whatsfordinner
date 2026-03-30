import 'package:flutter/material.dart';

class MockBannerAdWidget extends StatelessWidget {
  const MockBannerAdWidget({super.key, this.label = 'Sponsored'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('$label • Mock banner ad placement')),
          TextButton(onPressed: () {}, child: const Text('Learn more')),
        ],
      ),
    );
  }
}

class MockNativeAdWidget extends StatelessWidget {
  const MockNativeAdWidget({super.key, this.headline = 'Kitchen essentials pick'});

  final String headline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
        title: Text(headline),
        subtitle: const Text('Mock native ad that blends with content, clearly labeled.'),
        trailing: const Chip(label: Text('Ad')),
      ),
    );
  }
}

class MockRewardedPromptWidget extends StatelessWidget {
  const MockRewardedPromptWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text('Rewarded prompt placeholder'),
        subtitle: const Text('Future optional reward flow can be integrated here.'),
        trailing: OutlinedButton(onPressed: () {}, child: const Text('Try demo')),
      ),
    );
  }
}
