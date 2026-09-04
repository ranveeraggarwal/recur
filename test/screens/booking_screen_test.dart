import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/booking/booking_screen.dart';
import 'package:recur/widgets/day_pill.dart';
import 'package:recur/widgets/slot_tile.dart';

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
    preferredStartMinutes: 540,
    preferredEndMinutes: 720,
    createdAt: DateTime(2020, 1, 1),
  );
}

Future<void> _pumpBooking(WidgetTester tester, TestDeps testDeps) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: const MaterialApp(home: BookingScreen(eventTypeId: 'et-1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shows the card name, subtitle, and Pick a slot', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    expect(find.text('PT session'), findsOneWidget);
    expect(find.text('60 min · Kungsholmen'), findsOneWidget);
    expect(find.text('Pick a slot'), findsOneWidget);
  });

  testWidgets('tapping an available slot selects it and updates the summary', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    await tester.tap(find.text('09:30'));
    await tester.pumpAndSettle();

    expect(find.text('Mon 7 Sep, 09:30 to 10:30'), findsOneWidget);
  });

  testWidgets('the forward chevron shows next week and enables the back one', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    expect(find.text('Week of 7 Sep'), findsOneWidget);
    final backButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(backButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Week of 14 Sep'), findsOneWidget);
    final backButtonAfter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(backButtonAfter.onPressed, isNotNull);
  });

  testWidgets('selecting a day switches the timeline', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpBooking(tester, testDeps);

    final tuesdayPill = tester
        .widgetList<DayPill>(find.byType(DayPill))
        .firstWhere((p) => p.weekdayLabel == 'Tue');
    expect(tuesdayPill.selected, isFalse);

    await tester.tap(find.text('Tue').first);
    await tester.pumpAndSettle();

    final tuesdayPillAfter = tester
        .widgetList<DayPill>(find.byType(DayPill))
        .firstWhere((p) => p.weekdayLabel == 'Tue');
    expect(tuesdayPillAfter.selected, isTrue);
  });

  group('goldens', () {
    testWidgets('booking_week', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await expectGolden(tester, 'booking_week');
    });

    testWidgets('booking_selected', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.text('Tue').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is SlotTile && widget.timeLabel == '09:30',
        ),
      );
      await tester.pumpAndSettle();

      await expectGolden(tester, 'booking_selected');
    });

    testWidgets('booking_next_week', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const BookingScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      await expectGolden(tester, 'booking_next_week');
    });
  });
}
