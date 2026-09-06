import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/booking/booking_screen.dart';
import 'package:recur/screens/editor/prefill_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

/// `PT session`, 60 min, Kungsholmen, preferred Tue/Thu 09:00-12:00.
EventType _ptSession() {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    location: 'Kungsholmen',
    preferredWeekdays: const {2, 4},
    preferredWindows: [TimeWindow(startMinutes: 540, endMinutes: 720)],
    createdAt: DateTime(2020, 1, 1),
  );
}

CalendarEvent _event({required String id, required DateTime start}) {
  return CalendarEvent(
    id: id,
    calendarId: 'cal-1',
    title: 'Physio',
    start: start,
    end: start.add(const Duration(minutes: 60)),
    isAllDay: false,
  );
}

void main() {
  setUpAll(loadAppFonts);

  /// Pumps [child] at a 320 px wide, 800 px tall view (DPR 1) — the
  /// narrowest phones, and any phone in split-screen — and fails if a
  /// `RenderFlex overflowed` error is reported during the pump.
  Future<void> expectNoOverflow(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(child);
    await tester.pumpAndSettle();

    final overflow = errors.where(
      (e) => e.exceptionAsString().contains('A RenderFlex overflowed'),
    );
    expect(
      overflow,
      isEmpty,
      reason:
          'expected no RenderFlex overflow, got: '
          '${overflow.map((e) => e.exceptionAsString()).join('\n')}',
    );
  }

  testWidgets('BookingScreen day strip does not overflow at 320px', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());

    await expectNoOverflow(
      tester,
      AppScope(
        deps: testDeps.deps,
        child: const MaterialApp(home: BookingScreen(eventTypeId: 'et-1')),
      ),
    );
  });

  testWidgets('PrefillScreen day strip does not overflow at 320px', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    testDeps.calendar.events.add(
      _event(id: 'a', start: DateTime(2026, 9, 8, 10)),
    );

    await expectNoOverflow(
      tester,
      AppScope(
        deps: testDeps.deps,
        child: const MaterialApp(home: PrefillScreen()),
      ),
    );
  });
}
