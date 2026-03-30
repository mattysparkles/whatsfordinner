abstract interface class LocalPersistenceService {
  Future<void> initialize();
  Future<void> writeString(String key, String value);
  Future<String?> readString(String key);
}
