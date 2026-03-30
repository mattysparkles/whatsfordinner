import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env_config.dart';
import '../../../core/services/vision_parsing_service.dart';
import '../../../domain/models/models.dart';

class OpenAiVisionParsingService implements VisionParsingService {
  OpenAiVisionParsingService({
    required EnvConfig config,
    Dio? dio,
    Uuid? uuid,
    VisionParsingLogHook? logHook,
    OpenAiVisionApiClient? apiClient,
    DateTime Function()? now,
  })  : _config = config,
        _uuid = uuid ?? const Uuid(),
        _logHook = logHook ?? (config.visionLogEnabled ? const PrintVisionParsingLogHook() : const NoopVisionParsingLogHook()),
        _apiClient = apiClient ?? DioOpenAiVisionApiClient(config: config, dio: dio),
        _now = now ?? DateTime.now;

  final EnvConfig _config;
  final Uuid _uuid;
  final VisionParsingLogHook _logHook;
  final OpenAiVisionApiClient _apiClient;
  final DateTime Function() _now;

  @override
  Future<ParseSession> parseSession(List<CapturedImage> images) async {
    final parsedIngredients = <ParsedIngredient>[];
    final imageErrors = <String>[];

    if (images.isEmpty) {
      return ParseSession(
        id: _uuid.v4(),
        images: images,
        parsedIngredients: parsedIngredients,
        imageErrors: imageErrors,
        createdAt: _now(),
      );
    }

    if (_config.visionApiKey.trim().isEmpty) {
      imageErrors.add('Vision parsing is not configured. Missing VISION_API_KEY.');
      return ParseSession(
        id: _uuid.v4(),
        images: images,
        parsedIngredients: parsedIngredients,
        imageErrors: imageErrors,
        createdAt: _now(),
      );
    }

    final eligibleImages = <CapturedImage>[];
    for (final image in images) {
      final localError = _validateImage(image);
      if (localError != null) {
        imageErrors.add(localError);
      } else {
        eligibleImages.add(image);
      }
    }

    if (eligibleImages.isEmpty) {
      return ParseSession(
        id: _uuid.v4(),
        images: images,
        parsedIngredients: parsedIngredients,
        imageErrors: imageErrors,
        createdAt: _now(),
      );
    }

    final imagePayloads = <OpenAiVisionImagePayload>[];
    for (final image in eligibleImages) {
      final bytes = await File(image.path).readAsBytes();
      imagePayloads.add(
        OpenAiVisionImagePayload(
          imageId: image.id,
          category: image.category,
          mimeType: _mimeTypeFromPath(image.path),
          base64Data: base64Encode(bytes),
        ),
      );
    }

    final request = OpenAiVisionParseRequest(model: _config.visionModel, images: imagePayloads);
    _logHook.onRequest(
      OpenAiVisionLogEvent(
        message: 'Sending vision parse request.',
        payload: {
          'baseUrl': _config.visionApiBaseUrl,
          'model': _config.visionModel,
          'imageCount': imagePayloads.length,
          'timeoutMs': _config.visionRequestTimeoutMs,
          'maxRetries': _config.visionMaxRetries,
          'apiKey': _redactSecret(_config.visionApiKey),
        },
      ),
    );

    try {
      final response = await _apiClient.parseIngredients(request);
      _logHook.onResponse(OpenAiVisionLogEvent(message: 'Received vision parse response.', payload: {'keys': response.keys.toList()}));
      final mapped = _mapResponse(response);
      parsedIngredients.addAll(mapped);
    } on OpenAiVisionParseException catch (error) {
      imageErrors.add(error.userMessage);
      _logHook.onError(
        OpenAiVisionLogEvent(
          message: 'Vision parse failed with typed exception.',
          payload: {'type': error.type.name, 'details': error.details},
        ),
      );
    } catch (error) {
      imageErrors.add('Unable to parse images right now. Please try again.');
      _logHook.onError(OpenAiVisionLogEvent(message: 'Vision parse failed with unknown error.', payload: {'error': '$error'}));
    }

    return ParseSession(
      id: _uuid.v4(),
      images: images,
      parsedIngredients: parsedIngredients,
      imageErrors: imageErrors,
      createdAt: _now(),
    );
  }

  String? _validateImage(CapturedImage image) {
    if (image.errorMessage != null && image.errorMessage!.trim().isNotEmpty) {
      return image.errorMessage;
    }

    final file = File(image.path);
    if (!file.existsSync()) {
      return 'Image ${image.id} is missing from device storage.';
    }

    return null;
  }

  List<ParsedIngredient> _mapResponse(Map<String, dynamic> apiResponse) {
    final contentJson = _extractStructuredContentJson(apiResponse);
    final decoded = jsonDecode(contentJson);
    if (decoded is! Map<String, dynamic>) {
      throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.schemaMismatch, 'Structured output was not an object.');
    }

