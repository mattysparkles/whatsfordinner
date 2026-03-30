import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/src/core/config/env_config.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';
import 'package:pantry_pilot/src/infrastructure/vision/openai/openai_vision_parsing_service.dart';

void main() {
  group('OpenAiVisionParsingService', () {
    test('maps schema output into parsed ingredients for multi-image session', () async {
      final imageA = await _tempImageFile('a.jpg');
      final imageB = await _tempImageFile('b.png');

      final service = OpenAiVisionParsingService(
        config: _config(),
        apiClient: _FakeOpenAiVisionApiClient(
          response: {
            'choices': [
              {
                'message': {
                  'content':
                      '{"ingredientCandidates":[{"sourceImageId":"img-a","rawTextOrCue":"milk carton","suggestedIngredientName":"Milk","confidenceScore":0.92,"confidenceClass":"likely","ingredientCategory":"dairy","quantity":1,"unit":"carton","whyDetected":"Label text includes milk."},{"sourceImageId":"img-b","rawTextOrCue":"green leaves bag","suggestedIngredientName":"Spinach","confidenceScore":0.61,"confidenceClass":"possible","ingredientCategory":"produce","quantity":null,"unit":null,"whyDetected":"Visual texture and color look like spinach."}]}'
                }
              }
            ]
          },
        ),
      );

      final session = await service.parseSession([
        CapturedImage(id: 'img-a', path: imageA.path, category: CaptureCategory.fridge),
        CapturedImage(id: 'img-b', path: imageB.path, category: CaptureCategory.fridge),
      ]);

      expect(session.images, hasLength(2));
      expect(session.imageErrors, isEmpty);
      expect(session.parsedIngredients, hasLength(2));

      final milk = session.parsedIngredients.first;
      expect(milk.sourceImageId, 'img-a');
      expect(milk.suggestedName, 'Milk');
      expect(milk.parseConfidence, ParseConfidence.likely);
      expect(milk.category, IngredientCategory.dairy);
      expect(milk.inferredQuantity, 1);
      expect(milk.inferredUnit, 'carton');
      expect(milk.approved, isFalse);
    });

    test('returns graceful error on schema mismatch', () async {
      final image = await _tempImageFile('a.jpg');
      final service = OpenAiVisionParsingService(
        config: _config(),
        apiClient: _FakeOpenAiVisionApiClient(
          response: {
            'choices': [
              {
                'message': {'content': '{"unexpected":[]}'},
              }
            ]
          },
        ),
      );

      final session = await service.parseSession([
        CapturedImage(id: 'img-a', path: image.path, category: CaptureCategory.pantry),
      ]);

      expect(session.parsedIngredients, isEmpty);
      expect(session.imageErrors.single, contains('unexpected format'));
    });

    test('returns auth/quota failure as recoverable image error', () async {
      final image = await _tempImageFile('a.jpg');
      final service = OpenAiVisionParsingService(
        config: _config(),
        apiClient: _FakeOpenAiVisionApiClient(
          error: const OpenAiVisionParseException(
            OpenAiVisionParseErrorType.authOrQuota,
            'status 429',
          ),
        ),
      );

      final session = await service.parseSession([
        CapturedImage(id: 'img-a', path: image.path, category: CaptureCategory.pantry),
      ]);

      expect(session.parsedIngredients, isEmpty);
      expect(session.imageErrors.single, contains('quota'));
    });
  });
}

EnvConfig _config() {
  return const EnvConfig(
    environment: AppEnvironment.dev,
    useMocks: false,
    recipeApiBaseUrl: 'https://example.com/recipes',
    visionApiBaseUrl: 'https://api.openai.com/v1',
    recipeApiKey: 'unused',
    visionApiKey: 'test-key',
    visionModel: 'gpt-4.1-mini',
    visionRequestTimeoutMs: 5000,
    visionMaxRetries: 0,
    visionLogEnabled: false,
  );
}

class _FakeOpenAiVisionApiClient implements OpenAiVisionApiClient {
  _FakeOpenAiVisionApiClient({this.response, this.error});

  final Map<String, dynamic>? response;
  final OpenAiVisionParseException? error;

  @override
  Future<Map<String, dynamic>> parseIngredients(OpenAiVisionParseRequest request) async {
    if (error != null) throw error!;
    return response ?? const {};
  }
}

Future<File> _tempImageFile(String name) async {
  final directory = await Directory.systemTemp.createTemp('vision_test_');
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(const [1, 2, 3, 4]);
  return file;
}
