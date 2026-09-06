import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/formatting.dart';
import '../../core/local_date.dart';
import '../../data/models/event_type.dart';
import '../../theme/tokens.dart';
import '../../widgets/access_state.dart';
import '../../widgets/confirm_button.dart';
import '../../widgets/week_header.dart';
import 'booking_controller.dart';
import 'calendar_picker_sheet.dart';
import 'confirmation_sheet.dart';
import 'day_strip.dart';
import 'timeline.dart';

/// The week view for one card: day strip, timeline, and the confirm bar.
/// Reads its dependencies only through `AppScope.of(context)`.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.eventTypeId});

  final String eventTypeId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with WidgetsBindingObserver {
  BookingController? _controller;
  EventType? _eventType;
  ScrollController? _scrollController;
  LocalDate? _shownDate;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !_loading) return;
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Back from hours in the background: "now" has moved, so the past
    // slots and today's pill have to move with it.
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller?.refresh() ?? Future<void>.value());
    }
  }

  Future<void> _load() async {
    final deps = AppScope.of(context);
    try {
      final eventType = await deps.eventTypes.getById(widget.eventTypeId);
      if (!mounted) return;
      if (eventType == null) {
        // The card was deleted while this route sat on the back stack.
        // There is nothing to book, so leave rather than show an empty
        // screen with no way out.
        Navigator.of(context).pop();
        return;
      }

      final controller = BookingController(eventType: eventType, deps: deps);
      await controller.init();
      if (!mounted) return;

      controller.addListener(_onControllerChanged);
      setState(() {
        _eventType = eventType;
        _controller = controller;
        _shownDate = controller.selectedDate;
        _scrollController = ScrollController(
          initialScrollOffset: initialTimelineOffset(
            controller.grids[controller.selectedDate] ?? const [],
          ),
        );
        _loading = false;
      });
    } catch (_) {
      // An unreadable card or calendar: say so, with an app bar to leave by.
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _onControllerChanged() {
    _jumpToSelectedDay();
    setState(() {});
  }

  /// Brings each day's own offset into view, the way the screen opened at
  /// the first day's, so a card that prefers 16:00 on Wednesdays does not
  /// leave the user scrolling for the cedar edge.
  ///
  /// Only on a day change: a slot toggle notifies too, but keeps the day it
  /// is on. And only when that offset is off screen, so tapping along the
  /// day strip does not shuffle the rows under the user's eyes when the
  /// day's first good slot is already in front of them.
  void _jumpToSelectedDay() {
    final controller = _controller;
    final scrollController = _scrollController;
    if (controller == null || scrollController == null) return;
    if (controller.selectedDate == _shownDate) return;

    _shownDate = controller.selectedDate;
    if (!scrollController.hasClients) return;

    final position = scrollController.position;
    final target = initialTimelineOffset(
      controller.grids[controller.selectedDate] ?? const [],
    ).clamp(0.0, position.maxScrollExtent);

    final visibleFrom = position.pixels;
    final visibleTo = visibleFrom + position.viewportDimension;
    if (target >= visibleFrom && target + RecurSizes.slotRow <= visibleTo) {
      return;
    }

    scrollController.jumpTo(target);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    _scrollController?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final controller = _controller!;
    final slot = controller.selectedSlot;
    if (slot == null) return;

    var calendarId = controller.calendarIdToUse;
    if (calendarId == null && controller.writableCalendarCount >= 2) {
      calendarId = await showCalendarPicker(context);
      if (!mounted) return;
      await controller.refreshSettings();
    }
    if (calendarId == null) return;

    try {
      await controller.confirm(calendarId: calendarId);
      if (!mounted) return;
      await showConfirmationSheet(
        context,
        summary: formatDaySpan(
          date: slot.date,
          startMinutes: slot.startMinutes,
          endMinutes: slot.endMinutes,
        ),
        eventTypeName: controller.eventType.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That slot has passed. Pick another.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add to calendar.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: RecurSpacing.xxl),
            child: Text(
              "Couldn't open this card.",
              style: RecurText.body,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    final eventType = _eventType;
    if (_loading || controller == null || eventType == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final subtitle = [
      formatDuration(eventType.durationMinutes),
      if (eventType.location != null) eventType.location!,
    ].join(' · ');

    final needsAccess =
        controller.access != CalendarAccess.granted ||
        !controller.hasWritableCalendar;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eventType.name, style: RecurText.title),
            Text(
              subtitle,
              style: RecurText.caption.copyWith(color: RecurColors.muted),
            ),
          ],
        ),
      ),
      body: needsAccess
          ? AccessState(
              access: controller.access,
              hasWritableCalendar: controller.hasWritableCalendar,
              onRequestAccess: () => controller.requestAccess(),
              onOpenSettings: () => controller.openSettings(),
            )
          : _BookingBody(
              controller: controller,
              scrollController: _scrollController,
              onConfirm: _confirm,
            ),
    );
  }
}

class _BookingBody extends StatelessWidget {
  const _BookingBody({
    required this.controller,
    required this.scrollController,
    required this.onConfirm,
  });

  final BookingController controller;
  final ScrollController? scrollController;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final slots = controller.grids[controller.selectedDate] ?? const [];
    final selectedSlot = controller.selectedSlot;
    final backDisabled = controller.weekMonday == controller.today.mondayOfWeek;

    return Column(
      children: [
        WeekHeader(
          weekMonday: controller.weekMonday,
          onPrevious: backDisabled
              ? null
              : () => controller.showWeek(controller.weekMonday.addDays(-7)),
          onNext: () => controller.showWeek(controller.weekMonday.addDays(7)),
        ),
        DayStrip(
          weekMonday: controller.weekMonday,
          selectedDate: controller.selectedDate,
          today: controller.today,
          grids: controller.grids,
          onSelect: controller.selectDate,
        ),
        const SizedBox(height: RecurSpacing.md),
        const Divider(height: 1, thickness: 1, color: RecurColors.divider),
        Expanded(
          child: Timeline(
            slots: slots,
            selectedSlot: selectedSlot,
            onToggle: controller.toggleSlot,
            scrollController: scrollController,
          ),
        ),
        ConfirmBar(
          summary: selectedSlot == null
              ? 'Pick a slot'
              : formatDaySpan(
                  date: selectedSlot.date,
                  startMinutes: selectedSlot.startMinutes,
                  endMinutes: selectedSlot.endMinutes,
                ),
          button: ConfirmButton(
            label: 'Confirm',
            onPressed: selectedSlot == null || controller.isConfirming
                ? null
                : onConfirm,
            busy: controller.isConfirming,
          ),
        ),
      ],
    );
  }
}
