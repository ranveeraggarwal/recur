import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';
import 'package:recur/data/models/event_type.dart';
import 'package:recur/screens/editor/editor_screen.dart';
import 'package:recur/widgets/confirm_button.dart';

import '../helpers/fakes.dart';
import '../helpers/golden.dart';

EventType _ptSession() {
  return EventType(
    id: 'et-1',
    name: 'PT session',
    durationMinutes: 60,
    location: 'Kungsholmen',
    preferredWeekdays: const {1, 3, 5},
    preferredStartMinutes: 480,
    preferredEndMinutes: 1080,
    createdAt: DateTime(2026, 1, 1),
  );
}

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
  });
}
