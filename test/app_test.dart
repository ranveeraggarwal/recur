import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app.dart';
import 'package:recur/app_scope.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('shows the app name and the empty state', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();

    await tester.pumpWidget(
      AppScope(deps: testDeps.deps, child: const RecurApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recur'), findsOneWidget);
    expect(find.text('No events yet.'), findsOneWidget);
  });
}
