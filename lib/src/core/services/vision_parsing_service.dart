import '../../domain/models/models.dart';

abstract interface class VisionParsingService {
  Future<ParseSession> parseSession(List<CapturedImage> images);
}
