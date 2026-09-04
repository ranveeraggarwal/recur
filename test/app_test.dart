import 'package:flutter_test/flutter_test.dart';
import 'package:recur/app.dart';

void main() {
  testWidgets('shows the app name and the empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const RecurApp());

    expect(find.text('Recur'), findsOneWidget);
    expect(find.text('No events yet.'), findsOneWidget);
  });
}
