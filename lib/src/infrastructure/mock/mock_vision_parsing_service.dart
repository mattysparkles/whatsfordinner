import 'package:uuid/uuid.dart';

import '../../core/services/vision_parsing_service.dart';
import '../../domain/models/models.dart';

class MockVisionParsingService implements VisionParsingService {
  MockVisionParsingService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  Future<ParseSession> parseSession(List<CapturedImage> images) async {
    final parsedIngredients = <ParsedIngredient>[];
    final imageErrors = <String>[];

    for (final image in images) {
      final lowerPath = image.path.toLowerCase();
      if (lowerPath.contains('blurry')) {
        imageErrors.add('Image "${image.path}" appears blurry. Please retake in better light.');
        continue;
      }
      if (lowerPath.contains('empty')) {
        imageErrors.add('Image "${image.path}" did not include readable ingredients.');
        continue;
      }

      parsedIngredients.addAll(_fakeItemsForCategory(image));
    }

    return ParseSession(
      id: _uuid.v4(),
      images: images,
      parsedIngredients: parsedIngredients,
      imageErrors: imageErrors,
      createdAt: DateTime.now(),
    );
  }

  List<ParsedIngredient> _fakeItemsForCategory(CapturedImage image) {
    switch (image.category) {
      case CaptureCategory.pantry:
        return [
          _ingredient(image.id, 'black beans can', 'Black beans', 0.92, ParseConfidence.likely, IngredientCategory.cannedJarred),
          _ingredient(image.id, 'pasta box', 'Pasta', 0.88, ParseConfidence.likely, IngredientCategory.grainsBread),
          _ingredient(image.id, 'olive oil bottle', 'Olive oil', 0.77, ParseConfidence.possible, IngredientCategory.oilsCondiments),
        ];
      case CaptureCategory.fridge:
        return [
          _ingredient(image.id, 'milk carton', 'Milk', 0.93, ParseConfidence.likely, IngredientCategory.dairy),
          _ingredient(image.id, 'baby spinach tub', 'Spinach', 0.71, ParseConfidence.possible, IngredientCategory.produce),
          _ingredient(image.id, 'leftover container', 'Cooked rice', 0.54, ParseConfidence.unclear, IngredientCategory.grainsBread),
        ];
      case CaptureCategory.freezer:
        return [
          _ingredient(image.id, 'frozen peas bag', 'Frozen peas', 0.91, ParseConfidence.likely, IngredientCategory.frozen),
          _ingredient(image.id, 'ice cream carton', 'Vanilla ice cream', 0.82, ParseConfidence.possible, IngredientCategory.frozen),
        ];
      case CaptureCategory.spiceRack:
        return [
          _ingredient(image.id, 'cumin jar', 'Ground cumin', 0.84, ParseConfidence.likely, IngredientCategory.spicesSeasonings),
          _ingredient(image.id, 'paprika label', 'Paprika', 0.79, ParseConfidence.possible, IngredientCategory.spicesSeasonings),
          _ingredient(image.id, 'pepper grinder', 'Black pepper', 0.67, ParseConfidence.possible, IngredientCategory.spicesSeasonings),
        ];
      case CaptureCategory.groceryScreenshot:
        return [
          _ingredient(image.id, 'eggs 12ct', 'Eggs', 0.94, ParseConfidence.likely, IngredientCategory.dairy),
          _ingredient(image.id, 'bananas', 'Bananas', 0.9, ParseConfidence.likely, IngredientCategory.produce),
          _ingredient(image.id, 'pasta box', 'Pasta', 0.83, ParseConfidence.possible, IngredientCategory.grainsBread),
        ];
    }
  }

  ParsedIngredient _ingredient(
    String sourceImageId,
    String rawText,
    String suggestedName,
    double confidence,
    ParseConfidence parseConfidence,
    IngredientCategory category,
  ) {
    return ParsedIngredient(
      id: _uuid.v4(),
      rawText: rawText,
      suggestedName: suggestedName,
      confidenceScore: confidence,
      parseConfidence: parseConfidence,
      sourceImageId: sourceImageId,
      category: category,
      whyDetected: 'Why we think this is here: placeholder explanation from mock OCR tokens and label matching.',
    );
  }
}
