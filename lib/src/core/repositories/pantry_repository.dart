import '../../domain/models/models.dart';

abstract interface class PantryRepository {
  Future<List<PantryItem>> fetchAll();
  Future<void> upsert(PantryItem item);
  Future<void> deleteById(String id);
  Future<void> saveAll(List<PantryItem> items);
  Future<String> exportToJson();
  Future<void> importFromJson(String json);
}
