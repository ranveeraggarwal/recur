/// The line Recur adds to the notes of every event it opens, and how it is
/// read back. See `docs/architecture.md`, section "The marker".
library;

import 'dart:math';

/// The characters a card or occurrence code is made of.
const String codeAlphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

/// How many characters name a card inside the marker.
const int cardCodeLength = 2;

/// How many characters name one tap inside the marker.
const int occurrenceCodeLength = 3;

/// Every card code there is: 36 squared.
const int cardCodeCount = 1296;

/// Matches `Recur - rc` followed by exactly five code characters, and
/// captures the card code and the occurrence code.
final RegExp _markerPattern = RegExp(
  r'Recur - rc([0-9a-z]{2})([0-9a-z]{3})(?![0-9a-z])',
);

/// [length] characters drawn from [codeAlphabet].
String randomCode(Random random, int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(codeAlphabet[random.nextInt(codeAlphabet.length)]);
  }
  return buffer.toString();
}

/// A card code that is not in [taken]. Throws [StateError] when every code
/// is taken.
String newCardCode(Random random, Set<String> taken) {
  if (taken.length >= cardCodeCount) {
    throw StateError('Every card code is taken.');
  }
  while (true) {
    final code = randomCode(random, cardCodeLength);
    if (!taken.contains(code)) return code;
  }
}

/// The marker line for one tap on the card with [cardCode].
String markerLine({required String cardCode, required String occurrenceCode}) =>
    'Booked with Recur - rc$cardCode$occurrenceCode';

/// The event's notes: the card's [notes], a blank line, then [marker]; or
/// the marker alone when the card has no notes.
String notesWithMarker(String? notes, String marker) =>
    notes == null ? marker : '$notes\n\n$marker';

/// The codes in the first marker found anywhere in [notes], or `null` when
/// there is none.
({String cardCode, String occurrenceCode})? parseMarker(String? notes) {
  if (notes == null) return null;
  final match = _markerPattern.firstMatch(notes);
  if (match == null) return null;
  return (cardCode: match.group(1)!, occurrenceCode: match.group(2)!);
}
