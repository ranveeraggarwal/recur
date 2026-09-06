/// A card: something the user books repeatedly, with a name, a duration,
/// and the weekdays and times of day they usually want it at.
library;

import 'package:flutter/foundation.dart';

import '../../core/time_of_day_minutes.dart';
import '../../core/time_window.dart';
import 'json_helpers.dart';

/// Sentinel used by [EventType.copyWith] to tell "leave [location]/[notes]
/// unset" apart from "set it to null".
const Object _unset = Object();

/// A booking card. See `docs/architecture.md`, section "The data".
final class EventType {
  /// Creates an [EventType]. The invariants below are programmer errors,
  /// not user input mistakes — the Editor screen validates raw input with
  /// [validateName], [validateDuration] and [validateWindows] first, and
  /// only builds an [EventType] once those pass.
  const EventType({
    required this.id,
    required this.name,
    required this.durationMinutes,
    this.location,
    this.notes,
    required this.preferredWeekdays,
    required this.preferredWindows,
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
         preferredWindows.length > 0,
         'preferredWindows must be non-empty',
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

  /// The times of day this card suits, in order. Non-empty; each window
  /// starts on a 30-minute mark between 06:00 and 22:00 and is at least
  /// [durationMinutes] long. More than one window means "any of these".
  final List<TimeWindow> preferredWindows;

  final DateTime createdAt;

  /// The start of the first preferred window.
  int get preferredStartMinutes => preferredWindows.first.startMinutes;

  /// The end of the last preferred window.
  int get preferredEndMinutes => preferredWindows.last.endMinutes;

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
    if (start < dayStartMinutes || start > dayEndMinutes) {
      return 'Start must be between 06:00 and 22:00.';
    }
    if (start % slotMinutes != 0) {
      return 'Start must be on a 30 minute mark.';
    }
    if (end < start + duration) {
      return 'End must be after start plus the duration.';
    }
    if (end > dayEndMinutes) {
      return 'End must be by 22:00.';
    }
    return null;
  }

  /// Returns the first problem among [windows], or `Add at least one time
  /// window.` when there are none, or `null` when every window is valid.
  static String? validateWindows({
    required List<TimeWindow> windows,
    required int duration,
  }) {
    if (windows.isEmpty) return 'Add at least one time window.';
    for (final window in windows) {
      final error = validateWindow(
        start: window.startMinutes,
        end: window.endMinutes,
        duration: duration,
      );
      if (error != null) return error;
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
    List<TimeWindow>? preferredWindows,
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
      preferredWindows: preferredWindows ?? this.preferredWindows,
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
      'preferredWindows': preferredWindows.map((w) => w.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EventType.fromJson(Map<String, dynamic> json) {
    final weekdaysRaw = requireJson<List<dynamic>>(
      json,
      'preferredWeekdays',
      'EventType',
    );
    return EventType(
      id: requireJson<String>(json, 'id', 'EventType'),
      name: requireJson<String>(json, 'name', 'EventType'),
      durationMinutes: requireJson<int>(json, 'durationMinutes', 'EventType'),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      preferredWeekdays: weekdaysRaw.map((e) => e as int).toSet(),
      preferredWindows: _windowsFrom(json),
      createdAt: DateTime.parse(
        requireJson<String>(json, 'createdAt', 'EventType'),
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
      setEquals(other.preferredWeekdays, preferredWeekdays) &&
      timeWindowListEquals(other.preferredWindows, preferredWindows) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    durationMinutes,
    location,
    notes,
    Object.hashAllUnordered(preferredWeekdays),
    Object.hashAll(preferredWindows),
    createdAt,
  );

  @override
  String toString() =>
      'EventType(id: $id, name: $name, durationMinutes: $durationMinutes)';
}

/// Reads the preferred windows from [json], falling back to the single
/// `preferredStartMinutes`/`preferredEndMinutes` pair written by versions
/// before multiple windows existed.
List<TimeWindow> _windowsFrom(Map<String, dynamic> json) {
  final raw = json['preferredWindows'];
  if (raw != null) {
    if (raw is! List) {
      throw const FormatException(
        'Key "preferredWindows" in EventType JSON has the wrong type.',
      );
    }
    return [
      for (final entry in raw)
        TimeWindow.fromJson(entry as Map<String, dynamic>),
    ];
  }
  return [
    TimeWindow(
      startMinutes: requireJson<int>(
        json,
        'preferredStartMinutes',
        'EventType',
      ),
      endMinutes: requireJson<int>(json, 'preferredEndMinutes', 'EventType'),
    ),
  ];
}
