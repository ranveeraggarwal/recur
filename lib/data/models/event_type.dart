/// A card: something the user books repeatedly, with a name, a duration,
/// and the weekdays and times of day they usually want it at.
library;

/// Sentinel used by [EventType.copyWith] to tell "leave [location]/[notes]
/// unset" apart from "set it to null".
const Object _unset = Object();

/// A booking card. See `docs/architecture.md`, section "The data".
final class EventType {
  /// Creates an [EventType]. The invariants below are programmer errors,
  /// not user input mistakes — the Editor screen validates raw input with
  /// [validateName], [validateDuration] and [validateWindow] first, and
  /// only builds an [EventType] once those pass.
  const EventType({
    required this.id,
    required this.name,
    required this.durationMinutes,
    this.location,
    this.notes,
    required this.preferredWeekdays,
    required this.preferredStartMinutes,
    required this.preferredEndMinutes,
    required this.createdAt,
  }) : assert(
         name.length > 0 && name.length <= 40,
         'name must be 1..40 trimmed characters',
       ),
       assert(
         durationMinutes >= 5 &&
             durationMinutes <= 480 &&
             durationMinutes % 5 == 0,
         'durationMinutes must be 5..480 and a multiple of 5',
       ),
       assert(
         location == null || (location.length > 0 && location.length <= 80),
         'location must be null or 1..80 trimmed characters',
       ),
       assert(
         notes == null || (notes.length > 0 && notes.length <= 500),
         'notes must be null or 1..500 trimmed characters',
       ),
       assert(
         preferredWeekdays.length > 0,
         'preferredWeekdays must be non-empty',
       ),
       assert(
         preferredStartMinutes >= 360 &&
             preferredStartMinutes <= 1320 &&
             preferredStartMinutes % 30 == 0,
         'preferredStartMinutes must be 360..1320 and a multiple of 30',
       ),
       assert(
         preferredEndMinutes > preferredStartMinutes + durationMinutes - 1 &&
             preferredEndMinutes <= 1320,
         'preferredEndMinutes must be > preferredStartMinutes + '
         'durationMinutes - 1 and <= 1320',
       );

  final String id;

  /// 1..40 chars, trimmed.
  final String name;

  /// 5..480, multiple of 5.
  final int durationMinutes;

  /// Trimmed, null when empty, <= 80 chars.
  final String? location;

  /// Trimmed, null when empty, <= 500 chars.
  final String? notes;

  /// Subset of {1..7} (1 = Monday .. 7 = Sunday), non-empty.
  final Set<int> preferredWeekdays;

  /// 360..1320, multiple of 30.
  final int preferredStartMinutes;

  /// > [preferredStartMinutes] + [durationMinutes] - 1, <= 1320.
  final int preferredEndMinutes;

  final DateTime createdAt;

  /// Returns `Name is required.` for a blank name, or a message when it is
  /// too long, or `null` when [name] is valid. Trims before checking.
  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name is required.';
    if (trimmed.length > 40) return 'Name must be 40 characters or less.';
    return null;
  }

  /// Returns a message when [minutes] is out of range or not a multiple of
  /// 5, or `null` when it is valid.
  static String? validateDuration(int minutes) {
    if (minutes < 5 || minutes > 480) {
      return 'Duration must be between 5 and 480 minutes.';
    }
    if (minutes % 5 != 0) {
      return 'Duration must be a multiple of 5 minutes.';
    }
    return null;
  }

  /// Returns a message when the preferred window is invalid, or `null`
  /// when it is valid. `End must be after start plus the duration.` is
  /// returned when [end] does not leave room for [duration] after [start].
  static String? validateWindow({
    required int start,
    required int end,
    required int duration,
  }) {
    if (start < 360 || start > 1320) {
      return 'Start must be between 06:00 and 22:00.';
    }
    if (start % 30 != 0) {
      return 'Start must be on a 30 minute mark.';
    }
    if (end < start + duration) {
      return 'End must be after start plus the duration.';
    }
    if (end > 1320) {
      return 'End must be by 22:00.';
    }
    return null;
  }

  EventType copyWith({
    String? id,
    String? name,
    int? durationMinutes,
    Object? location = _unset,
    Object? notes = _unset,
    Set<int>? preferredWeekdays,
    int? preferredStartMinutes,
    int? preferredEndMinutes,
    DateTime? createdAt,
  }) {
    return EventType(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      preferredWeekdays: preferredWeekdays ?? this.preferredWeekdays,
      preferredStartMinutes:
          preferredStartMinutes ?? this.preferredStartMinutes,
      preferredEndMinutes: preferredEndMinutes ?? this.preferredEndMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationMinutes': durationMinutes,
      'location': location,
      'notes': notes,
      'preferredWeekdays': (preferredWeekdays.toList()..sort()),
      'preferredStartMinutes': preferredStartMinutes,
      'preferredEndMinutes': preferredEndMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EventType.fromJson(Map<String, dynamic> json) {
    final weekdaysRaw = _require<List<dynamic>>(
      json,
      'preferredWeekdays',
      'EventType',
    );
    return EventType(
      id: _require<String>(json, 'id', 'EventType'),
      name: _require<String>(json, 'name', 'EventType'),
      durationMinutes: _require<int>(json, 'durationMinutes', 'EventType'),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      preferredWeekdays: weekdaysRaw.map((e) => e as int).toSet(),
      preferredStartMinutes: _require<int>(
        json,
        'preferredStartMinutes',
        'EventType',
      ),
      preferredEndMinutes: _require<int>(
        json,
        'preferredEndMinutes',
        'EventType',
      ),
      createdAt: DateTime.parse(
        _require<String>(json, 'createdAt', 'EventType'),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventType &&
      other.id == id &&
      other.name == name &&
      other.durationMinutes == durationMinutes &&
      other.location == location &&
      other.notes == notes &&
      _setEquals(other.preferredWeekdays, preferredWeekdays) &&
      other.preferredStartMinutes == preferredStartMinutes &&
      other.preferredEndMinutes == preferredEndMinutes &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    durationMinutes,
    location,
    notes,
    Object.hashAllUnordered(preferredWeekdays),
    preferredStartMinutes,
    preferredEndMinutes,
    createdAt,
  );

  @override
  String toString() =>
      'EventType(id: $id, name: $name, durationMinutes: $durationMinutes)';
}

bool _setEquals(Set<int> a, Set<int> b) {
  if (a.length != b.length) return false;
  for (final value in a) {
    if (!b.contains(value)) return false;
  }
  return true;
}

/// Reads [key] from [json] as a [T], throwing a [FormatException] (naming
/// [typeName] and [key]) when the key is missing, null, or the wrong type —
/// never a raw cast error.
T _require<T>(Map<String, dynamic> json, String key, String typeName) {
  if (!json.containsKey(key) || json[key] == null) {
    throw FormatException('Missing required key "$key" in $typeName JSON.');
  }
  final value = json[key];
  if (value is! T) {
    throw FormatException('Key "$key" in $typeName JSON has the wrong type.');
  }
  return value;
}