    final candidates = decoded['ingredientCandidates'];
    if (candidates is! List) {
      throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.schemaMismatch, 'Missing ingredientCandidates in structured output.');
    }

    return candidates.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.schemaMismatch, 'Ingredient candidate had invalid shape.');
      }

      final score = (item['confidenceScore'] as num?)?.toDouble();
      final scoreNormalized = score == null ? 0.0 : score.clamp(0.0, 1.0).toDouble();
      final confidenceClassRaw = (item['confidenceClass'] as String?)?.trim();
      final parseConfidence = _confidenceFromClass(confidenceClassRaw, scoreNormalized);

      return ParsedIngredient(
        id: _uuid.v4(),
        rawText: (item['rawTextOrCue'] as String?)?.trim().isNotEmpty == true
            ? (item['rawTextOrCue'] as String).trim()
            : 'visual cue',
        suggestedName: (item['suggestedIngredientName'] as String?)?.trim().isNotEmpty == true
            ? (item['suggestedIngredientName'] as String).trim()
            : 'Unknown ingredient',
        confidenceScore: scoreNormalized,
        parseConfidence: parseConfidence,
        sourceImageId: (item['sourceImageId'] as String?)?.trim().isNotEmpty == true
            ? (item['sourceImageId'] as String).trim()
            : 'unknown-image',
        category: _categoryFromString(item['ingredientCategory'] as String?),
        inferredQuantity: (item['quantity'] as num?)?.toDouble(),
        inferredUnit: (item['unit'] as String?)?.trim(),
        whyDetected: (item['whyDetected'] as String?)?.trim().isNotEmpty == true
            ? (item['whyDetected'] as String).trim()
            : 'Detected via visual cues and text recognition.',
        approved: false,
      );
    }).toList(growable: false);
  }

  String _extractStructuredContentJson(Map<String, dynamic> apiResponse) {
    final choices = apiResponse['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.badResponse, 'Missing choices in API response.');
    }

    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.badResponse, 'First choice had invalid type.');
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.badResponse, 'Missing message in first choice.');
    }

    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }

    throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.badResponse, 'No JSON content found in model response.');
  }

  ParseConfidence _confidenceFromClass(String? rawClass, double score) {
    final normalized = (rawClass ?? '').toLowerCase();
    if (normalized == 'likely') return ParseConfidence.likely;
    if (normalized == 'possible') return ParseConfidence.possible;
    if (normalized == 'unclear') return ParseConfidence.unclear;

    if (score >= 0.8) return ParseConfidence.likely;
    if (score >= 0.55) return ParseConfidence.possible;
    return ParseConfidence.unclear;
  }

  IngredientCategory _categoryFromString(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return IngredientCategory.values.firstWhere(
      (value) => value.name.toLowerCase() == normalized,
      orElse: () => IngredientCategory.other,
    );
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  String _redactSecret(String value) {
    if (value.length <= 8) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 2)}';
  }
}

class OpenAiVisionParseRequest {
  const OpenAiVisionParseRequest({required this.model, required this.images});

  final String model;
  final List<OpenAiVisionImagePayload> images;
}

class OpenAiVisionImagePayload {
  const OpenAiVisionImagePayload({
    required this.imageId,
    required this.category,
    required this.mimeType,
    required this.base64Data,
  });

  final String imageId;
  final CaptureCategory category;
  final String mimeType;
  final String base64Data;
}

abstract interface class OpenAiVisionApiClient {
  Future<Map<String, dynamic>> parseIngredients(OpenAiVisionParseRequest request);
}

