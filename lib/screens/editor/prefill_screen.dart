import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/local_date.dart';
import '../../core/time_of_day_minutes.dart';
import '../../theme/tokens.dart';
import '../../widgets/access_state.dart';
import '../../widgets/day_pill.dart';
import '../../widgets/week_header.dart';
import 'event_prefill.dart';

/// How far back and forward the picker reads the calendar. The chevrons
/// stop at the weeks holding these edges, so a week on screen is always a
/// week that was actually read.
const Duration prefillLookBack = Duration(days: 90);
const Duration prefillLookAhead = Duration(days: 30);

const List<String> _weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// One hour of the timeline. Twice a Booking slot row, so an hour here is
/// as tall as the two 30-minute rows it would be over there.
const double _hourHeight = RecurSizes.slotRow * 2;

/// A week of the phone calendar, to copy a new card from one of its
/// events. Pushed from the Editor; pops the chosen [EventPrefill], or
/// `null` when the user backs out.
///
/// A calendar rather than a list, because picking the right past
/// appointment is a "which Tuesday was that" question: the week and the
/// time of day are what you recognise it by.
class PrefillScreen extends StatefulWidget {
  const PrefillScreen({super.key});

  @override
  State<PrefillScreen> createState() => _PrefillScreenState();
}

class _PrefillScreenState extends State<PrefillScreen> {
  AppDependencies? _deps;
  bool _loading = true;
  CalendarAccess _access = CalendarAccess.notDetermined;
  List<CalendarEvent> _events = const [];

