import 'package:flutter/material.dart';

import '../calendar/calendar_gateway.dart';
import '../theme/tokens.dart';
import 'confirm_button.dart';

/// The centred message, and the one button that can do something about it,
/// shown in place of a calendar view when access is missing or there is no
/// writable calendar.
///
/// Booking replaces its week header, day strip and timeline (no confirm
/// bar) with this; `Copy from calendar` replaces its week with it. A screen
/// that only reads the calendar passes `hasWritableCalendar: true`, since
/// having somewhere to write is not its problem.
class AccessState extends StatelessWidget {
  const AccessState({
    super.key,
    required this.access,
    required this.hasWritableCalendar,
    required this.onRequestAccess,
    required this.onOpenSettings,
    this.message,
  });

  final CalendarAccess access;
  final bool hasWritableCalendar;
  final VoidCallback onRequestAccess;
  final VoidCallback onOpenSettings;

  /// Replaces the missing-access sentence, for a screen that wants the
  /// calendar for something other than showing a week. The no-writable-
  /// calendar sentence is a different problem and is never replaced.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final String text;
    String? buttonLabel;
    VoidCallback? onPressed;

    if (access == CalendarAccess.notDetermined) {
      text = message ?? 'Recur needs calendar access to show your week.';
      buttonLabel = 'Allow calendar access';
      onPressed = onRequestAccess;
    } else if (access == CalendarAccess.denied) {
      text = message ?? 'Calendar access is off for Recur.';
      buttonLabel = 'Open settings';
      onPressed = onOpenSettings;
    } else {
      text = 'No writable calendar found.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: RecurText.body, textAlign: TextAlign.center),
            if (buttonLabel != null) ...[
              const SizedBox(height: RecurSpacing.lg),
              ConfirmButton(
                label: buttonLabel,
                onPressed: onPressed,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
