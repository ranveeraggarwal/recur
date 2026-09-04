import 'package:flutter_test/flutter_test.dart';
import 'package:recur/core/id_generator.dart';

void main() {
  group('SequentialIdGenerator', () {
    test('yields id-1, id-2, ...', () {
      final generator = SequentialIdGenerator();
      expect(generator.next(), 'id-1');
      expect(generator.next(), 'id-2');
      expect(generator.next(), 'id-3');
    });

    test('reset starts the sequence over at id-1', () {
      final generator = SequentialIdGenerator();
      generator.next();
      generator.next();
      generator.reset();
      expect(generator.next(), 'id-1');
    });
  });

  group('UuidLikeIdGenerator', () {
    test('yields 32 lowercase hex characters', () {
      final generator = UuidLikeIdGenerator();
      final id = generator.next();
      expect(id.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });

    test('two calls return different ids', () {
      final generator = UuidLikeIdGenerator();
      final first = generator.next();
      final second = generator.next();
      expect(first, isNot(second));
    });
  });
}
