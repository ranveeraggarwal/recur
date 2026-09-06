// The named `deps` parameter can't share its name with the private `_deps`
// field, so it can't become an initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../app_scope.dart';
import '../../core/time_of_day_minutes.dart';
import '../../core/time_window.dart';
import '../../data/models/event_type.dart';
import 'event_prefill.dart';

/// The durations the Editor offers as pills; anything else is "Custom".
const List<int> editorPresetDurations = [30, 45, 60, 90];

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

  /// The name the card was saved under, set by [load] for an existing
  /// card. Used instead of the live draft's [name] wherever the saved
  /// card needs to be identified, e.g. the delete confirmation, so
  /// clearing or changing the name field first does not change what the
  /// dialog asks to delete.
  String? savedName;

  /// `true` once [load] has run for an [eventTypeId] that no card came
  /// back for. The screen should not be shown in that case.
  bool notFound = false;

  /// `true` once [load] has run and the repository read threw. The
  /// screen should show an error message instead of the form.
  bool loadError = false;

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

  /// The preferred times of day, in the order they are shown. Always at
  /// least one; a card can want mornings and late afternoons but nothing
  /// in between.
  List<TimeWindow> windows = const [
    TimeWindow(startMinutes: 480, endMinutes: 1080),
  ];

  /// Loads the existing card's fields when [eventTypeId] is set, or leaves
  /// the D18 defaults (60 min, Mon-Fri, 08:00-18:00) in place for a new
  /// card. Must be called once before the screen is shown.
  Future<void> load() async {
    final id = eventTypeId;
    if (id != null) {
      try {
        final existing = await _deps.eventTypes.getById(id);
        if (existing != null) {
          name = existing.name;
          durationMinutes = existing.durationMinutes;
          isCustomDuration = !editorPresetDurations.contains(
            existing.durationMinutes,
          );
          customDurationText = '${existing.durationMinutes}';
          location = existing.location;
          notes = existing.notes;
          weekdays = Set.of(existing.preferredWeekdays);
          windows = List.of(existing.preferredWindows);
          _createdAt = existing.createdAt;
          savedName = existing.name;
        } else {
          notFound = true;
        }
      } catch (_) {
        loadError = true;
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

  /// The first problem among [windows], or `null` when every one of them
  /// is valid.
  String? get windowError =>
      EventType.validateWindows(windows: windows, duration: durationMinutes);

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

  void setWindowStart(int index, int minutes) {
    windows = [
      for (var i = 0; i < windows.length; i++)
        i == index ? windows[i].copyWith(startMinutes: minutes) : windows[i],
    ];
    notifyListeners();
  }

  void setWindowEnd(int index, int minutes) {
    windows = [
      for (var i = 0; i < windows.length; i++)
        i == index ? windows[i].copyWith(endMinutes: minutes) : windows[i],
    ];
    notifyListeners();
  }

  /// Appends a window that starts where the last one ends, or as close to
  /// it as 22:00 allows, long enough to hold one appointment.
  void addWindow() {
    windows = [...windows, _nextWindow()];
    notifyListeners();
  }

  /// Removes the window at [index]. The last remaining window stays: a
  /// card always prefers some time of day.
  void removeWindow(int index) {
    if (windows.length <= 1) return;
    if (index < 0 || index >= windows.length) return;
    windows = [
      for (var i = 0; i < windows.length; i++)
        if (i != index) windows[i],
    ];
    notifyListeners();
  }

  TimeWindow _nextWindow() {
    final span = roundUpToSlot(
      durationMinutes < slotMinutes ? slotMinutes : durationMinutes,
    );
    final previousEnd = windows.isEmpty ? 480 : windows.last.endMinutes;
    var start = previousEnd;
    if (start + span > dayEndMinutes) start = dayEndMinutes - span;
    if (start < dayStartMinutes) start = dayStartMinutes;
    return TimeWindow(startMinutes: start, endMinutes: start + span);
  }

  /// Fills the whole form in from an event already in the calendar. The
  /// user can still change anything before saving.
  void applyPrefill(EventPrefill prefill) {
    name = prefill.name;
    nameTouched = true;
    durationMinutes = prefill.durationMinutes;
    isCustomDuration = !editorPresetDurations.contains(prefill.durationMinutes);
    customDurationText = '${prefill.durationMinutes}';
    location = prefill.location;
    notes = prefill.notes;
    weekdays = Set.of(prefill.weekdays);
    windows = List.of(prefill.windows);
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
        preferredWindows: List.of(windows),
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
