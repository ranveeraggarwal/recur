// The named `deps` parameter can't share its name with the private `_deps`
// field, so it can't become an initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../app_scope.dart';
import '../../data/models/event_type.dart';

/// Draft state for the Editor screen: one event type being created or
/// edited, with live validation, [save], and [delete].
///
/// Reads and writes only through [AppDependencies], never `DateTime.now()`
/// or a fresh id generator directly, so it stays testable.
class EditorController extends ChangeNotifier {
  EditorController({required AppDependencies deps, this.eventTypeId})
    : _deps = deps;

  final AppDependencies _deps;

  /// The id of the card being edited, or `null` when creating a new one.
  final String? eventTypeId;

  bool get isNew => eventTypeId == null;

  bool _loading = true;
  bool get loading => _loading;

  DateTime? _createdAt;

  String name = '';
  bool nameTouched = false;

  int durationMinutes = 60;
  bool isCustomDuration = false;

  /// The raw text of the custom-duration field, kept separately from
  /// [durationMinutes] so an unparseable or out-of-range value can still be
  /// shown (and flagged as an error) without corrupting the last valid
  /// duration.
  String customDurationText = '60';

  String? location;
  String? notes;

  Set<int> weekdays = {1, 2, 3, 4, 5};

  int startMinutes = 480;
  int endMinutes = 1080;

  /// Loads the existing card's fields when [eventTypeId] is set, or leaves
  /// the D18 defaults (60 min, Mon-Fri, 08:00-18:00) in place for a new
  /// card. Must be called once before the screen is shown.
  Future<void> load() async {
    final id = eventTypeId;
    if (id != null) {
      final existing = await _deps.eventTypes.getById(id);
      if (existing != null) {
        name = existing.name;
        durationMinutes = existing.durationMinutes;
        isCustomDuration = ![30, 45, 60, 90].contains(existing.durationMinutes);
        customDurationText = '${existing.durationMinutes}';
        location = existing.location;
        notes = existing.notes;
        weekdays = Set.of(existing.preferredWeekdays);
        startMinutes = existing.preferredStartMinutes;
        endMinutes = existing.preferredEndMinutes;
        _createdAt = existing.createdAt;
      }
    }
    _loading = false;
    notifyListeners();
  }

  String? get nameError => nameTouched ? EventType.validateName(name) : null;

  /// `Use 5 to 480 minutes in steps of 5.` when the custom-duration field
  /// holds an unparseable or out-of-range value. `null` when a preset is
  /// selected, or the custom value is valid.
  String? get durationError {
    if (!isCustomDuration) return null;
    final parsed = int.tryParse(customDurationText);
    if (parsed == null || EventType.validateDuration(parsed) != null) {
      return 'Use 5 to 480 minutes in steps of 5.';
    }
    return null;
  }

  String? get windowError => EventType.validateWindow(
    start: startMinutes,
    end: endMinutes,
    duration: durationMinutes,
  );

  bool get isValid =>
      EventType.validateName(name) == null &&
      weekdays.isNotEmpty &&
      durationError == null &&
      windowError == null;

  void setName(String value) {
    name = value;
    nameTouched = true;
    notifyListeners();
  }

  void selectPresetDuration(int minutes) {
    isCustomDuration = false;
    durationMinutes = minutes;
    customDurationText = '$minutes';
    notifyListeners();
  }

  void selectCustomDuration() {
    isCustomDuration = true;
    customDurationText = '$durationMinutes';
    notifyListeners();
  }

  void setCustomDurationText(String text) {
    customDurationText = text;
    final parsed = int.tryParse(text);
    if (parsed != null) {
      durationMinutes = parsed;
    }
    notifyListeners();
  }

  void setLocation(String value) {
    location = value.isEmpty ? null : value;
    notifyListeners();
  }

  void setNotes(String value) {
    notes = value.isEmpty ? null : value;
    notifyListeners();
  }

  void toggleWeekday(int weekday) {
    if (weekdays.contains(weekday)) {
      weekdays = {...weekdays}..remove(weekday);
    } else {
      weekdays = {...weekdays, weekday};
    }
    notifyListeners();
  }

  void setStartMinutes(int minutes) {
    startMinutes = minutes;
    notifyListeners();
  }

  void setEndMinutes(int minutes) {
    endMinutes = minutes;
    notifyListeners();
  }

  /// Upserts the current draft. Uses `ids.next()` and `clock.now()` for a
  /// new card's id and `createdAt`; an existing card keeps both.
  Future<void> save() async {
    final id = eventTypeId ?? _deps.ids.next();
    final createdAt = _createdAt ?? _deps.clock.now();
    final trimmedLocation = location?.trim();
    final trimmedNotes = notes?.trim();

    await _deps.eventTypes.upsert(
      EventType(
        id: id,
        name: name.trim(),
        durationMinutes: durationMinutes,
        location: (trimmedLocation == null || trimmedLocation.isEmpty)
            ? null
            : trimmedLocation,
        notes: (trimmedNotes == null || trimmedNotes.isEmpty)
            ? null
            : trimmedNotes,
        preferredWeekdays: Set.of(weekdays),
        preferredStartMinutes: startMinutes,
        preferredEndMinutes: endMinutes,
        createdAt: createdAt,
      ),
    );
  }

  /// Removes this card's local bookings, then the card itself. Never calls
  /// the calendar gateway (decision D10: deleting a card never touches the
  /// calendar).
  Future<void> delete() async {
    final id = eventTypeId;
    if (id == null) return;
    await _deps.bookings.deleteForEventType(id);
    await _deps.eventTypes.delete(id);
  }
}
