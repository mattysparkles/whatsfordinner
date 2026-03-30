import 'package:dio/dio.dart';

class PantryGatewayException implements Exception {
  const PantryGatewayException(this.userMessage);

  final String userMessage;
}

class PantryGatewayClient {
  PantryGatewayClient({required String baseUrl, Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 30)));

  final Dio _dio;

  Future<Map<String, dynamic>> postJson({required String path, required Map<String, dynamic> payload}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: payload);
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map<String, dynamic>) {
        final message = body['userMessage'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          throw PantryGatewayException(message.trim());
        }
      }
      throw const PantryGatewayException('Service is temporarily unavailable. Please try again.');
    }
  }
}
