import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/clock.dart';
import '../../core/formatting.dart';
import '../../data/models/event_type.dart';
import '../../history/history_scan.dart';
import '../../history/marker.dart';
import '../../suggestions/first_suggested_slot.dart';
import '../../suggestions/suggestion_engine.dart';
import '../../theme/tokens.dart';
import '../../widgets/access_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/recur_fab.dart';
import '../editor/editor_screen.dart';

/// Height of one Home grid tile at text scale 1. Multiplied by the current
/// text scale so a card that grows with the system font size still fits.
const double _cardHeight = 148;

/// The app's landing screen: a two-column grid of cards, one per event
/// type, or an empty state when there are none. Tapping a card opens the
/// calendar app on a new event at a suggested time.
///
/// Reads its dependencies only through `AppScope.of(context)`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  AppDependencies? _deps;

  /// The cards from the last load that succeeded, kept while the next one
  /// runs so a reload never blanks an already-drawn grid.
  List<EventType>? _cards;

  CalendarAccess? _access;

  /// Set when the most recent load threw, cleared when one succeeds.
  Object? _error;

  /// The scan running now, or the one that last ran.
  HistorySnapshot? _live;

  /// The last scan that finished, shown for any card the running scan has
  /// not settled yet, so a reload does not blank every card's line.
  HistorySnapshot? _shown;

  StreamSubscription<HistorySnapshot>? _scan;

  /// Card codes seen in any scan this session, so a new card's code never
  /// matches a deleted card's events.
  final Set<String> _seenCardCodes = {};

  /// Bumped by every [_reload] so a slow earlier load cannot overwrite the
  /// result of a later one.
  int _loadGeneration = 0;

  bool _loadStarted = false;

  /// Busy times over the suggestion range, read on each load ahead of the
  /// scan. A tap uses whatever is here and never waits for a read: a wrong
  /// suggestion is fixed in the calendar app, a frozen tap is not.
  List<BusyInterval> _busy = const [];

  /// Set while the calendar app is being opened, so a double tap opens it
  /// once.
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scan?.cancel());
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
    // A resume while the Editor is on top would reload Home underneath for
    // nothing; it reloads Home when it pops. Coming back from the calendar
    // app lands here, which is how a just-saved event shows up.
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    unawaited(_reload());
  }

  /// Gives every card without a code one that no card has and no scan has
  /// seen, and saves it.
  Future<List<EventType>> _withCodes(List<EventType> cards) async {
    final deps = _deps!;
    final taken = {
      ..._seenCardCodes,
      for (final card in cards)
        if (card.code != null) card.code!,
    };
    final result = <EventType>[];
    for (final card in cards) {
      if (card.code != null) {
        result.add(card);
        continue;
      }
      final code = newCardCode(deps.random, taken);
      taken.add(code);
      final coded = card.copyWith(code: code);
      await deps.eventTypes.upsert(coded);
      result.add(coded);
    }
    return result;
  }

  Future<void> _reload() async {
    final deps = _deps!;
    final generation = ++_loadGeneration;
    try {
      var access = await deps.calendar.checkAccess();
      if (access == CalendarAccess.notDetermined) {
        // Not asked yet: show the OS permission dialog straight away.
        access = await deps.calendar.requestAccess();
      }
      final cards = await _withCodes(await deps.eventTypes.getAll());
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _cards = cards;
        _access = access;
        _error = null;
      });
      // Asked for before the scan so it is not queued behind a year of
      // events; the plugin answers one read at a time.
      if (access == CalendarAccess.granted) {
        unawaited(_loadBusy(generation));
      }
      _startScan(cards);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _error = error;
      });
    }
  }

  Future<void> _loadBusy(int generation) async {
    final range = suggestionSearchRange(_deps!.clock.now());
    try {
      final busy = await _deps!.calendar.busyIntervals(
        from: range.from,
        to: range.to,
      );
      if (mounted && generation == _loadGeneration) {
        _busy = busy;
      }
    } catch (_) {
      // A suggestion that ignores busy times still beats no event.
    }
  }

  void _startScan(List<EventType> cards) {
    final deps = _deps!;
    unawaited(_scan?.cancel());
    if (_live != null && _live!.done) {
      _shown = _live;
    }
    setState(() {
      _live = HistorySnapshot.initial;
    });
    _scan =
        scanHistory(
          calendar: deps.calendar,
          now: deps.clock.now(),
          cardCodes: {
            for (final card in cards)
              if (card.code != null) card.code!,
          },
        ).listen((snapshot) {
          if (!mounted) return;
          _seenCardCodes.addAll(snapshot.seenCardCodes);
          setState(() {
            _live = snapshot;
            if (snapshot.done) {
              _shown = snapshot;
            }
          });
        });
  }

  /// The snapshot to read [code]'s history from: the running scan once it
  /// has settled that card, else the last finished scan, else the running
  /// one.
  HistorySnapshot? _historySource(String? code) {
    final live = _live;
    if (live != null && live.isSettled(code)) return live;
    return _shown ?? live;
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

  Future<void> _requestAccess() async {
    await _deps!.calendar.requestAccess();
    await _reload();
  }

  Future<void> _openSettings() async {
    await _deps!.calendar.openSystemSettings();
  }

  Future<void> _book(EventType card) async {
    if (_opening) return;
    _opening = true;
    final deps = _deps!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Everything up to opening the calendar app uses what Home already
      // has in memory, so the tap answers at once even mid-scan.
      final now = deps.clock.now();
      final past = _historySource(card.code)?.historyFor(card.code).past;
      final window = suggestionWindowFor(
        eventType: card,
        occurrences: past ?? const [],
        now: now,
      );
      final slot = firstSuggestedSlot(
        eventType: card,
        window: window,
        busy: _access == CalendarAccess.granted ? _busy : const [],
        now: now,
      );

      // Load gives every card a code before it is drawn; this only guards
      // against that changing, checking against every card.
      final cardCode =
          card.code ??
          (await _withCodes(_cards!)).firstWhere((c) => c.id == card.id).code!;
      final marker = markerLine(
        cardCode: cardCode,
        occurrenceCode: randomCode(deps.random, occurrenceCodeLength),
      );

      await deps.calendar.openNewEvent(
        title: card.name,
        start: slot.start,
        end: slot.end,
        location: card.location,
        notes: notesWithMarker(card.notes, marker),
      );
    } on CalendarOpenException {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open your calendar.")),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    final scanning = live != null && !live.done;
    final access = _access;
    final showAccess =
        _error == null && access != null && access != CalendarAccess.granted;

    return Scaffold(
      appBar: AppBar(title: const Text('Recur', style: RecurText.display)),
      body: Stack(
        children: [
          if (_error != null)
            const _HomeReadError()
          else
            Column(
              children: [
                if (showAccess)
                  Padding(
                    padding: const EdgeInsets.only(top: RecurSpacing.xl),
                    child: AccessState(
                      access: access,
                      hasWritableCalendar: true,
                      message:
                          'Recur needs calendar access to see what you have '
                          'booked.',
                      onRequestAccess: () => unawaited(_requestAccess()),
                      onOpenSettings: () => unawaited(_openSettings()),
                    ),
                  ),
                Expanded(
                  child: _HomeBody(
                    cards: _cards,
                    clock: _deps!.clock,
                    lineFor: _lineFor,
                    onBook: (card) => unawaited(_book(card)),
                    onOpenEditor: (id) => unawaited(_openEditor(id)),
                  ),
                ),
              ],
            ),
          if (scanning)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: live.progress,
                minHeight: RecurSizes.progressBar,
                color: RecurColors.primary,
                backgroundColor: RecurColors.divider,
              ),
            ),
        ],
      ),
      floatingActionButton: RecurFab(
        onPressed: () => unawaited(_openEditor(null)),
      ),
    );
  }

  /// The start [card]'s line describes, and whether a line is known yet.
  ({bool known, DateTime? start}) _lineFor(EventType card) {
    final source = _historySource(card.code);
    if (source == null || !source.hasAccess || !source.isSettled(card.code)) {
      return (known: false, start: null);
    }
    return (known: true, start: source.historyFor(card.code).lineStart);
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
    required this.cards,
    required this.clock,
    required this.lineFor,
    required this.onBook,
    required this.onOpenEditor,
  });

  final List<EventType>? cards;
  final Clock clock;
  final ({bool known, DateTime? start}) Function(EventType card) lineFor;

  /// Called with the tapped card.
  final ValueChanged<EventType> onBook;

  /// Called with the long-pressed card's event type id, or `null` from the
  /// FAB.
  final ValueChanged<String?> onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final cards = this.cards;
    if (cards == null) {
      return const SizedBox.shrink();
    }

    if (cards.isEmpty) {
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
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final column = index.isEven ? CardColumn.one : CardColumn.two;
        final line = lineFor(card);
        final start = line.start;

        return EventCard(
          name: card.name,
          durationMinutes: card.durationMinutes,
          location: card.location,
          lastBookedText: line.known
              ? formatLastBooked(latestStart: start, now: now)
              : '',
          lastBookedIsFuture: start != null && start.isAfter(now),
          column: column,
          onTap: () => onBook(card),
          onLongPress: () => onOpenEditor(card.id),
        );
      },
    );
  }
}
