import 'dart:convert';

import 'local_store.dart';
import 'models/event_type.dart';

/// Reads and writes the card list. See `docs/architecture.md`, section
/// "Files, not a database".
abstract interface class EventTypeRepository {
  /// All cards, sorted by [EventType.createdAt] ascending, then by id.
  Future<List<EventType>> getAll();

  Future<EventType?> getById(String id);

  /// Adds [eventType], or replaces the existing card with the same id.
  Future<void> upsert(EventType eventType);

  /// Removes the card with [id]. A no-op if no card has that id.
  Future<void> delete(String id);
}

/// [EventTypeRepository] backed by a [LocalStore]. Holds no in-memory
/// cache; every call reads the store fresh.
class LocalEventTypeRepository implements EventTypeRepository {
  LocalEventTypeRepository(this._store);

  final LocalStore _store;

  static const _key = 'event_types';

  Future<List<EventType>> _readAll() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException(
        'Expected a JSON array in the "event_types" document.',
      );
    }
    return decoded
        .map((e) => EventType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<EventType> eventTypes) async {
    final encoded = jsonEncode(eventTypes.map((e) => e.toJson()).toList());
    await _store.write(_key, encoded);
  }

  @override
  Future<List<EventType>> getAll() async {
    final eventTypes = await _readAll();
    eventTypes.sort((a, b) {
      final byCreatedAt = a.createdAt.compareTo(b.createdAt);
      if (byCreatedAt != 0) return byCreatedAt;
      return a.id.compareTo(b.id);
    });
    return eventTypes;
  }

  @override
  Future<EventType?> getById(String id) async {
    final eventTypes = await _readAll();
    for (final eventType in eventTypes) {
      if (eventType.id == id) return eventType;
    }
    return null;
  }

  @override
  Future<void> upsert(EventType eventType) async {
    final eventTypes = await _readAll();
    final index = eventTypes.indexWhere((e) => e.id == eventType.id);
    if (index == -1) {
      eventTypes.add(eventType);
    } else {
      eventTypes[index] = eventType;
    }
    await _writeAll(eventTypes);
  }

  @override
  Future<void> delete(String id) async {
    final eventTypes = await _readAll();
    eventTypes.removeWhere((e) => e.id == id);
    await _writeAll(eventTypes);
  }
}
