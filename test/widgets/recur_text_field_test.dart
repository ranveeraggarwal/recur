import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/theme/tokens.dart';
import 'package:recur/widgets/recur_text_field.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('text_field_states', (WidgetTester tester) async {
    final focusedFocusNode = FocusNode();
    final disabledFocusNode = FocusNode(canRequestFocus: false);
    addTearDown(focusedFocusNode.dispose);
    addTearDown(disabledFocusNode.dispose);

    await pumpGolden(
      tester,
      Padding(
        padding: const EdgeInsets.all(RecurSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecurTextField(
              label: 'Name',
              controller: TextEditingController(),
              placeholder: 'PT session',
            ),
            const SizedBox(height: RecurSpacing.lg),
            RecurTextField(
              label: 'Name',
              controller: TextEditingController(text: 'PT session'),
              focusNode: focusedFocusNode,
            ),
            const SizedBox(height: RecurSpacing.lg),
            RecurTextField(
              label: 'Name',
              controller: TextEditingController(),
              errorText: 'Name is required.',
            ),
            const SizedBox(height: RecurSpacing.lg),
            RecurTextField(
              label: 'Name',
              controller: TextEditingController(text: 'PT session'),
              focusNode: disabledFocusNode,
            ),
            const SizedBox(height: RecurSpacing.lg),
            RecurTextField(
              label: 'Notes',
              controller: TextEditingController(text: 'x' * 12),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
      height: 700,
    );

    await tester.pump();
    focusedFocusNode.requestFocus();
    await tester.pumpAndSettle();

    await expectGolden(tester, 'text_field_states');
  });

  testWidgets('RecurTextField forwards typed text to its controller', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpGolden(
      tester,
      RecurTextField(label: 'Name', controller: controller),
    );

    await tester.enterText(find.byType(TextField), 'PT session');
    await tester.pumpAndSettle();

    expect(controller.text, 'PT session');
  });
}
