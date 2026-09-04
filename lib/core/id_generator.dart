import 'dart:math';

/// A source of new unique identifiers.
abstract interface class IdGenerator {
  /// Returns the next id.
  String next();
}

/// An [IdGenerator] that returns 32 lowercase hex characters drawn from
/// [Random.secure].
class UuidLikeIdGenerator implements IdGenerator {
  final Random _random = Random.secure();

  static const String _hexDigits = '0123456789abcdef';

  @override
  String next() {
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(_hexDigits[_random.nextInt(16)]);
    }
    return buffer.toString();
  }
}

/// An [IdGenerator] that returns `id-1`, `id-2`, ... in order, for tests.
class SequentialIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String next() {
    _counter += 1;
    return 'id-$_counter';
  }

  /// Resets the counter so the next call to [next] returns `id-1` again.
  void reset() => _counter = 0;
}
