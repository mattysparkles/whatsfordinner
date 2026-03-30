import '../models/app_models.dart';

abstract interface class PantryRepository {
  Future<List<PantryItem>> fetchAll();
  Future<void> saveAll(List<PantryItem> items);
}
