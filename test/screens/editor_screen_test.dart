import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/calendar/calendar_gateway.dart';
import 'package:recur/core/time_window.dart';
import 'package:recur/data/booking_repository.dart';
import 'package:recur/data/event_type_repository.dart';
import 'package:recur/data/local_store.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/data/settings_repository.dart';
import 'package:recur/screens/editor/editor_screen.dart';
import 'package:recur/theme/app_theme.dart';
import 'package:recur/widgets/confirm_button.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

/// A [LocalStore] that reads normally from [_inner] but throws on every
/// write and delete, standing in for a full disk or a corrupt write.
class _WriteThrowingLocalStore implements LocalStore {
  _WriteThrowingLocalStore(this._inner);

  final LocalStore _inner;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String json) async {
    throw Exception('write failed');
  }

  @override
  Future<void> delete(String key) async {
    throw Exception('delete failed');
  }
}

/// Rebuilds [testDeps] over a [_WriteThrowingLocalStore] backed by its own
/// store, so anything already saved is still readable but every write or
/// delete fails.
TestDeps _withWriteFailure(TestDeps testDeps) {
  final throwingStore = _WriteThrowingLocalStore(testDeps.store);
  return TestDeps(
    deps: AppDependencies(
      clock: testDeps.deps.clock,
      ids: testDeps.deps.ids,
      eventTypes: LocalEventTypeRepository(throwingStore),
      bookings: LocalBookingRepository(throwingStore),
      settings: LocalSettingsRepository(throwingStore),
      calendar: testDeps.calendar,
      places: testDeps.places,
    ),
    calendar: testDeps.calendar,
    places: testDeps.places,
    clock: testDeps.clock,
    store: testDeps.store,
  );
}

EventType _ptSession() {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    location: 'Kungsholmen',
    preferredWeekdays: const {1, 3, 5},
    preferredWindows: [TimeWindow(startMinutes: 480, endMinutes: 1080)],
    createdAt: DateTime(2026, 1, 1),
  );
}

/// The times the Start/End dropdowns actually show, read off the form
/// fields rather than the controller, so a field left holding a stale
/// value is caught.
List<int?> _dropdownValues(WidgetTester tester) => tester
    .stateList<FormFieldState<int>>(find.byType(DropdownButtonFormField<int>))
    .map((state) => state.value)
    .toList();

