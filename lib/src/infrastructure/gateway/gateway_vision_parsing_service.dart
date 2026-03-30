import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/services/vision_parsing_service.dart';
import '../../domain/models/models.dart';
import 'pantry_gateway_client.dart';

class GatewayVisionParsingService implements VisionParsingService {
  GatewayVisionParsingService({required PantryGatewayClient client, Uuid? uuid, DateTime Function()? now})
      : _client = client,
        _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  final PantryGatewayClient _client;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<ParseSession> parseSession(List<CapturedImage> images) async {
    final errors = <String>[];
    if (images.isEmpty) {
      return ParseSession(id: _uuid.v4(), images: images, parsedIngredients: const [], imageErrors: const [], createdAt: _now());
    }

    final encodedImages = <Map<String, dynamic>>[];
    for (final image in images) {
      if (image.errorMessage != null && image.errorMessage!.trim().isNotEmpty) {
        errors.add(image.errorMessage!.trim());
        continue;
      }
      final file = File(image.path);
      if (!file.existsSync()) {
        errors.add('Image ${image.id} is missing from device storage.');
        continue;
      }

      encodedImages.add({
        'imageId': image.id,
        'category': _category(image.category),
        'mimeType': _mimeTypeFromPath(image.path),
        'base64Data': base64Encode(await file.readAsBytes()),
      });
    }

    final ingredients = <ParsedIngredient>[];
    if (encodedImages.isNotEmpty) {
      try {
        final response = await _client.postJson(path: '/vision/parse', payload: {'images': encodedImages});
        final candidates = (response['ingredientCandidates'] as List?) ?? const [];
        for (final candidate in candidates.whereType<Map<String, dynamic>>()) {
          ingredients.add(_mapCandidate(candidate));
        }
      } on PantryGatewayException catch (error) {
        errors.add(error.userMessage);
      }
    }

    return ParseSession(
      id: _uuid.v4(),
      images: images,
      parsedIngredients: ingredients,
      imageErrors: errors,
      createdAt: _now(),
    );
  }

  ParsedIngredient _mapCandidate(Map<String, dynamic> item) {
    final score = (item['confidenceScore'] as num?)?.toDouble() ?? 0;
    return ParsedIngredient(
      id: _uuid.v4(),
      rawText: (item['rawTextOrCue'] as String?)?.trim().isNotEmpty == true ? (item['rawTextOrCue'] as String).trim() : 'visual cue',
      suggestedName: (item['suggestedIngredientName'] as String?)?.trim().isNotEmpty == true
          ? (item['suggestedIngredientName'] as String).trim()
          : 'Unknown ingredient',
      confidenceScore: score.clamp(0, 1).toDouble(),
      parseConfidence: _confidence(item['confidenceClass'] as String?, score),
      sourceImageId: (item['sourceImageId'] as String?) ?? 'unknown-image',
      category: _ingredientCategory(item['ingredientCategory'] as String?),
      inferredQuantity: (item['quantity'] as num?)?.toDouble(),
      inferredUnit: (item['unit'] as String?)?.trim(),
      whyDetected: (item['whyDetected'] as String?)?.trim() ?? 'Detected via visual cues and text recognition.',
      approved: false,
    );
  }

  ParseConfidence _confidence(String? raw, double score) {
    final normalized = (raw ?? '').toLowerCase();
    if (normalized == 'likely') return ParseConfidence.likely;
    if (normalized == 'possible') return ParseConfidence.possible;
    if (score >= 0.8) return ParseConfidence.likely;
    if (score >= 0.55) return ParseConfidence.possible;
    return ParseConfidence.unclear;
  }

  IngredientCategory _ingredientCategory(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return IngredientCategory.values.firstWhere((value) => value.name.toLowerCase() == normalized, orElse: () => IngredientCategory.other);
  }

  String _category(CaptureCategory category) {
    switch (category) {
      case CaptureCategory.fridge:
        return 'fridge';
      case CaptureCategory.pantry:
        return 'pantry';
      default:
        return 'other';
    }
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
