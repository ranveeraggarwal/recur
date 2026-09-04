/// The app's one piece of persisted settings: which calendar to book into.
///
/// See `docs/architecture.md`, section "The data".
library;

/// Sentinel used by [AppSettings.copyWith] to tell "leave
/// [AppSettings.selectedCalendarId] unset" apart from "set it to null".
const Object _unset = Object();

final class AppSettings {
  const AppSettings({this.selectedCalendarId});

  /// The id of the calendar the user chose, or `null` if none has been
  /// chosen yet.
  final String? selectedCalendarId;

  static const AppSettings empty = AppSettings(selectedCalendarId: null);

  AppSettings copyWith({Object? selectedCalendarId = _unset}) {
    return AppSettings(
      selectedCalendarId: identical(selectedCalendarId, _unset)
          ? this.selectedCalendarId
          : selectedCalendarId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'selectedCalendarId': selectedCalendarId};
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      selectedCalendarId: json['selectedCalendarId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.selectedCalendarId == selectedCalendarId;

  @override
  int get hashCode => selectedCalendarId.hashCode;

  @override
  String toString() => 'AppSettings(selectedCalendarId: $selectedCalendarId)';
}
