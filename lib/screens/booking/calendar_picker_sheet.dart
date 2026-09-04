import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../theme/tokens.dart';

/// Opens the calendar picker sheet: one row per writable calendar, with a
/// check mark on the current selection. Tapping a row stores the choice
/// through `SettingsRepository`, closes the sheet, and returns the chosen
/// id (`null` if dismissed without choosing).
///
/// Only reachable from the Home app bar icon (2+ writable calendars) and
/// from a first Confirm when no calendar has been chosen yet.
Future<String?> showCalendarPicker(BuildContext context) async {
  final deps = AppScope.of(context);
  final calendars = await deps.calendar.listWritableCalendars();
  final settings = await deps.settings.get();
  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: RecurColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: RecurRadii.sheet),
    builder: (sheetContext) {
      return _CalendarPickerSheet(
        calendars: calendars,
        selectedCalendarId: settings.selectedCalendarId,
        onSelect: (calendarId) async {
          await deps.settings.save(
            settings.copyWith(selectedCalendarId: calendarId),
          );
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop(calendarId);
          }
        },
      );
    },
  );
}

class _CalendarPickerSheet extends StatelessWidget {
  const _CalendarPickerSheet({
    required this.calendars,
    required this.selectedCalendarId,
    required this.onSelect,
  });

  final List<CalendarInfo> calendars;
  final String? selectedCalendarId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: RecurSpacing.md,
          bottom: RecurSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xl),
              child: Text('Write bookings to', style: RecurText.title),
            ),
            const SizedBox(height: RecurSpacing.sm),
            for (final calendar in calendars)
              _CalendarRow(
                calendar: calendar,
                selected: calendar.id == selectedCalendarId,
                onTap: () => onSelect(calendar.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(bottom: RecurSpacing.lg),
        decoration: BoxDecoration(
          color: RecurColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required this.calendar,
    required this.selected,
    required this.onTap,
  });

  final CalendarInfo calendar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: RecurColors.primaryTint,
        highlightColor: RecurColors.primaryTint,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(calendar.name, style: RecurText.body),
                      if (calendar.accountName != null)
                        Text(
                          calendar.accountName!,
                          style: RecurText.caption.copyWith(
                            color: RecurColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check, size: 24, color: RecurColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
