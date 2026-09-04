/// A source of the current local time.
///
/// Production code depends on [Clock], never on `DateTime.now()` directly,
/// so tests can substitute [FixedClock] and control time precisely.
abstract interface class Clock {
  /// The current local wall-clock time.
  DateTime now();
}

/// A [Clock] backed by the real system time.
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

/// A [Clock] with a settable, advanceable time, for tests.
///
/// [Clock.now] is an interface *method*, so a class implementing [Clock]
/// cannot also declare a property setter named `now` — Dart does not allow
/// a method and an accessor to share a base name. [setNow] provides the
/// same behaviour as a plain method instead, alongside [advance] (see the
/// "Decisions" table in `docs/architecture.md`).
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock forward by [d].
  void advance(Duration d) => _now = _now.add(d);

  /// Sets the clock to [value].
  void setNow(DateTime value) => _now = value;
}
