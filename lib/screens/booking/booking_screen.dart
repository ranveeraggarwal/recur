import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/formatting.dart';
import '../../data/models/event_type.dart';
import '../../suggestions/slot_grid.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm_button.dart';
import 'booking_controller.dart';
import 'calendar_picker_sheet.dart';
import 'confirmation_sheet.dart';
import 'day_strip.dart';
import 'timeline.dart';

/// The week view for one card: day strip, timeline, and the confirm flow.
/// Reads its dependencies only through `AppScope.of(context)`.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.eventTypeId});

  final String eventTypeId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  BookingController? _controller;
  EventType? _eventType;
  ScrollController? _scrollController;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !_loading) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final deps = AppScope.of(context);
    final eventType = await deps.eventTypes.getById(widget.eventTypeId);
    if (eventType == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final controller = BookingController(eventType: eventType, deps: deps);
    controller.addListener(_onControllerChanged);
    await controller.init();
    if (!mounted) return;

    setState(() {
      _eventType = eventType;
      _controller = controller;
      _scrollController = ScrollController(
        initialScrollOffset: _initialOffset(controller),
      );
      _loading = false;
    });
  }

  double _initialOffset(BookingController controller) {
    final slots = controller.grids[controller.selectedDate] ?? const [];
    final highlightedIndex = slots.indexWhere(
      (s) => s.state == SlotState.highlighted,
    );
    final eightAmIndex = slots.indexWhere((s) => s.startMinutes == 480);
    final index = highlightedIndex >= 0
        ? highlightedIndex
        : (eightAmIndex >= 0 ? eightAmIndex : 0);
    return index * RecurSizes.slotRow;
  }

  void _onControllerChanged() => setState(() {});

  @override
  void dispose() {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add to calendar.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          ? _AccessState(
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
        SizedBox(
          height: 72,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous week',
                onPressed: backDisabled
                    ? null
                    : () => controller.showWeek(
                        controller.weekMonday.addDays(-7),
                      ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    formatWeekOf(controller.weekMonday),
                    style: RecurText.label,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week',
                onPressed: () =>
                    controller.showWeek(controller.weekMonday.addDays(7)),
              ),
            ],
          ),
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

/// Replaces the header, day strip, and timeline (no confirm bar) when
/// calendar access is missing or there is no writable calendar.
class _AccessState extends StatelessWidget {
  const _AccessState({
    required this.access,
    required this.hasWritableCalendar,
    required this.onRequestAccess,
    required this.onOpenSettings,
  });

  final CalendarAccess access;
  final bool hasWritableCalendar;
  final VoidCallback onRequestAccess;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final String message;
    String? buttonLabel;
    VoidCallback? onPressed;

    if (access == CalendarAccess.notDetermined) {
      message = 'Recur needs calendar access to show your week.';
      buttonLabel = 'Allow calendar access';
      onPressed = onRequestAccess;
    } else if (access == CalendarAccess.denied) {
      message = 'Calendar access is off for Recur.';
      buttonLabel = 'Open settings';
      onPressed = onOpenSettings;
    } else {
      message = 'No writable calendar found.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: RecurText.body, textAlign: TextAlign.center),
            if (buttonLabel != null) ...[
              const SizedBox(height: RecurSpacing.lg),
              SizedBox(
                width: 220,
                child: ConfirmButton(label: buttonLabel, onPressed: onPressed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
