import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../domain/models/models.dart';

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantryState = ref.watch(pantryControllerProvider);
    final controller = ref.read(pantryControllerProvider.notifier);
    final grouped = pantryState.groupedByCategory;

    return AppScaffold(
      title: 'Pantry Inventory',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: pantryState.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading pantry items...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (pantryState.errorMessage != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(pantryState.errorMessage!),
                        trailing: TextButton(
                          onPressed: controller.clearError,
                          child: const Text('Dismiss'),
                        ),
                      ),
                    ),
                  TextField(
                    onChanged: controller.setSearchQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search ingredients',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text(pantryState.filters.sourceType?.name ?? 'Any source'),
                          selected: pantryState.filters.sourceType != null,
                          onSelected: (_) => _showSourceFilterPicker(context, ref),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(pantryState.filters.freshnessState?.name ?? 'Any freshness'),
                          selected: pantryState.filters.freshnessState != null,
                          onSelected: (_) => _showFreshnessFilterPicker(context, ref),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _QuickAddRow(
                    onQuickAdd: (value) => _showItemEditor(context, ref, prefillName: value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: grouped.isEmpty
                        ? const _EmptyPantryState()
                        : ListView(
                            children: grouped.entries.map((entry) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Chip(label: Text(_categoryLabel(entry.key))),
                                      ],
                                    ),
                                  ),
                                  ...entry.value.map(
                                    (item) => Card(
                                      child: ListTile(
                                        title: Text(item.ingredient.name),
                                        subtitle: Text(
                                          '${item.quantityInfo.displayText} • ${_provenanceLabel(item)}'
                                          ' • ${item.estimatedFreshnessState.name}'
                                          '${item.hasAiConfidence ? ' • ${((item.confidence * 100).round())}% confidence' : ''}',
                                        ),
                                        isThreeLine: item.ingredient.normalizedName != null,
                                        leading: item.ingredient.normalizedName == null
                                            ? null
                                            : Tooltip(
                                                message: 'Normalized: ${item.ingredient.normalizedName}',
                                                child: const Icon(Icons.auto_fix_high_outlined),
                                              ),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showItemEditor(context, ref, editingItem: item);
                                              return;
                                            }
                                            controller.deleteItem(item.id);
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showSourceFilterPicker(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<PantrySourceType?>(
      context: context,
      builder: (_) => _EnumPickerSheet<PantrySourceType>(
        title: 'Filter by source',
        values: PantrySourceType.values,
        labelFor: _sourceLabel,
      ),
    );
    ref.read(pantryControllerProvider.notifier).setSourceFilter(selected);
  }

  Future<void> _showFreshnessFilterPicker(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<FreshnessState?>(
      context: context,
      builder: (_) => _EnumPickerSheet<FreshnessState>(
        title: 'Filter by freshness',
        values: FreshnessState.values,
        labelFor: (value) => value.name,
      ),
    );
    ref.read(pantryControllerProvider.notifier).setFreshnessFilter(selected);
  }

  Future<void> _showItemEditor(
    BuildContext context,
    WidgetRef ref, {
    PantryItem? editingItem,
    String? prefillName,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PantryItemEditorSheet(
        editingItem: editingItem,
        prefillName: prefillName,
      ),
    );
  }
}

class _PantryItemEditorSheet extends ConsumerStatefulWidget {
  const _PantryItemEditorSheet({this.editingItem, this.prefillName});

  final PantryItem? editingItem;
  final String? prefillName;

  @override
  ConsumerState<_PantryItemEditorSheet> createState() => _PantryItemEditorSheetState();
}

class _PantryItemEditorSheetState extends ConsumerState<_PantryItemEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late IngredientCategory _category;
  late PantrySourceType _sourceType;

  @override
  void initState() {
    super.initState();
    final item = widget.editingItem;
    _nameController = TextEditingController(text: item?.ingredient.name ?? widget.prefillName ?? '');
    _amountController = TextEditingController(text: item?.quantityInfo.amount?.toString() ?? '');
    _unitController = TextEditingController(text: item?.quantityInfo.unit ?? '');
    _category = item?.ingredient.category ?? IngredientCategory.other;
    _sourceType = item?.sourceType ?? PantrySourceType.manual;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.editingItem == null ? 'Add pantry item' : 'Edit pantry item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Ingredient name')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Unit (optional)'))),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<IngredientCategory>(
              value: _category,
              items: IngredientCategory.values
                  .map((category) => DropdownMenuItem(value: category, child: Text(_categoryLabel(category))))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _category = value ?? IngredientCategory.other),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PantrySourceType>(
              value: _sourceType,
              items: PantrySourceType.values
                  .map((source) => DropdownMenuItem(value: source, child: Text(_sourceLabel(source))))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _sourceType = value ?? PantrySourceType.manual),
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                final amount = double.tryParse(_amountController.text.trim());
                await ref.read(pantryControllerProvider.notifier).addOrUpdateItem(
                      id: widget.editingItem?.id,
                      ingredientName: name,
                      category: _category,
                      amount: amount,
                      unit: _unitController.text,
                      sourceType: _sourceType,
                      confidence: _sourceType == PantrySourceType.manual ? 1 : 0.8,
                      provenanceType: PantryItemProvenanceType.manual,
                    );
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Save item'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QuickAddRow extends ConsumerWidget {
  const _QuickAddRow({required this.onQuickAdd});

  final ValueChanged<String> onQuickAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(pantryQuickAddSuggestionsProvider);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) => ActionChip(label: Text(suggestions[index]), onPressed: () => onQuickAdd(suggestions[index])),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: suggestions.length,
      ),
    );
  }
}

