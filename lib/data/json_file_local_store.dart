import 'dart:io';

import 'local_store.dart';

/// File-backed implementation of LocalStore using JSON files.
/// One file per key under [root]/`<key>.json`.
/// Writes go to `<key>.json.tmp` then rename, so a crash never leaves a half file.
class JsonFileLocalStore implements LocalStore {
  final Directory root;

  JsonFileLocalStore(this.root);

  /// Validates that a key matches the required pattern.
  /// Keys must match ^[a-z_]+$
  void _validateKey(String key) {
    if (!RegExp(r'^[a-z_]+$').hasMatch(key)) {
      throw ArgumentError('Invalid key: $key. Keys must match ^[a-z_]+\$');
    }
  }

  File _fileForKey(String key) {
    return File('${root.path}/$key.json');
  }

  File _tmpFileForKey(String key) {
    return File('${root.path}/$key.json.tmp');
  }

  @override
  Future<String?> read(String key) async {
    _validateKey(key);
    final file = _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String json) async {
    _validateKey(key);

    // Create root directory recursively if needed
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    // Write to temporary file
    final tmpFile = _tmpFileForKey(key);
    await tmpFile.writeAsString(json);

    // Rename temporary file to actual file (atomic)
    final file = _fileForKey(key);
    await tmpFile.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    _validateKey(key);
    final file = _fileForKey(key);
    try {
      await file.delete();
    } on FileSystemException {
      // Ignore if file doesn't exist
    }
  }
}
