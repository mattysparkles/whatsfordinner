import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pilot/src/domain/models/models.dart';
import 'package:pantry_pilot/src/infrastructure/gateway/gateway_vision_parsing_service.dart';
import 'package:pantry_pilot/src/infrastructure/gateway/pantry_gateway_client.dart';

void main() {
  test('maps backend vision candidates into parsed ingredients', () async {
    final image = await _tempImageFile('a.jpg');
    final service = GatewayVisionParsingService(
      client: _FakeGatewayClient(
        payload: {
          'ingredientCandidates': [
            {
              'sourceImageId': 'img-a',
              'rawTextOrCue': 'milk carton',
              'suggestedIngredientName': 'Milk',
              'confidenceScore': 0.9,
              'confidenceClass': 'likely',
              'ingredientCategory': 'dairy',
              'quantity': 1,
              'unit': 'carton',
              'whyDetected': 'Label text includes milk.',
            }
          ]
        },
      ),
    );

    final session = await service.parseSession([
      CapturedImage(id: 'img-a', path: image.path, category: CaptureCategory.fridge),
    ]);

    expect(session.imageErrors, isEmpty);
    expect(session.parsedIngredients.single.suggestedName, 'Milk');
  });

  test('returns user-safe errors when backend fails', () async {
    final image = await _tempImageFile('a.jpg');
    final service = GatewayVisionParsingService(client: _FakeGatewayClient(error: const PantryGatewayException('Try again soon.')));

    final session = await service.parseSession([
      CapturedImage(id: 'img-a', path: image.path, category: CaptureCategory.pantry),
    ]);

    expect(session.parsedIngredients, isEmpty);
    expect(session.imageErrors.single, 'Try again soon.');
  });
}

class _FakeGatewayClient extends PantryGatewayClient {
  _FakeGatewayClient({this.payload, this.error}) : super(baseUrl: 'https://example.com');

  final Map<String, dynamic>? payload;
  final PantryGatewayException? error;

  @override
  Future<Map<String, dynamic>> postJson({required String path, required Map<String, dynamic> payload}) async {
    if (error != null) throw error!;
    return this.payload ?? const {};
  }
}

Future<File> _tempImageFile(String name) async {
  final directory = await Directory.systemTemp.createTemp('vision_gateway_test_');
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(const [1, 2, 3, 4]);
  return file;
}