  late LocalDate _today;
  late LocalDate _weekMonday;
  late LocalDate _selectedDate;
  late LocalDate _firstMonday;
  late LocalDate _lastMonday;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deps != null) return;
    _deps = AppScope.of(context);
    _load();
  }

  Future<void> _load() async {
    final deps = _deps!;
    final now = deps.clock.now();
    _today = LocalDate.fromDateTime(now);
    _weekMonday = _today.mondayOfWeek;
    _selectedDate = _today;

    final from = now.subtract(prefillLookBack);
    final to = now.add(prefillLookAhead);
    _firstMonday = LocalDate.fromDateTime(from).mondayOfWeek;
    _lastMonday = LocalDate.fromDateTime(to).mondayOfWeek;

    var events = const <CalendarEvent>[];
    var access = CalendarAccess.notDetermined;
    try {
      access = await deps.calendar.checkAccess();
      if (access == CalendarAccess.granted) {
        events = await deps.calendar.listEvents(from: from, to: to);
      }
    } catch (_) {
      // A calendar that will not be read leaves the empty state below.
    }

    if (!mounted) return;
    setState(() {
      _events = events.where(canPrefillFrom).toList();
      _access = access;
      _loading = false;
    });
  }

  Future<void> _requestAccess() async {
    await _deps!.calendar.requestAccess();
    if (!mounted) return;
    await _load();
  }

  List<CalendarEvent> _eventsOn(LocalDate date) {
    final events =
        _events.where((e) => LocalDate.fromDateTime(e.start) == date).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  void _showWeek(LocalDate monday) {
    setState(() {
      _weekMonday = monday;
      _selectedDate = monday;
    });
  }

  void _pick(CalendarEvent event) {
    final prefill = prefillFor(event: event, allEvents: _events);
    if (prefill == null) return;
    Navigator.of(context).pop(prefill);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Copy from calendar')),
      body: _loading
          ? const SizedBox.shrink()
          : _access != CalendarAccess.granted
          ? AccessState(
              access: _access,
              // Copying only reads the calendar, so having one to write
              // to is not this screen's problem.
              hasWritableCalendar: true,
              onRequestAccess: _requestAccess,
              onOpenSettings: () => _deps!.calendar.openSystemSettings(),
              message: 'Recur needs calendar access to copy an event.',
            )
          : _events.isEmpty
          ? const _EmptyMessage('Nothing in your calendar to copy.')
          : _body(),
    );
  }

  Widget _body() {
    return Column(
      children: [
        WeekHeader(
          weekMonday: _weekMonday,
          onPrevious: _weekMonday.compareTo(_firstMonday) <= 0
              ? null
              : () => _showWeek(_weekMonday.addDays(-7)),
          onNext: _weekMonday.compareTo(_lastMonday) >= 0
              ? null
              : () => _showWeek(_weekMonday.addDays(7)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.lg),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: Center(child: _pillFor(i))),
            ],
          ),
        ),
        const SizedBox(height: RecurSpacing.md),
        const Divider(height: 1, thickness: 1, color: RecurColors.divider),
        Expanded(
          child: _DayTimeline(
            // A fresh timeline per day, so each one opens scrolled to its
            // own first event.
            key: ValueKey(_selectedDate),
            events: _eventsOn(_selectedDate),
            onPick: _pick,
          ),
        ),
      ],
    );
  }

  Widget _pillFor(int index) {
    final date = _weekMonday.addDays(index);
    return DayPill(
      weekdayLabel: _weekdayLabels[index],
      dayNumber: date.day,
      selected: date == _selectedDate,
      // Every day is pickable here: copying looks backwards, so a past
      // day is the likely one.
      enabled: true,
      hasSuggestions: _eventsOn(date).isNotEmpty,
      isToday: date == _today,
      onTap: () => setState(() => _selectedDate = date),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xxl),
        child: Text(
          message,
          style: RecurText.body.copyWith(color: RecurColors.muted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// One day's events, drawn on an hour grid like the Booking timeline.
///
/// The grid runs 06:00 to 22:00, widened to whatever hours the day's
/// events actually need, so an early or late event is never off the grid
/// and out of reach.
class _DayTimeline extends StatefulWidget {
  const _DayTimeline({super.key, required this.events, required this.onPick});

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onPick;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  late final ScrollController _scrollController;
  late final int _startHour;
  late final int _endHour;

  @override
  void initState() {
    super.initState();
    final bounds = _hourBounds(widget.events);
    _startHour = bounds.$1;
    _endHour = bounds.$2;
    _scrollController = ScrollController(initialScrollOffset: _initialOffset());
  }

  /// Opens on the day's first event, a little above it so the hour before
  /// is visible too.
  double _initialOffset() {
    if (widget.events.isEmpty) return 0;
    final first = minutesOfDay(widget.events.first.start);
    final offset = (first - _startHour * 60) / 60 * _hourHeight - _hourHeight;
    return offset < 0 ? 0 : offset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const _EmptyMessage('Nothing on this day.');
    }

    final totalHeight = (_endHour - _startHour) * _hourHeight;

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            for (var hour = _startHour; hour < _endHour; hour++)
              Positioned(
                left: 0,
                right: 0,
                top: (hour - _startHour) * _hourHeight,
                child: _HourLine(hour: hour),
              ),
            for (final placed in _placeEvents(widget.events))
              _positioned(placed, context),
          ],
        ),
      ),
    );
  }

  Widget _positioned(_PlacedEvent placed, BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - RecurSizes.hourGutter;
    final columnWidth =
        (width - RecurSpacing.lg) / placed.columns - RecurSpacing.xs;
    final top = (placed.startMinutes - _startHour * 60) / 60 * _hourHeight;
    final height = placed.durationMinutes / 60 * _hourHeight;

    return Positioned(
      top: top,
      left:
          RecurSizes.hourGutter +
          placed.column * (columnWidth + RecurSpacing.xs),
      width: columnWidth,
      height: height < _minBlockHeight ? _minBlockHeight : height,
      child: _EventBlock(
        event: placed.event,
        onTap: () => widget.onPick(placed.event),
      ),
    );
  }
}

/// Short enough to read a name on, tall enough to tap.
const double _minBlockHeight = 40;

/// Tall enough for the time-and-place line under the name.
const double _twoLineBlockHeight = 56;

