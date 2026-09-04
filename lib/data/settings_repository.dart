import 'dart:convert';

import 'local_store.dart';
import 'models/app_settings.dart';

/// Reads and writes the settings document. See `docs/architecture.md`,
/// section "Files, not a database".
abstract interface class SettingsRepository {
  /// The current settings, or [AppSettings.empty] if none have been saved.
  Future<AppSettings> get();

  Future<void> save(AppSettings settings);
}

/// [SettingsRepository] backed by a [LocalStore]. Holds no in-memory
/// cache; every call reads the store fresh.
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._store);

  final LocalStore _store;

  static const _key = 'settings';

  @override
  Future<AppSettings> get() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) {
      return AppSettings.empty;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected a JSON object in the "settings" document.',
      );
    }
    return AppSettings.fromJson(decoded);
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _store.write(_key, jsonEncode(settings.toJson()));
  }
}
