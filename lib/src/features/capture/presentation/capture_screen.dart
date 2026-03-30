import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_routes.dart';
import '../../../app/providers.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/pantry_intelligence_service.dart';
import '../../../core/services/user_error_messaging_service.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../domain/models/models.dart';
import '../application/capture_import_service.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final List<CapturedImage> _images = [];
  CaptureCategory _selectedSource = CaptureCategory.pantry;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _importErrorMessage;
  bool _captureSessionTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImports());
  }

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
                onPressed: _isImporting ? null : () => _captureFromCamera(),
                icon: const Icon(Icons.photo_camera),
                label: Text(_isImporting ? 'Opening camera...' : 'Camera capture'),
              ),
              OutlinedButton.icon(
                onPressed: _isImporting ? null : () => _importFromPhotoLibrary(),
                icon: const Icon(Icons.photo_library),
                label: const Text('Photo library'),
              ),
              OutlinedButton.icon(
                onPressed: _isImporting ? null : () => _importScreenshot(),
                icon: const Icon(Icons.upload_file),
                label: const Text('Screenshot upload'),
              ),
            ],
          ),
          if (_importErrorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_importErrorMessage!)),
                  ],
                ),
              ),
            ),
          ],
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
                    const Text('No images added yet. Start with camera capture or photo library import.')
                  else
                    ..._images.map(
                      (image) => ListTile(
                        dense: true,
                        leading: _CaptureThumbnail(path: image.path),
                        title: Text(p.basename(image.path)),
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

  Future<void> _captureFromCamera() async {
    await _runImport(() async {
      final imported = await ref.read(captureImportServiceProvider).captureFromCamera(category: _selectedSource);
      setState(() => _images.addAll(imported));
      await _trackCaptureSessionCreated();
    });
  }

  Future<void> _importFromPhotoLibrary() async {
    await _runImport(() async {
      final imported = await ref.read(captureImportServiceProvider).importFromLibrary(
            category: _selectedSource,
            screenshotMode: false,
          );
      setState(() => _images.addAll(imported));
      await _trackCaptureSessionCreated();
    });
  }

  Future<void> _importScreenshot() async {
    await _runImport(() async {
      final imported = await ref.read(captureImportServiceProvider).importFromLibrary(
            category: CaptureCategory.groceryScreenshot,
            screenshotMode: true,
          );
      setState(() => _images.addAll(imported));
      await _trackCaptureSessionCreated();
    });
  }


  Future<void> _trackCaptureSessionCreated() async {
    if (_captureSessionTracked || _images.isEmpty) return;
    _captureSessionTracked = true;
    await ref.read(analyticsServiceProvider).logEvent(
      AppAnalyticsEvent.captureSessionCreated,
      parameters: {'source': _selectedSource.name, 'imageCount': _images.length},
    );
  }

  Future<void> _recoverLostImports() async {
    try {
      final recovered = await ref.read(captureImportServiceProvider).recoverLostImports();
      if (!mounted || recovered.isEmpty) return;
      setState(() => _images.addAll(recovered));
      ref.read(userErrorMessagingServiceProvider).show(
        context,
        message: UserMessage(
          title: 'Import recovered',
          details: 'Recovered ${recovered.length} image(s) from an interrupted import session.',
        ),
      );
    } on CaptureImportException catch (error) {
      if (!mounted) return;
      setState(() => _importErrorMessage = error.message);
    }
  }

  Future<void> _runImport(Future<void> Function() action) async {
    setState(() {
      _isImporting = true;
      _importErrorMessage = null;
    });

    try {
      await action();
    } on CaptureImportException catch (error) {
      setState(() => _importErrorMessage = error.message);
    } catch (error, stackTrace) {
      ref.read(crashReportingServiceProvider).recordError(
        error,
        stackTrace,
        reason: 'Capture import failed',
      );
      final mapped = ref.read(userErrorMessagingServiceProvider).map(error, fallbackTitle: 'Import failed');
      setState(() => _importErrorMessage = mapped.details);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _parseAndReview() async {
    setState(() => _isParsing = true);
    try {
      final parseSession = await ref.read(visionParsingServiceProvider).parseSession(_images);
      await ref.read(analyticsServiceProvider).logEvent(
        AppAnalyticsEvent.parseSessionCompleted,
        parameters: {
          'images': _images.length,
          'parsedIngredients': parseSession.parsedIngredients.length,
          'recoverableErrors': parseSession.imageErrors.length,
        },
      );
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
                  amount: ingredient.inferredQuantity,
                  unit: ingredient.inferredUnit,
                  sourceType: PantrySourceType.aiImport,
                  confidence: ingredient.confidenceScore,
                  provenanceType: ingredient.sourceImageId.isNotEmpty
                      ? PantryItemProvenanceType.captureSession
                      : PantryItemProvenanceType.screenshotImport,
                  provenanceSourceId: ingredient.sourceImageId,
                  mergeCompatibleAliases: true,
                );
              }
              await ref.read(analyticsServiceProvider).logEvent(
                AppAnalyticsEvent.pantryItemApproved,
                parameters: {'approvedCount': approvedIngredients.length},
              );
            },
          ),
        ),
      );
    } catch (error, stackTrace) {
      ref.read(crashReportingServiceProvider).recordError(error, stackTrace, reason: 'Parse session failed');
      if (!mounted) return;
      final message = ref.read(userErrorMessagingServiceProvider).map(error, fallbackTitle: 'Could not analyze images');
      ref.read(userErrorMessagingServiceProvider).show(context, message: message);
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }
}

class _CaptureThumbnail extends StatelessWidget {
  const _CaptureThumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 48,
        height: 48,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
            : const Icon(Icons.broken_image_outlined),
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
    const messenger = UserErrorMessagingService();
    messenger.show(
      context,
      message: const UserMessage(title: 'Inventory updated', details: 'Approved items added to inventory.'),
    );
    context.go(AppRoutes.pantry);
  }

  void _mergeDuplicates() {
    final intelligence = const PantryIntelligenceService();
    setState(() => _items = intelligence.mergeDuplicateDetections(_items));
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
