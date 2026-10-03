import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:recur/history/marker.dart';

void main() {
  group('markerLine', () {
    test('is rc, the card code, then the occurrence code', () {
      expect(
        markerLine(cardCode: 'ab', occurrenceCode: '3k7'),
        'Booked with Recur - rcab3k7',
      );
    });
  });

  group('notesWithMarker', () {
    test('puts the marker after a blank line', () {
      expect(
        notesWithMarker('Bring a towel', 'Booked with Recur - rcab3k7'),
        'Bring a towel\n\nBooked with Recur - rcab3k7',
      );
    });

    test('is the marker alone when there are no notes', () {
      expect(
        notesWithMarker(null, 'Booked with Recur - rcab3k7'),
        'Booked with Recur - rcab3k7',
      );
    });
  });

  group('parseMarker', () {
    test('reads the codes back', () {
      expect(parseMarker('Booked with Recur - rcab3k7'), (
        cardCode: 'ab',
        occurrenceCode: '3k7',
      ));
    });

    test('finds the marker among other notes', () {
      expect(
        parseMarker('Bring a towel\n\nBooked with Recur - rcab3k7\nGate B'),
        (cardCode: 'ab', occurrenceCode: '3k7'),
      );
    });

    test('ignores notes without a marker', () {
      expect(parseMarker(null), isNull);
      expect(parseMarker('Bring a towel'), isNull);
    });

    test('needs exactly five code characters', () {
      expect(parseMarker('Booked with Recur - rcab3k'), isNull);
      expect(parseMarker('Booked with Recur - rcab3k7x'), isNull);
      expect(parseMarker('Booked with Recur - rcAB3K7'), isNull);
    });
  });

  group('codes', () {
    test('randomCode draws from the code alphabet', () {
      final random = Random(1);
      for (var i = 0; i < 50; i++) {
        expect(randomCode(random, 3), matches(RegExp(r'^[0-9a-z]{3}$')));
      }
    });

    test('newCardCode avoids every taken code', () {
      final random = Random(1);
      final taken = <String>{};
      for (var i = 0; i < cardCodeCount; i++) {
        final code = newCardCode(random, taken);
        expect(taken.contains(code), isFalse);
        taken.add(code);
      }
      expect(() => newCardCode(random, taken), throwsStateError);
    });
  });
}
