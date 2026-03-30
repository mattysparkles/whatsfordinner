import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shoppingListControllerProvider);
    final linkGenerationState = ref.watch(shoppingLinkGenerationStateProvider);
    final list = state.list;

    if (list == null || list.items.isEmpty) {
      return const AppScaffold(
        title: 'Shopping List',
        adPlacement: AdPlacement.shoppingBanner,
        body: Center(
          child: Text('No shopping list yet. Add missing ingredients from a recipe first.'),
        ),
      );
    }

    return AppScaffold(
      title: 'Shopping List',
      adPlacement: AdPlacement.shoppingBanner,
      body: ListView(
        children: [
          Text(list.title, style: Theme.of(context).textTheme.titleLarge),
          if (list.recipeTitle != null) Text('From recipe: ${list.recipeTitle}'),
          const SizedBox(height: 12),
          _ProviderCapabilityCard(providers: state.activeProviders),
          const SizedBox(height: 12),
          ...state.groupedItems.entries.map(
            (entry) => _GroupedSection(groupLabel: entry.key, items: entry.value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _generateLinks(context, ref, providerId: 'instacart'),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Order with Instacart'),
              ),
              OutlinedButton.icon(
                onPressed: () => _generateLinks(context, ref, providerId: 'amazon'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Amazon links'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyList(context, ref),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy list'),
              ),
              OutlinedButton.icon(
                onPressed: () => _shareList(context, ref),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share list'),
              ),
            ],
          ),
          if (linkGenerationState.isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Generating shopping links...'),
          ],
          if (linkGenerationState.hasError) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Link generation failed. ${linkGenerationState.error}'),
              ),
            ),
          ],
          if (state.linkResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Generated links', style: TextStyle(fontWeight: FontWeight.bold)),
            ...state.linkResults.map((link) => ListTile(
                  leading: Icon(link.canOpenNow ? Icons.check_circle_outline : Icons.schedule),
                  title: Text(link.provider.name),
                  subtitle: Text(link.message),
                  trailing: link.checkoutUri != null ? Text(link.checkoutUri.toString(), textAlign: TextAlign.end) : null,
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _generateLinks(BuildContext context, WidgetRef ref, {required String providerId}) async {
    final state = ref.read(shoppingListControllerProvider);
    final list = state.list;
    if (list == null) return;
    ref.read(shoppingLinkGenerationStateProvider.notifier).state = const AsyncLoading<void>();
    try {
      final provider = state.activeProviders.firstWhere((item) => item.id == providerId);
      final service = ref.read(shoppingLinkServiceProvider);
      final result = await service.buildLinks(list: list, providers: [provider]);
      ref.read(shoppingListControllerProvider.notifier).setLinkResults(result);
      ref.read(shoppingLinkGenerationStateProvider.notifier).state = const AsyncData(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Built ${provider.name} shopping links.')));
      }
    } catch (error, stackTrace) {
      ref.read(shoppingLinkGenerationStateProvider.notifier).state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _copyList(BuildContext context, WidgetRef ref) async {
    final text = _listAsText(ref.read(shoppingListControllerProvider).list);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shopping list copied.')));
    }
  }

  Future<void> _shareList(BuildContext context, WidgetRef ref) async {
    final text = _listAsText(ref.read(shoppingListControllerProvider).list);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share sheet integration is coming later. List copied so you can paste it anywhere.'),
        ),
      );
    }
  }

  String _listAsText(ShoppingList? list) {
    if (list == null) return '';
    final lines = <String>[list.title, ''];
    for (final item in list.items) {
      final qty = item.quantity == null ? '' : '${item.quantity} ';
      final unit = item.unit == null ? '' : '${item.unit} ';
      final note = item.note == null ? '' : ' (${item.note})';
      lines.add('- ${item.ingredientName}: $qty$unit$note'.trim());
    }
    return lines.join('\n');
  }
}

class _ProviderCapabilityCard extends StatelessWidget {
  const _ProviderCapabilityCard({required this.providers});

  final List<CommerceProvider> providers;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provider capability status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...providers.map(
              (provider) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(provider.name),
                subtitle: Text(provider.notes ?? ''),
                trailing: Chip(label: Text(provider.capabilityLabel.label)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedSection extends ConsumerWidget {
  const _GroupedSection({required this.groupLabel, required this.items});

  final String groupLabel;
  final List<ShoppingListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shoppingListControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(value: item.isChecked, onChanged: (_) => controller.toggleChecked(item.id)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.ingredientName),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item.quantity?.toString() ?? '',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    onChanged: (value) => controller.updateQuantity(item.id, value),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item.note ?? '',
                                    decoration: const InputDecoration(labelText: 'Notes'),
                                    onChanged: (value) => controller.updateNotes(item.id, value),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => controller.removeItem(item.id),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove item',
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
