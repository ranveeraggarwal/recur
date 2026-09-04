import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recur/data/models/app_settings.dart';

void main() {
  group('AppSettings.empty', () {
    test('has a null selectedCalendarId', () {
      expect(AppSettings.empty.selectedCalendarId, isNull);
    });
  });

  group('AppSettings JSON shape', () {
    test('toJson matches the excerpt sample byte for byte', () {
      const settings = AppSettings(selectedCalendarId: '1');
      expect(jsonEncode(settings.toJson()), '{"selectedCalendarId":"1"}');
    });

    test('toJson emits null when unset', () {
      expect(AppSettings.empty.toJson(), {'selectedCalendarId': null});
    });

    test('fromJson parses the literal excerpt sample', () {
      const source = '{"selectedCalendarId":"1"}';
      final settings = AppSettings.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
      expect(settings.selectedCalendarId, '1');
    });

    test('fromJson accepts a null selectedCalendarId', () {
      const source = '{"selectedCalendarId":null}';
      final settings = AppSettings.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
      expect(settings.selectedCalendarId, isNull);
    });
  });

  group('AppSettings round trip', () {
    test('jsonEncode/jsonDecode round trips to an equal instance', () {
      const settings = AppSettings(selectedCalendarId: '1');
      final decoded = AppSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, settings);
    });
  });

  group('AppSettings equality and hashCode', () {
    test('two instances with the same field values are equal', () {
      const a = AppSettings(selectedCalendarId: '1');
      const b = AppSettings(selectedCalendarId: '1');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differ when selectedCalendarId differs', () {
      const a = AppSettings(selectedCalendarId: '1');
      const b = AppSettings(selectedCalendarId: '2');
      expect(a, isNot(b));
    });

    test('AppSettings.empty equals a plain instance with a null id', () {
      const other = AppSettings(selectedCalendarId: null);
      expect(AppSettings.empty, other);
    });
  });

  group('AppSettings.copyWith', () {
    test('sets a new value', () {
      final copy = AppSettings.empty.copyWith(selectedCalendarId: '1');
      expect(copy.selectedCalendarId, '1');
    });

    test('keeps the original value when nothing is given', () {
      const settings = AppSettings(selectedCalendarId: '1');
      expect(settings.copyWith(), settings);
    });

    test('can explicitly clear the value back to null', () {
      const settings = AppSettings(selectedCalendarId: '1');
      final copy = settings.copyWith(selectedCalendarId: null);
      expect(copy.selectedCalendarId, isNull);
    });
  });
}
