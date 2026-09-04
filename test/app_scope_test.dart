import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app_scope.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('AppScope.of returns the injected deps', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    late AppDependencies fromContext;

    await tester.pumpWidget(
      AppScope(
        deps: testDeps.deps,
        child: Builder(
          builder: (context) {
            fromContext = AppScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(fromContext, same(testDeps.deps));
  });

  testWidgets(
    'AppScope.of throws a FlutterError naming AppScope when missing',
    (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      expect(
        () => AppScope.of(capturedContext),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.toString(),
            'message',
            contains('AppScope'),
          ),
        ),
      );
    },
  );

  testWidgets('updateShouldNotify is false for the same instance', (
    WidgetTester tester,
  ) async {
    final testDeps = buildTestDeps();
    final scope = AppScope(deps: testDeps.deps, child: const SizedBox());

    expect(scope.updateShouldNotify(scope), isFalse);
  });

  testWidgets('updateShouldNotify is true for a different instance', (
    WidgetTester tester,
  ) async {
    final first = buildTestDeps();
    final second = buildTestDeps();

    final oldScope = AppScope(deps: first.deps, child: const SizedBox());
    final newScope = AppScope(deps: second.deps, child: const SizedBox());

    expect(newScope.updateShouldNotify(oldScope), isTrue);
  });
}
