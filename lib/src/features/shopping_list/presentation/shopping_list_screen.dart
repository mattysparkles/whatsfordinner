import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/user_error_messaging_service.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../monetization/domain/ad_placement.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shoppingListControllerProvider);
    final linkGenerationState = ref.watch(shoppingLinkGenerationStateProvider);
    final launchState = ref.watch(shoppingLinkLaunchStateProvider);
    final list = state.list;
    final instacartProvider = _providerById(state.activeProviders, 'instacart');
    final amazonProvider = _providerById(state.activeProviders, 'amazon');
    final savedResults = state.linksByListId[list?.id ?? ''] ?? state.linkResults;
    final linkByProviderId = {for (final link in savedResults) link.provider.id: link};

    if (list == null || list.items.isEmpty) {
      return const AppScaffold(
        title: 'Shopping List',
        adPlacement: AdPlacement.shoppingBanner,
        body: Center(
          child: Text('No shopping list yet. Open a recipe and tap “Add missing to shopping list” to create one.'),
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
          const SizedBox(height: 8),
          _ProviderLaunchStateCard(providers: state.activeProviders, linkByProviderId: linkByProviderId),
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
                onPressed: instacartProvider?.capabilityLabel == ProviderCapabilityLabel.active
                    ? () => _generateLinks(context, ref, providerId: 'instacart')
                    : null,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Order with Instacart'),
              ),
              OutlinedButton.icon(
                onPressed: amazonProvider?.capabilityLabel == ProviderCapabilityLabel.active
                    ? () => _generateLinks(context, ref, providerId: 'amazon')
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Amazon links'),
              ),
              if (linkByProviderId['instacart']?.checkoutUri != null)
                OutlinedButton.icon(
                  onPressed: () => _openLink(
                    context,
                    ref,
                    linkByProviderId['instacart']!.checkoutUri!,
                    providerName: 'Instacart',
                  ),
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Open last Instacart link'),
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
          if (launchState != null) ...[
            const SizedBox(height: 12),
            Card(
              color: launchState.$1 ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(launchState.$2),
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
                  trailing: link.checkoutUri != null
                      ? IconButton(
                          icon: const Icon(Icons.launch),
                          tooltip: 'Open provider link',
                          onPressed: () => _openLink(context, ref, link.checkoutUri!, providerName: link.provider.name),
                        )
                      : null,
                )),
            ...state.linkResults.expand(
              (link) => link.itemUris.map(
                (itemUri) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.link),
                  title: Text(itemUri.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${link.provider.name} item link'),
                  onTap: () => _openLink(context, ref, itemUri, providerName: link.provider.name),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  CommerceProvider? _providerById(List<CommerceProvider> providers, String id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  Future<void> _generateLinks(BuildContext context, WidgetRef ref, {required String providerId}) async {
    final state = ref.read(shoppingListControllerProvider);
    final list = state.list;
    if (list == null) return;
    ref.read(shoppingLinkGenerationStateProvider.notifier).state = const AsyncLoading<void>();
    try {
      final provider = state.activeProviders.firstWhere((item) => item.id == providerId);
      if (provider.capabilityLabel != ProviderCapabilityLabel.active) {
        ref.read(shoppingLinkLaunchStateProvider.notifier).state = (
          false,
          '${provider.name} is configured but currently unavailable in this build.',
        );
        return;
      }
      final service = ref.read(shoppingLinkServiceProvider);
      final result = await service.buildLinks(list: list, providers: [provider]);
      ref.read(shoppingListControllerProvider.notifier).setLinkResults(result);
      ref.read(shoppingLinkGenerationStateProvider.notifier).state = const AsyncData(null);
      await ref.read(analyticsServiceProvider).logEvent(
        AppAnalyticsEvent.shoppingHandoffStarted,
        parameters: {'provider': provider.id, 'itemCount': list.items.length},
      );
      if (context.mounted) {
        ref.read(userErrorMessagingServiceProvider).show(
          context,
          message: UserMessage(title: 'Links ready', details: 'Built ${provider.name} shopping links.'),
        );
      }
    } catch (error, stackTrace) {
      await ref.read(crashReportingServiceProvider).recordError(
        error,
        stackTrace,
        reason: 'Shopping link generation failed',
        context: {'providerId': providerId},
      );
      ref.read(shoppingLinkGenerationStateProvider.notifier).state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _copyList(BuildContext context, WidgetRef ref) async {
    final text = _listAsText(ref.read(shoppingListControllerProvider).list);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ref.read(userErrorMessagingServiceProvider).show(
        context,
        message: const UserMessage(title: 'Copied', details: 'Shopping list copied.'),
      );
    }
  }

  Future<void> _shareList(BuildContext context, WidgetRef ref) async {
    final text = _listAsText(ref.read(shoppingListControllerProvider).list);
    await Share.share(text, subject: 'PantryPilot shopping list');
    if (context.mounted) {
      ref.read(userErrorMessagingServiceProvider).show(
        context,
        message: const UserMessage(
          title: 'Share started',
          details: 'Opened share sheet. Recipients can shop from the list in their own apps.',
        ),
      );
    }
  }

  Future<void> _openLink(BuildContext context, WidgetRef ref, Uri uri, {required String providerName}) async {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (success) {
      await ref.read(analyticsServiceProvider).logEvent(
        AppAnalyticsEvent.shoppingHandoffStarted,
        parameters: {'provider': providerName, 'mode': 'external_launch'},
      );
      ref.read(shoppingLinkLaunchStateProvider.notifier).state = (true, 'Opened $providerName successfully.');
    } else {
      ref.read(shoppingLinkLaunchStateProvider.notifier).state = (
        false,
        'Could not open $providerName link on this device.',
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

class _ProviderLaunchStateCard extends StatelessWidget {
  const _ProviderLaunchStateCard({required this.providers, required this.linkByProviderId});

  final List<CommerceProvider> providers;
  final Map<String, ShoppingLinkResult> linkByProviderId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provider link state', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...providers.map((provider) {
              final link = linkByProviderId[provider.id];
              final hasLaunchable = link?.checkoutUri != null || (link?.itemUris.isNotEmpty ?? false);
              final subtitle = link == null
                  ? 'No generated link yet for this list.'
                  : hasLaunchable
                      ? 'Ready to open: ${link.message}'
                      : link.message;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(hasLaunchable ? Icons.check_circle_outline : Icons.radio_button_unchecked),
                title: Text(provider.name),
                subtitle: Text(subtitle),
              );
            }),
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