class DioOpenAiVisionApiClient implements OpenAiVisionApiClient {
  DioOpenAiVisionApiClient({required EnvConfig config, Dio? dio})
      : _config = config,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.visionApiBaseUrl,
                connectTimeout: Duration(milliseconds: config.visionRequestTimeoutMs),
                receiveTimeout: Duration(milliseconds: config.visionRequestTimeoutMs),
                sendTimeout: Duration(milliseconds: config.visionRequestTimeoutMs),
              ),
            );

  final EnvConfig _config;
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> parseIngredients(OpenAiVisionParseRequest request) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/chat/completions',
          options: Options(headers: {'Authorization': 'Bearer ${_config.visionApiKey}'}),
          data: _buildPayload(request),
        );

        final data = response.data;
        if (data == null) {
          throw const OpenAiVisionParseException(OpenAiVisionParseErrorType.badResponse, 'Vision API returned an empty body.');
        }
        return data;
      } on DioException catch (error) {
        if (_isRetryable(error) && attempt <= _config.visionMaxRetries) {
          await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
          continue;
        }
        throw _mapDioException(error);
      }
    }
  }

  Map<String, dynamic> _buildPayload(OpenAiVisionParseRequest request) {
    final imageInstructions = request.images
        .map(
          (image) => {
            'imageId': image.imageId,
            'captureCategory': image.category.name,
          },
        )
        .toList(growable: false);

    final userContent = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text': '''
Extract ingredient candidates across all provided images.
Treat each image independently and preserve imageId.
Return strict JSON matching the schema.
Image metadata:
${jsonEncode(imageInstructions)}
''',
      },
      ...request.images.map(
        (image) => {
          'type': 'image_url',
          'image_url': {'url': 'data:${image.mimeType};base64,${image.base64Data}'},
        },
      ),
    ];

    return {
      'model': request.model,
      'temperature': 0,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a pantry ingredient detection system. Only output JSON that matches the schema. Be conservative; do not invent ingredients.',
        },
        {'role': 'user', 'content': userContent},
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'ingredient_extraction',
          'strict': true,
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'ingredientCandidates': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'sourceImageId': {'type': 'string'},
                    'rawTextOrCue': {'type': 'string'},
                    'suggestedIngredientName': {'type': 'string'},
                    'confidenceScore': {'type': 'number', 'minimum': 0, 'maximum': 1},
                    'confidenceClass': {
                      'type': 'string',
                      'enum': ['likely', 'possible', 'unclear'],
                    },
                    'ingredientCategory': {'type': 'string'},
                    'quantity': {'type': ['number', 'null']},
                    'unit': {'type': ['string', 'null']},
                    'whyDetected': {'type': 'string'},
                  },
                  'required': [
                    'sourceImageId',
                    'rawTextOrCue',
                    'suggestedIngredientName',
                    'confidenceScore',
                    'confidenceClass',
                    'ingredientCategory',
                    'quantity',
                    'unit',
                    'whyDetected',
                  ],
                },
              },
            },
            'required': ['ingredientCandidates'],
          },
        },
      },
    };
  }

  bool _isRetryable(DioException error) {
    final status = error.response?.statusCode ?? 0;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        status == 408 ||
        status >= 500;
  }

  OpenAiVisionParseException _mapDioException(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status == 401 || status == 403 || status == 429) {
      return OpenAiVisionParseException(
        OpenAiVisionParseErrorType.authOrQuota,
        'Vision API rejected the request (status $status).',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const OpenAiVisionParseException(
        OpenAiVisionParseErrorType.timeout,
        'Vision parsing timed out. Please try again.',
      );
    }

    return OpenAiVisionParseException(
      OpenAiVisionParseErrorType.badResponse,
      'Vision API request failed: ${error.message}',
    );
  }
}

enum OpenAiVisionParseErrorType { badResponse, schemaMismatch, timeout, authOrQuota }

class OpenAiVisionParseException implements Exception {
  const OpenAiVisionParseException(this.type, this.details);

  final OpenAiVisionParseErrorType type;
  final String details;

  String get userMessage {
    switch (type) {
      case OpenAiVisionParseErrorType.authOrQuota:
        return 'Vision service authentication or quota error. Check API credentials/billing.';
      case OpenAiVisionParseErrorType.timeout:
        return 'Vision parsing timed out. Try with fewer or clearer images.';
      case OpenAiVisionParseErrorType.schemaMismatch:
        return 'Vision service returned an unexpected format. Please retry.';
      case OpenAiVisionParseErrorType.badResponse:
        return 'Vision service returned an invalid response. Please retry.';
    }
  }
}

class OpenAiVisionLogEvent {
  const OpenAiVisionLogEvent({required this.message, required this.payload});

  final String message;
  final Map<String, dynamic> payload;
}

abstract interface class VisionParsingLogHook {
  void onRequest(OpenAiVisionLogEvent event);

  void onResponse(OpenAiVisionLogEvent event);

  void onError(OpenAiVisionLogEvent event);
}

class NoopVisionParsingLogHook implements VisionParsingLogHook {
  const NoopVisionParsingLogHook();

  @override
  void onError(OpenAiVisionLogEvent event) {}

  @override
  void onRequest(OpenAiVisionLogEvent event) {}

  @override
  void onResponse(OpenAiVisionLogEvent event) {}
}

class PrintVisionParsingLogHook implements VisionParsingLogHook {
  const PrintVisionParsingLogHook();

  @override
  void onError(OpenAiVisionLogEvent event) {
    // ignore: avoid_print
    print('[VisionParse][ERROR] ${event.message} payload=${jsonEncode(event.payload)}');
  }

  @override
  void onRequest(OpenAiVisionLogEvent event) {
    // ignore: avoid_print
    print('[VisionParse][REQUEST] ${event.message} payload=${jsonEncode(event.payload)}');
  }

  @override
  void onResponse(OpenAiVisionLogEvent event) {
    // ignore: avoid_print
    print('[VisionParse][RESPONSE] ${event.message} payload=${jsonEncode(event.payload)}');
  }
}