/// The hours the grid must cover: 06:00 to 22:00, stretched to hold every
/// event of the day.
(int, int) _hourBounds(List<CalendarEvent> events) {
  var start = dayStartMinutes ~/ 60;
  var end = dayEndMinutes ~/ 60;
  for (final event in events) {
    final from = minutesOfDay(event.start) ~/ 60;
    final rawEnd = minutesOfDay(event.start) + event.durationMinutes;
    final to = (rawEnd > 1440 ? 1440 : rawEnd) / 60;
    if (from < start) start = from;
    if (to.ceil() > end) end = to.ceil();
  }
  return (start, end > 24 ? 24 : end);
}

/// An event with the column it sits in, so two overlapping events share
/// the width instead of hiding each other.
final class _PlacedEvent {
  const _PlacedEvent({
    required this.event,
    required this.column,
    required this.columns,
  });

  final CalendarEvent event;
  final int column;
  final int columns;

  int get startMinutes => minutesOfDay(event.start);

  int get durationMinutes {
    final end = startMinutes + event.durationMinutes;
    return (end > 1440 ? 1440 : end) - startMinutes;
  }
}

/// Lays [events] (sorted by start) into columns: each run of events that
/// overlap each other is split across as many columns as it needs, and
/// every event in the run reports that same column count so they line up.
List<_PlacedEvent> _placeEvents(List<CalendarEvent> events) {
  final placed = <_PlacedEvent>[];
  var run = <CalendarEvent>[];
  final columnOf = <int>[];
  var runEnd = -1;

  void flushRun() {
    if (run.isEmpty) return;
    final columns = columnOf.reduce((a, b) => a > b ? a : b) + 1;
    for (var i = 0; i < run.length; i++) {
      placed.add(
        _PlacedEvent(event: run[i], column: columnOf[i], columns: columns),
      );
    }
    run = [];
    columnOf.clear();
    runEnd = -1;
  }

  // The end minute each open column is free after.
  var columnEnds = <int>[];

  for (final event in events) {
    final start = minutesOfDay(event.start);
    final end = start + event.durationMinutes;

    if (start >= runEnd) {
      flushRun();
      columnEnds = [];
    }

    var column = columnEnds.indexWhere((freeAt) => freeAt <= start);
    if (column == -1) {
      columnEnds.add(end);
      column = columnEnds.length - 1;
    } else {
      columnEnds[column] = end;
    }

    run.add(event);
    columnOf.add(column);
    if (end > runEnd) runEnd = end;
  }
  flushRun();

  return placed;
}

class _HourLine extends StatelessWidget {
  const _HourLine({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: RecurSizes.hourGutter,
            child: Padding(
              padding: const EdgeInsets.only(
                top: RecurSpacing.xs,
                left: RecurSpacing.sm,
              ),
              child: Text(
                formatMinutes(hour * 60),
                style: RecurText.caption.copyWith(color: RecurColors.muted),
              ),
            ),
          ),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: RecurColors.divider)),
              ),
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// One event on the timeline: a cedar-edged block you tap to copy.
class _EventBlock extends StatelessWidget {
  const _EventBlock({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = minutesOfDay(event.start);
    final rawEnd = start + event.durationMinutes;
    final end = rawEnd > 1440 ? 1440 : rawEnd;
    final detail = [
      '${formatMinutes(start)} to ${formatMinutes(end)}',
      if (event.location != null) event.location!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        // Surface under the 8% cedar wash, so the hour lines behind the
        // block do not show through it.
        color: RecurColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(RecurRadii.slot)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: RecurColors.primaryTint,
          highlightColor: RecurColors.primaryTint,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final roomForDetail =
                  constraints.maxHeight >= _twoLineBlockHeight;
              return Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: RecurColors.accentTint),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: RecurSizes.highlightBorder,
                      color: RecurColors.accent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      RecurSpacing.md,
                      RecurSpacing.xs,
                      RecurSpacing.sm,
                      RecurSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          style: RecurText.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (roomForDetail)
                          Text(
                            detail,
                            style: RecurText.caption.copyWith(
                              color: RecurColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