class _EmptyPantryState extends StatelessWidget {
  const _EmptyPantryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.kitchen_outlined, size: 36),
          SizedBox(height: 8),
          Text('Your pantry is empty.'),
          Text('Use quick add chips or tap Add item to get started.'),
        ],
      ),
    );
  }
}

class _EnumPickerSheet<T> extends StatelessWidget {
  const _EnumPickerSheet({required this.title, required this.values, required this.labelFor});

  final String title;
  final List<T> values;
  final String Function(T value) labelFor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(title)),
          ListTile(
            title: const Text('Any'),
            onTap: () => Navigator.of(context).pop(null),
          ),
          ...values.map(
            (value) => ListTile(
              title: Text(labelFor(value)),
              onTap: () => Navigator.of(context).pop(value),
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(IngredientCategory category) {
  switch (category) {
    case IngredientCategory.produce:
      return 'Produce';
    case IngredientCategory.dairy:
      return 'Dairy';
    case IngredientCategory.meatSeafood:
      return 'Meat & seafood';
    case IngredientCategory.grainsBread:
      return 'Grains & bread';
    case IngredientCategory.cannedJarred:
      return 'Canned & jarred';
    case IngredientCategory.frozen:
      return 'Frozen';
    case IngredientCategory.baking:
      return 'Baking';
    case IngredientCategory.spicesSeasonings:
      return 'Spices';
    case IngredientCategory.oilsCondiments:
      return 'Oils & condiments';
    case IngredientCategory.snacks:
      return 'Snacks';
    case IngredientCategory.beverages:
      return 'Beverages';
    case IngredientCategory.other:
      return 'Other';
  }
}

String _sourceLabel(PantrySourceType sourceType) {
  switch (sourceType) {
    case PantrySourceType.manual:
      return 'Manual';
    case PantrySourceType.pantryPhoto:
      return 'Pantry photo';
    case PantrySourceType.fridgePhoto:
      return 'Fridge photo';
    case PantrySourceType.freezerPhoto:
      return 'Freezer photo';
    case PantrySourceType.groceryScreenshot:
      return 'Screenshot';
    case PantrySourceType.aiImport:
      return 'AI import';
  }
}

String _provenanceLabel(PantryItem item) {
  if (item.provenance.isEmpty) return _sourceLabel(item.sourceType);
  switch (item.provenance.last.type) {
    case PantryItemProvenanceType.manual:
      return 'Manual';
    case PantryItemProvenanceType.captureSession:
      return 'Capture session';
    case PantryItemProvenanceType.screenshotImport:
      return 'Screenshot import';
    case PantryItemProvenanceType.recipeImport:
      return 'Recipe import';
  }
}
