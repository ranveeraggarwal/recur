/// A key -> JSON document store. Documents are whole JSON strings.
abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String json);
  Future<void> delete(String key);
}

/// In-memory implementation of LocalStore for testing.
class InMemoryLocalStore implements LocalStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> write(String key, String json) async {
    _store[key] = json;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  /// Returns an unmodifiable copy of the current store for testing.
  Map<String, String> get snapshot => Map.unmodifiable(_store);
}
