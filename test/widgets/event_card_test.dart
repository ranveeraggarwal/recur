import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/widgets/event_card.dart';

import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  Widget buildCard({
    required String name,
    int durationMinutes = 60,
    String? location,
    required String lastBookedText,
    bool lastBookedIsFuture = false,
    CardColumn column = CardColumn.one,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return Center(
      child: SizedBox(
        width: 166,
        child: EventCard(
          name: name,
          durationMinutes: durationMinutes,
          location: location,
          lastBookedText: lastBookedText,
          lastBookedIsFuture: lastBookedIsFuture,
          column: column,
          onTap: onTap ?? () {},
          onLongPress: onLongPress ?? () {},
        ),
      ),
    );
  }

  group('goldens', () {
    testWidgets('event_card_column_one', (WidgetTester tester) async {
      await pumpGolden(
        tester,
        buildCard(
          name: 'PT session',
          durationMinutes: 60,
          location: 'Kungsholmen',
          lastBookedText: 'Last booked 3 weeks ago',
        ),
        height: 220,
      );

      await expectGolden(tester, 'event_card_column_one');
    });

    testWidgets('event_card_column_two', (WidgetTester tester) async {
      await pumpGolden(
        tester,
        buildCard(
          name: 'PT session',
          durationMinutes: 60,
          location: 'Kungsholmen',
          lastBookedText: 'Last booked 3 weeks ago',
          column: CardColumn.two,
        ),
        height: 220,
      );

      await expectGolden(tester, 'event_card_column_two');
    });

    testWidgets('event_card_never_booked', (WidgetTester tester) async {
      await pumpGolden(
        tester,
        buildCard(
          name: 'Massage',
          durationMinutes: 45,
          location: 'Södermalm',
          lastBookedText: 'Not booked yet',
        ),
        height: 220,
      );

      await expectGolden(tester, 'event_card_never_booked');
    });

    testWidgets('event_card_future_booking', (WidgetTester tester) async {
      await pumpGolden(
        tester,
        buildCard(
          name: 'Dentist',
          durationMinutes: 30,
          location: 'Vasastan',
          lastBookedText: 'Booked for Tue 8 Sep',
          lastBookedIsFuture: true,
        ),
        height: 220,
      );

      await expectGolden(tester, 'event_card_future_booking');
    });

    testWidgets('event_card_long_name', (WidgetTester tester) async {
      await pumpGolden(
        tester,
        buildCard(
          name: 'Physiotherapy follow-up with Dr Lindqvist',
          durationMinutes: 60,
          lastBookedText: 'Last booked 3 weeks ago',
        ),
        height: 260,
      );

      await expectGolden(tester, 'event_card_long_name');
    });
  });

  group('behaviour', () {
    testWidgets('onTap fires on tap', (WidgetTester tester) async {
      var tapped = false;

      await pumpGolden(
        tester,
        buildCard(
          name: 'PT session',
          lastBookedText: 'Last booked 3 weeks ago',
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('onLongPress fires on long press', (WidgetTester tester) async {
      var longPressed = false;

      await pumpGolden(
        tester,
        buildCard(
          name: 'PT session',
          lastBookedText: 'Last booked 3 weeks ago',
          onLongPress: () => longPressed = true,
        ),
      );

      await tester.longPress(find.byType(EventCard));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });
  });

  group('semantics', () {
    testWidgets('a card reads as one button with a hint about editing', (
      WidgetTester tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGolden(
        tester,
        buildCard(
          name: 'PT session',
          durationMinutes: 60,
          location: 'Kungsholmen',
          lastBookedText: 'Last booked 3 weeks ago',
        ),
        height: 220,
      );

      expect(
        tester.getSemantics(find.byType(EventCard)),
        matchesSemantics(
          label: 'PT session, 60 min, Kungsholmen, Last booked 3 weeks ago',
          hint: 'Double tap to book, double tap and hold to edit',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a card without a location leaves it out of the label', (
      WidgetTester tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGolden(
        tester,
        buildCard(
          name: 'Massage',
          durationMinutes: 45,
          lastBookedText: 'Not booked yet',
        ),
        height: 220,
      );

      expect(
        tester.getSemantics(find.byType(EventCard)),
        matchesSemantics(
          label: 'Massage, 45 min, Not booked yet',
          hint: 'Double tap to book, double tap and hold to edit',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the lines are not read again one by one', (
      WidgetTester tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGolden(
        tester,
        buildCard(
          name: 'PT session',
          durationMinutes: 60,
          location: 'Kungsholmen',
          lastBookedText: 'Last booked 3 weeks ago',
        ),
        height: 220,
      );

      expect(find.bySemanticsLabel('PT session'), findsNothing);
      expect(find.bySemanticsLabel('Kungsholmen'), findsNothing);
      expect(find.bySemanticsLabel('Last booked 3 weeks ago'), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('location is omitted when null', (WidgetTester tester) async {
    await pumpGolden(
      tester,
      buildCard(name: 'PT session', lastBookedText: 'Last booked 3 weeks ago'),
    );

    expect(find.text('Kungsholmen'), findsNothing);
  });
}
