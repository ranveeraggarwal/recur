import 'dart:io';

import 'local_store.dart';

/// File-backed implementation of LocalStore using JSON files.
/// One file per key under [root]/`<key>.json`.
/// Writes go to `<key>.json.tmp`, flushed to disk, then renamed, so a crash
/// never leaves a half file.
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

    // Delete a stale temp file left behind by a previous crash, if any.
    // Not required for correctness (rename overwrites it anyway on
    // Linux/Android), but avoids relying on that.
    final tmpFile = _tmpFileForKey(key);
    if (await tmpFile.exists()) {
      await tmpFile.delete();
    }

    // Write to temporary file, flushing to disk before returning so the
    // rename below can never make an unflushed (half-written or empty)
    // file durable. Without flush: true, writeAsString may return once the
    // bytes are only in the OS buffer, so a crash between the write and the
    // rename could leave the renamed file empty or truncated.
    await tmpFile.writeAsString(json, flush: true);

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
