import '../models/app_models.dart';

abstract interface class VisionService {
  Future<List<ParsedIngredient>> parseCapturedSources(List<String> sourcePaths);
}