Future<void> _pumpEditor(
  WidgetTester tester,
  TestDeps testDeps, {
  String? eventTypeId,
}) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(home: EditorScreen(eventTypeId: eventTypeId)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a root screen with a button that pushes [EditorScreen], so tests
/// can observe `Navigator.pop` (returning to the root) after Save/Delete.
Future<void> _pumpEditorPushed(
  WidgetTester tester,
  TestDeps testDeps, {
  String? eventTypeId,
}) async {
  await tester.pumpWidget(
    AppScope(
      deps: testDeps.deps,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditorScreen(eventTypeId: eventTypeId),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a new card shows New event and Save is disabled', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpEditor(tester, testDeps);

    expect(find.text('New event'), findsOneWidget);
    final confirmButton = tester.widget<ConfirmButton>(
      find.byType(ConfirmButton),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('Save becomes enabled once the name is filled in', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpEditor(tester, testDeps);

    await tester.enterText(find.byType(TextField).first, 'PT session');
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<ConfirmButton>(
      find.byType(ConfirmButton),
    );
    expect(confirmButton.onPressed, isNotNull);
  });

  testWidgets('saving a new card navigates back with true', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await _pumpEditorPushed(tester, testDeps);

    await tester.enterText(find.byType(TextField).first, 'PT session');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ConfirmButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    final saved = await testDeps.deps.eventTypes.getAll();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'PT session');
  });

  testWidgets(
    'editing an existing card shows Edit event with no Delete button for a new one',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      expect(find.text('Delete event type'), findsNothing);
    },
  );

  testWidgets(
    'the delete dialog shows the exact copy and Delete removes the card',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      await _pumpEditorPushed(tester, testDeps, eventTypeId: 'et-1');

      expect(find.text('Edit event'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete event type'));
      await tester.tap(find.text('Delete event type'));
      await tester.pumpAndSettle();

      expect(find.text('Delete "PT session"?'), findsOneWidget);
      expect(
        find.text(
          'Past bookings are removed from Recur. '
          'Calendar events are not touched.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(await testDeps.deps.eventTypes.getById('et-1'), isNull);
      expect(testDeps.calendar.created, isEmpty);
    },
  );

  testWidgets('Cancel in the delete dialog keeps the card', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    await _pumpEditorPushed(tester, testDeps, eventTypeId: 'et-1');

    await tester.ensureVisible(find.text('Delete event type'));
    await tester.tap(find.text('Delete event type'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Edit event'), findsOneWidget);
    expect(await testDeps.deps.eventTypes.getById('et-1'), isNotNull);
  });

  testWidgets(
    'the delete dialog names the card as it was saved, not the live draft',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      await _pumpEditor(tester, testDeps, eventTypeId: 'et-1');

      await tester.enterText(find.byType(TextField).first, 'Updated name');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete event type'));
      await tester.tap(find.text('Delete event type'));
      await tester.pumpAndSettle();

      expect(find.text('Delete "PT session"?'), findsOneWidget);
      expect(find.text('Delete "Updated name"?'), findsNothing);
    },
  );

  testWidgets('a failed save shows a snack bar and stays on the screen', (
    WidgetTester tester,
  ) async {
    final testDeps = _withWriteFailure(buildTestDeps());
    await _pumpEditorPushed(tester, testDeps);

    await tester.enterText(find.byType(TextField).first, 'PT session');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ConfirmButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsNothing);
    expect(find.text("Couldn't save."), findsOneWidget);
    expect(await testDeps.deps.eventTypes.getAll(), isEmpty);
  });

  testWidgets('a failed delete shows a snack bar and stays on the screen', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.deps.eventTypes.upsert(_ptSession());
    final failing = _withWriteFailure(testDeps);
    await _pumpEditorPushed(tester, failing, eventTypeId: 'et-1');

    await tester.ensureVisible(find.text('Delete event type'));
    await tester.tap(find.text('Delete event type'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsNothing);
    expect(find.text("Couldn't delete."), findsOneWidget);
    expect(await testDeps.deps.eventTypes.getById('et-1'), isNotNull);
  });

  testWidgets(
    'a card that no longer exists pops the route without writing anything',
    (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await tester.pumpWidget(
        AppScope(
          deps: testDeps.deps,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const EditorScreen(eventTypeId: 'missing'),
                      ),
                    ),
                    child: const Text('home'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(EditorScreen), findsNothing);
      expect(await testDeps.deps.eventTypes.getAll(), isEmpty);
    },
  );

  testWidgets("a read failure shows Couldn't open this card. with an app bar", (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    await testDeps.store.write('event_types', 'not json');
    await _pumpEditor(tester, testDeps, eventTypeId: 'et-1');

    expect(find.text("Couldn't open this card."), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  group('preferred times', () {
    testWidgets('Add a time adds a start and end pair', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      expect(find.text('Start'), findsOneWidget);

      await tester.ensureVisible(find.text('Add a time'));
      await tester.tap(find.text('Add a time'));
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsNWidgets(2));
      expect(find.text('End'), findsNWidgets(2));
    });

    testWidgets('the remove button appears only with more than one time', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      expect(find.byTooltip('Remove this time'), findsNothing);

      await tester.ensureVisible(find.text('Add a time'));
      await tester.tap(find.text('Add a time'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove this time'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Remove this time').first);
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget);
      expect(find.byTooltip('Remove this time'), findsNothing);
      // The row left behind shows the second window's times, not the
      // removed row's.
      expect(_dropdownValues(tester), [1080, 1140]);
    });

    testWidgets('both times are saved on the card', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      await tester.enterText(find.byType(TextField).first, 'PT session');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add a time'));
      await tester.tap(find.text('Add a time'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ConfirmButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = (await testDeps.deps.eventTypes.getAll()).single;
      expect(saved.preferredWindows, hasLength(2));
    });
  });

  group('custom duration', () {
    testWidgets(
      "switching to a preset and back to Custom shows the preset's minutes",
      (WidgetTester tester) async {
        final testDeps = buildTestDeps();
        await _pumpEditor(tester, testDeps);

        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), '75');
        await tester.pumpAndSettle();

        await tester.tap(find.text('30 min'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Custom'));
        await tester.pumpAndSettle();

        final minutesField = tester.widget<TextField>(
          find.byType(TextField).at(1),
        );
        expect(minutesField.controller!.text, '30');
      },
    );

    testWidgets('typing in Minutes still works after a preset was chosen', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      await tester.enterText(find.byType(TextField).first, 'PT session');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '75');
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '45');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ConfirmButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = (await testDeps.deps.eventTypes.getAll()).single;
      expect(saved.durationMinutes, 45);
    });
  });

  group('copy from calendar', () {
    void seedPhysio(TestDeps testDeps) {
      testDeps.calendar.events.add(
        CalendarEvent(
          id: 'evt-9',
          calendarId: 'cal-1',
          title: 'Physio',
          // Tuesday of the week the picker opens on.
          start: DateTime(2026, 9, 8, 10),
          end: DateTime(2026, 9, 8, 10, 45),
          isAllDay: false,
          location: 'Vasastan',
          notes: 'Bring the referral',
        ),
      );
    }

    testWidgets('the button is offered on a new card', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      expect(find.text('Copy from calendar'), findsOneWidget);
    });

    testWidgets('the button is not offered when editing a card', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());
      await _pumpEditor(tester, testDeps, eventTypeId: 'et-1');

      expect(find.text('Copy from calendar'), findsNothing);
    });

    testWidgets('picking an event off the calendar fills the form in', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      seedPhysio(testDeps);
      await _pumpEditor(tester, testDeps);

      await tester.tap(find.text('Copy from calendar'));
      await tester.pumpAndSettle();

      // The week view, not a list of names.
      expect(find.text('Week of 7 Sep'), findsOneWidget);
      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physio'));
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.controller!.text, 'Physio');
      expect(find.text('Bring the referral'), findsOneWidget);
      expect(find.text('Vasastan'), findsOneWidget);
      expect(_dropdownValues(tester), [600, 660]);

      await tester.tap(find.widgetWithText(ConfirmButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = (await testDeps.deps.eventTypes.getAll()).single;
      expect(saved.name, 'Physio');
      expect(saved.durationMinutes, 45);
      expect(saved.location, 'Vasastan');
      expect(saved.notes, 'Bring the referral');
      expect(saved.preferredWeekdays, {2});
      expect(saved.preferredWindows, [
        const TimeWindow(startMinutes: 600, endMinutes: 660),
      ]);
    });

    testWidgets('backing out of the picker leaves the draft alone', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      seedPhysio(testDeps);
      await _pumpEditor(tester, testDeps);

      await tester.enterText(find.byType(TextField).first, 'PT session');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy from calendar'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.controller!.text, 'PT session');
    });

    testWidgets('an empty calendar says so', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await _pumpEditor(tester, testDeps);

      await tester.tap(find.text('Copy from calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing in your calendar to copy.'), findsOneWidget);
    });

    testWidgets('without calendar access it asks for it', (
      WidgetTester tester,
    ) async {
      final testDeps = buildTestDeps();
      seedPhysio(testDeps);
      testDeps.calendar.access = CalendarAccess.denied;
      await _pumpEditor(tester, testDeps);

      await tester.tap(find.text('Copy from calendar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Recur needs calendar access to copy an event.'),
        findsOneWidget,
      );
    });
  });

  group('goldens', () {
    testWidgets('editor_new', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const EditorScreen()),
        height: 900,
        scaffold: false,
      );

      await expectGolden(tester, 'editor_new');
    });

    testWidgets('editor_edit', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      await pumpGolden(
        tester,
        AppScope(
          deps: testDeps.deps,
          child: const EditorScreen(eventTypeId: 'et-1'),
        ),
        height: 900,
        scaffold: false,
      );

      await expectGolden(tester, 'editor_edit');
    });

    testWidgets('editor_error', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const EditorScreen()),
        height: 900,
        scaffold: false,
      );

      await tester.enterText(find.byType(TextField).first, 'PT session');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      await expectGolden(tester, 'editor_error');
    });

    testWidgets('editor_custom_duration', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const EditorScreen()),
        height: 900,
        scaffold: false,
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '75');
      await tester.pumpAndSettle();

      await expectGolden(tester, 'editor_custom_duration');
    });

    testWidgets('editor_two_times', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await pumpGolden(
        tester,
        AppScope(deps: testDeps.deps, child: const EditorScreen()),
        height: 900,
        scaffold: false,
      );

      await tester.ensureVisible(find.text('Add a time'));
      await tester.tap(find.text('Add a time'));
      await tester.pumpAndSettle();

      await expectGolden(tester, 'editor_two_times');
    });

    testWidgets('editor_delete_dialog', (WidgetTester tester) async {
      final testDeps = buildTestDeps();
      await testDeps.deps.eventTypes.upsert(_ptSession());

      tester.view.physicalSize = const Size(goldenWidth, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          deps: testDeps.deps,
          child: MaterialApp(
            theme: buildRecurTheme(),
            home: const EditorScreen(eventTypeId: 'et-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete event type'));
      await tester.tap(find.text('Delete event type'));
      await tester.pumpAndSettle();

      await expectGolden(tester, 'editor_delete_dialog');
    });
  });
}
