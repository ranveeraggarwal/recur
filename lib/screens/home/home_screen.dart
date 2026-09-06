import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/clock.dart';
import '../../core/formatting.dart';
import '../../data/booking_sync.dart';
import '../../data/models/event_type.dart';
import '../../theme/tokens.dart';
import '../../widgets/event_card.dart';
import '../../widgets/recur_fab.dart';
import '../booking/booking_screen.dart';
import '../booking/calendar_picker_sheet.dart';
import '../editor/editor_screen.dart';

/// Height of one Home grid tile at text scale 1. Multiplied by the current
/// text scale so a card that grows with the system font size still fits.
const double _cardHeight = 148;

/// The app's landing screen: a two-column grid of cards, one per event
/// type, or an empty state when there are none.
///
/// Reads its dependencies only through `AppScope.of(context)`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeCard {
  const _HomeCard({required this.eventType, required this.latestStart});

  final EventType eventType;

  /// The start of the most recent booking for [eventType], or `null` if it
  /// has never been booked.
  final DateTime? latestStart;
}

class _HomeLoad {
  const _HomeLoad({required this.cards, required this.writableCalendarCount});

  final List<_HomeCard> cards;
  final int writableCalendarCount;
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  AppDependencies? _deps;

  /// The last load that succeeded, kept while the next one runs so a reload
  /// never blanks an already-drawn grid.
  _HomeLoad? _data;

  /// Set when the most recent load threw, cleared when one succeeds.
  Object? _error;

  /// Bumped by every [_reload] so a slow earlier load cannot overwrite the
  /// result of a later one.
  int _loadGeneration = 0;

  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deps = AppScope.of(context);
    if (!_loadStarted) {
      _loadStarted = true;
      unawaited(_reload());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    // A resume while Booking or the Editor is on top would reload Home
    // underneath for nothing; those screens reload it when they pop.
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    unawaited(_reload());
  }

  Future<_HomeLoad> _load() async {
    final deps = _deps!;
    var access = await deps.calendar.checkAccess();
    if (access == CalendarAccess.notDetermined) {
      // Not asked yet: show the OS permission dialog now, rather than
      // waiting for the user to open Booking.
      access = await deps.calendar.requestAccess();
    }

    // An event deleted in the calendar app leaves its booking behind, so
    // drop those before the cards read their last-booked line.
    await pruneVanishedBookings(
      bookings: deps.bookings,
      calendar: deps.calendar,
    );

    final eventTypes = await deps.eventTypes.getAll();
    final cards = <_HomeCard>[];
    for (final eventType in eventTypes) {
      final latest = await deps.bookings.latestForEventType(eventType.id);
      cards.add(_HomeCard(eventType: eventType, latestStart: latest?.start));
    }

    // Listing calendars without access throws on a real phone, so only ask
    // when access was granted.
    final writableCalendarCount = access == CalendarAccess.granted
        ? (await deps.calendar.listWritableCalendars()).length
        : 0;
    return _HomeLoad(
      cards: cards,
      writableCalendarCount: writableCalendarCount,
    );
  }

  Future<void> _reload() async {
    final generation = ++_loadGeneration;
    try {
      final data = await _load();
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _error = error;
      });
    }
  }

  Future<void> _openEditor(String? eventTypeId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditorScreen(eventTypeId: eventTypeId),
      ),
    );
    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _openBooking(String eventTypeId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingScreen(eventTypeId: eventTypeId),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recur', style: RecurText.display),
        actions: [
          if ((data?.writableCalendarCount ?? 0) >= 2)
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: 'Choose calendar',
              onPressed: () => unawaited(showCalendarPicker(context)),
            ),
        ],
      ),
      body: _error != null
          ? const _HomeReadError()
          : _HomeBody(
              data: data,
              clock: _deps!.clock,
              onOpenBooking: (id) => unawaited(_openBooking(id)),
              onOpenEditor: (id) => unawaited(_openEditor(id)),
            ),
      floatingActionButton: RecurFab(
        onPressed: () => unawaited(_openEditor(null)),
      ),
    );
  }
}

/// Shown when the stored cards could not be read, in place of the grid.
class _HomeReadError extends StatelessWidget {
  const _HomeReadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't read your cards.", style: RecurText.title),
          const SizedBox(height: RecurSpacing.sm),
          Text(
            'Restart Recur to try again.',
            style: RecurText.body.copyWith(color: RecurColors.muted),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.data,
    required this.clock,
    required this.onOpenBooking,
    required this.onOpenEditor,
  });

  final _HomeLoad? data;
  final Clock clock;

  /// Called with the tapped card's event type id.
  final ValueChanged<String> onOpenBooking;

  /// Called with the long-pressed card's event type id, or `null` from the
  /// FAB.
  final ValueChanged<String?> onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    if (data.cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No events yet.', style: RecurText.title),
            const SizedBox(height: RecurSpacing.sm),
            Text(
              'Tap + to add one.',
              style: RecurText.body.copyWith(color: RecurColors.muted),
            ),
          ],
        ),
      );
    }

    final now = clock.now();
    // The card's content grows with the system font size, so the tile has
    // to grow with it too; a fixed aspect ratio overflows at 1.3 and up.
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return GridView.builder(
      padding: const EdgeInsets.all(RecurSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RecurSpacing.lg,
        mainAxisSpacing: RecurSpacing.lg,
        mainAxisExtent: _cardHeight * textScale,
      ),
      itemCount: data.cards.length,
      itemBuilder: (context, index) {
        final card = data.cards[index];
        final column = index.isEven ? CardColumn.one : CardColumn.two;
        final latestStart = card.latestStart;
        final lastBookedIsFuture =
            latestStart != null && latestStart.isAfter(now);

        return EventCard(
          name: card.eventType.name,
          durationMinutes: card.eventType.durationMinutes,
          location: card.eventType.location,
          lastBookedText: formatLastBooked(latestStart: latestStart, now: now),
          lastBookedIsFuture: lastBookedIsFuture,
          column: column,
          onTap: () => onOpenBooking(card.eventType.id),
          onLongPress: () => onOpenEditor(card.eventType.id),
        );
      },
    );
  }
}
