import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/clock.dart';
import '../../core/formatting.dart';
import '../../data/models/event_type.dart';
import '../../theme/tokens.dart';
import '../../widgets/event_card.dart';
import '../../widgets/recur_fab.dart';
import '../booking/calendar_picker_sheet.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  AppDependencies? _deps;
  Future<_HomeLoad>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deps = AppScope.of(context);
    _future ??= _load();
  }

  Future<_HomeLoad> _load() async {
    final deps = _deps!;
    final eventTypes = await deps.eventTypes.getAll();
    final cards = <_HomeCard>[];
    for (final eventType in eventTypes) {
      final latest = await deps.bookings.latestForEventType(eventType.id);
      cards.add(_HomeCard(eventType: eventType, latestStart: latest?.start));
    }
    final calendars = await deps.calendar.listWritableCalendars();
    return _HomeLoad(cards: cards, writableCalendarCount: calendars.length);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openEditor(String? eventTypeId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _EditorPlaceholder(eventTypeId: eventTypeId),
      ),
    );
    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _openBooking(String eventTypeId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _BookingPlaceholder(eventTypeId: eventTypeId),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeLoad>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
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
          body: _HomeBody(
            data: data,
            clock: _deps!.clock,
            onOpenBooking: (id) => unawaited(_openBooking(id)),
            onOpenEditor: (id) => unawaited(_openEditor(id)),
          ),
          floatingActionButton: RecurFab(
            onPressed: () => unawaited(_openEditor(null)),
          ),
        );
      },
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

    return GridView.builder(
      padding: const EdgeInsets.all(RecurSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RecurSpacing.lg,
        mainAxisSpacing: RecurSpacing.lg,
        childAspectRatio: 166 / 148,
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

/// Stands in for the real Editor screen until it lands.
class _EditorPlaceholder extends StatelessWidget {
  const _EditorPlaceholder({this.eventTypeId});

  final String? eventTypeId;

  @override
  Widget build(BuildContext context) {
    // TODO(#21): replace with the real EditorScreen.
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: const Center(child: Text('Editor placeholder')),
    );
  }
}

/// Stands in for the real Booking screen until it lands.
class _BookingPlaceholder extends StatelessWidget {
  const _BookingPlaceholder({required this.eventTypeId});

  final String eventTypeId;

  @override
  Widget build(BuildContext context) {
    // TODO(#22): replace with the real BookingScreen.
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: const Center(child: Text('Booking placeholder')),
    );
  }
}
