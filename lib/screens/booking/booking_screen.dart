import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/formatting.dart';
import '../../data/models/event_type.dart';
import '../../suggestions/slot_grid.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm_button.dart';
import 'booking_controller.dart';
import 'day_strip.dart';
import 'timeline.dart';

/// The week view for one card: day strip, timeline, and (from #23) the
/// confirm flow. Reads its dependencies only through `AppScope.of(context)`.
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final eventType = _eventType;
    if (_loading || controller == null || eventType == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final slots = controller.grids[controller.selectedDate] ?? const [];
    final selectedSlot = controller.selectedSlot;
    final subtitle = [
      formatDuration(eventType.durationMinutes),
      if (eventType.location != null) eventType.location!,
    ].join(' · ');
    final backDisabled = controller.weekMonday == controller.today.mondayOfWeek;

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
      body: Column(
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
              scrollController: _scrollController,
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
            // TODO(#23): enable once confirm() is implemented.
            button: const ConfirmButton(label: 'Confirm', onPressed: null),
          ),
        ],
      ),
    );
  }
}
