import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../domain/models/models.dart';
import '../../../core/widgets/app_scaffold.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _uuid = const Uuid();
  final List<CapturedImage> _images = [];
  CaptureCategory _selectedSource = CaptureCategory.pantry;
  bool _isParsing = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Capture Ingredients',
      body: ListView(
        children: [
          Text(
            'Add one or more photos/screenshots, then review every ingredient before anything is added to inventory.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CaptureCategory>(
            value: _selectedSource,
            items: CaptureCategory.values
                .map((source) => DropdownMenuItem(value: source, child: Text(_sourceLabel(source))))
                .toList(growable: false),
            onChanged: (value) => setState(() => _selectedSource = value ?? _selectedSource),
            decoration: const InputDecoration(
              labelText: 'Source label',
              helperText: 'Choose where these ingredients are coming from.',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _addMockImage(CaptureInputMethod.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Camera capture'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMockImage(CaptureInputMethod.photoLibrary),
                icon: const Icon(Icons.photo_library),
                label: const Text('Photo library'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addMockImage(CaptureInputMethod.screenshotUpload),
                icon: const Icon(Icons.upload_file),
                label: const Text('Screenshot upload'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session images (${_images.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_images.isEmpty)
                    const Text('No images added yet.')
                  else
                    ..._images.map(
                      (image) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(image.path),
                        subtitle: Text('${_sourceLabel(image.category)} • ${_methodLabel(image.inputMethod)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _images.removeWhere((entry) => entry.id == image.id)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _images.isEmpty || _isParsing ? null : _parseAndReview,
            child: Text(_isParsing ? 'Analyzing...' : 'Review detected ingredients'),
          ),
          const SizedBox(height: 8),
          const Text(
            'PantryPilot never treats image results as certain. You are always in control before inventory changes.',
          ),
        ],
      ),
    );
  }

  void _addMockImage(CaptureInputMethod method) {
    final fileName = '${_selectedSource.name}_${method.name}_${_images.length + 1}.jpg';
    setState(
      () => _images.add(
        CapturedImage(
          id: _uuid.v4(),
          path: fileName,
          category: _selectedSource,
          inputMethod: method,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _parseAndReview() async {
    setState(() => _isParsing = true);
    final parseSession = await ref.read(visionParsingServiceProvider).parseSession(_images);
    setState(() => _isParsing = false);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParseReviewScreen(
          session: parseSession,
          onApprove: (approvedIngredients) async {
            final controller = ref.read(pantryControllerProvider.notifier);
            for (final ingredient in approvedIngredients) {
              await controller.addOrUpdateItem(
                ingredientName: ingredient.suggestedName,
                category: ingredient.category,
                sourceType: PantrySourceType.aiImport,
                confidence: ingredient.confidenceScore,
              );
            }
          },
        ),
      ),
    );
  }
}

class ParseReviewScreen extends StatefulWidget {
  const ParseReviewScreen({
    super.key,
    required this.session,
    required this.onApprove,
  });

  final ParseSession session;
  final Future<void> Function(List<ParsedIngredient> approvedIngredients) onApprove;

  @override
  State<ParseReviewScreen> createState() => _ParseReviewScreenState();
}

class _ParseReviewScreenState extends State<ParseReviewScreen> {
  late List<ParsedIngredient> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.session.parsedIngredients;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Review ingredients',
      actions: [
        IconButton(
          tooltip: 'Merge duplicates',
          onPressed: _items.isEmpty ? null : _mergeDuplicates,
          icon: const Icon(Icons.merge_type),
        ),
      ],
      body: Column(
        children: [
          if (widget.session.hasRecoverableErrors)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Some images need attention:'),
                    const SizedBox(height: 4),
                    ...widget.session.imageErrors.map((error) => Text('• $error')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No ingredients detected. Try clearer photos with labels visible.'),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => _IngredientReviewCard(
                  ingredient: _items[index],
                  onChanged: (updated) => setState(() => _items[index] = updated),
                  onRemoved: () => setState(() => _items.removeAt(index)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _items.any((item) => item.approved) && !_isSaving ? _approveToInventory : null,
            icon: const Icon(Icons.check_circle),
            label: Text(_isSaving ? 'Saving...' : 'Send approved items to inventory'),
          ),
          const SizedBox(height: 6),
          const Text('You can always edit or remove anything before saving.'),
        ],
      ),
    );
  }

  Future<void> _approveToInventory() async {
    setState(() => _isSaving = true);
    await widget.onApprove(_items.where((item) => item.approved).toList(growable: false));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved items added to inventory.')));
    context.go(AppRoutes.pantry);
  }

  void _mergeDuplicates() {
    final mergedByName = <String, ParsedIngredient>{};
    for (final item in _items) {
      final key = item.suggestedName.trim().toLowerCase();
      final existing = mergedByName[key];
      if (existing == null) {
        mergedByName[key] = item;
        continue;
      }

      mergedByName[key] = existing.copyWith(
        confidenceScore: existing.confidenceScore >= item.confidenceScore ? existing.confidenceScore : item.confidenceScore,
        parseConfidence: _higherConfidence(existing.parseConfidence, item.parseConfidence),
        approved: existing.approved || item.approved,
      );
    }

    setState(() => _items = mergedByName.values.toList(growable: false));
  }

  ParseConfidence _higherConfidence(ParseConfidence a, ParseConfidence b) {
    const rank = {
      ParseConfidence.unclear: 0,
      ParseConfidence.possible: 1,
      ParseConfidence.likely: 2,
    };
    return rank[a]! >= rank[b]! ? a : b;
  }
}

class _IngredientReviewCard extends StatelessWidget {
  const _IngredientReviewCard({
    required this.ingredient,
    required this.onChanged,
    required this.onRemoved,
  });

  final ParsedIngredient ingredient;
  final ValueChanged<ParsedIngredient> onChanged;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: ingredient.approved,
                  onChanged: (value) => onChanged(ingredient.copyWith(approved: value ?? false)),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: ingredient.suggestedName,
                    decoration: const InputDecoration(labelText: 'Ingredient name'),
                    onChanged: (value) => onChanged(ingredient.copyWith(suggestedName: value)),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ingredient',
                  onPressed: onRemoved,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ConfidencePill(confidence: ingredient.parseConfidence),
                const SizedBox(width: 8),
                Text('Score ${(ingredient.confidenceScore * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<IngredientCategory>(
              value: ingredient.category,
              items: IngredientCategory.values
                  .map((category) => DropdownMenuItem(value: category, child: Text(_categoryLabel(category))))
                  .toList(growable: false),
              onChanged: (value) => onChanged(ingredient.copyWith(category: value ?? ingredient.category)),
              decoration: const InputDecoration(labelText: 'Assign category'),
            ),
            const SizedBox(height: 8),
            Text('Detected text: ${ingredient.rawText}'),
            const SizedBox(height: 6),
            Text(ingredient.whyDetected),
          ],
        ),
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.confidence});

  final ParseConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      ParseConfidence.likely => ('Likely', Colors.green),
      ParseConfidence.possible => ('Possible', Colors.orange),
      ParseConfidence.unclear => ('Unclear', Colors.redAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

String _sourceLabel(CaptureCategory source) => switch (source) {
      CaptureCategory.pantry => 'Pantry',
      CaptureCategory.fridge => 'Fridge',
      CaptureCategory.freezer => 'Freezer',
      CaptureCategory.spiceRack => 'Spice Rack',
      CaptureCategory.groceryScreenshot => 'Grocery Screenshot',
    };

String _methodLabel(CaptureInputMethod method) => switch (method) {
      CaptureInputMethod.camera => 'Camera',
      CaptureInputMethod.photoLibrary => 'Photo Library',
      CaptureInputMethod.screenshotUpload => 'Screenshot Upload',
    };

String _categoryLabel(IngredientCategory category) => switch (category) {
      IngredientCategory.produce => 'Produce',
      IngredientCategory.dairy => 'Dairy',
      IngredientCategory.meatSeafood => 'Meat & Seafood',
      IngredientCategory.grainsBread => 'Grains & Bread',
      IngredientCategory.cannedJarred => 'Canned & Jarred',
      IngredientCategory.frozen => 'Frozen',
      IngredientCategory.baking => 'Baking',
      IngredientCategory.spicesSeasonings => 'Spices & Seasonings',
      IngredientCategory.oilsCondiments => 'Oils & Condiments',
      IngredientCategory.snacks => 'Snacks',
      IngredientCategory.beverages => 'Beverages',
      IngredientCategory.other => 'Other',
    };
