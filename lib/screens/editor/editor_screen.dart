import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/formatting.dart';
import '../../core/time_of_day_minutes.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm_button.dart';
import '../../widgets/duration_pill.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/recur_text_field.dart';
import 'editor_controller.dart';
import 'event_prefill.dart';
import 'prefill_screen.dart';

const List<String> _weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// A form for creating or editing one event type.
///
/// Pass `eventTypeId: null` for a new card, or an existing id to edit it.
/// Reads its dependencies only through `AppScope.of(context)`.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.eventTypeId});

  final String? eventTypeId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorController? _controller;

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late final TextEditingController _customDurationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController()
      ..addListener(() => _controller?.setName(_nameController.text));
    _locationController = TextEditingController()
      ..addListener(() => _controller?.setLocation(_locationController.text));
    _notesController = TextEditingController()
      ..addListener(() => _controller?.setNotes(_notesController.text));
    _customDurationController = TextEditingController()
      ..addListener(
        () =>
            _controller?.setCustomDurationText(_customDurationController.text),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;

    final controller = EditorController(
      deps: AppScope.of(context),
      eventTypeId: widget.eventTypeId,
    );
    controller.addListener(_onControllerChanged);
    _controller = controller;
    controller.load().then((_) {
      if (!mounted) return;
      _nameController.text = controller.name;
      _locationController.text = controller.location ?? '';
      _notesController.text = controller.notes ?? '';
      _customDurationController.text = controller.customDurationText;
    });
  }

  /// Rebuilds on every draft change, then keeps [_customDurationController]
  /// in sync with the draft's `customDurationText`. Setting `.text` is a
  /// no-op while the user is typing (the draft is a mirror of what they
  /// typed) and only fires when a duration pill rewrote the draft instead.
  void _onControllerChanged() {
    setState(() {});
    final controller = _controller!;
    if (_customDurationController.text != controller.customDurationText) {
      _customDurationController.text = controller.customDurationText;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _nameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  /// Opens the copy-from-calendar week view and, when the user picks an
  /// event, replaces the whole draft with it. The text fields are pushed
  /// their new values by hand: they own their own [TextEditingController]s
  /// and do not rebuild from the controller.
  Future<void> _copyFromCalendar() async {
    final controller = _controller!;
    final prefill = await Navigator.of(context).push<EventPrefill>(
      MaterialPageRoute(builder: (context) => const PrefillScreen()),
    );
    if (prefill == null || !mounted) return;

    controller.applyPrefill(prefill);
    _nameController.text = controller.name;
    _locationController.text = controller.location ?? '';
    _notesController.text = controller.notes ?? '';
  }

  Future<void> _save() async {
    final controller = _controller!;
    await controller.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final controller = _controller!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${controller.name}"?'),
        content: const Text(
          'Past bookings are removed from Recur. '
          'Calendar events are not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.delete();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || controller.loading) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isNew ? 'New event' : 'Edit event'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RecurSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RecurSpacing.xl,
                children: [
                  if (controller.isNew)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _copyFromCalendar,
                        icon: const Icon(Icons.event_outlined, size: 20),
                        label: const Text('Copy from calendar'),
                        style: TextButton.styleFrom(
                          foregroundColor: RecurColors.primary,
                        ),
                      ),
                    ),
                  RecurTextField(
                    label: 'Name',
                    controller: _nameController,
                    placeholder: 'PT session',
                    maxLength: 40,
                    errorText: controller.nameError,
                  ),
                  _DurationGroup(
                    controller: controller,
                    customDurationController: _customDurationController,
                  ),
                  LocationAutocompleteField(
                    controller: _locationController,
                    places: AppScope.of(context).places,
                  ),
                  RecurTextField(
                    label: 'Notes',
                    controller: _notesController,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  _WeekdayGroup(controller: controller),
                  _TimeWindowGroup(controller: controller),
                  if (!controller.isNew)
                    TextButton(
                      onPressed: _confirmDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: RecurColors.error,
                      ),
                      child: const Text('Delete event type'),
                    ),
                ],
              ),
            ),
          ),
          ConfirmBar(
            summary: '',
            button: ConfirmButton(
              label: 'Save',
              onPressed: controller.isValid ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationGroup extends StatelessWidget {
  const _DurationGroup({
    required this.controller,
    required this.customDurationController,
  });

  final EditorController controller;
  final TextEditingController customDurationController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Duration',
          style: RecurText.label.copyWith(color: RecurColors.muted),
        ),
        const SizedBox(height: RecurSpacing.sm),
        Wrap(
          spacing: RecurSpacing.sm,
          runSpacing: RecurSpacing.sm,
          children: [
            for (final preset in editorPresetDurations)
              IntrinsicWidth(
                child: DurationPill(
                  label: formatDuration(preset),
                  selected:
                      !controller.isCustomDuration &&
                      controller.durationMinutes == preset,
                  onTap: () => controller.selectPresetDuration(preset),
                ),
              ),
            IntrinsicWidth(
              child: DurationPill(
                label: 'Custom',
                selected: controller.isCustomDuration,
                onTap: controller.selectCustomDuration,
              ),
            ),
          ],
        ),
        if (controller.isCustomDuration) ...[
          const SizedBox(height: RecurSpacing.sm),
          RecurTextField(
            label: 'Minutes',
            controller: customDurationController,
            keyboardType: TextInputType.number,
            errorText: controller.durationError,
          ),
        ],
      ],
    );
  }
}

class _WeekdayGroup extends StatelessWidget {
  const _WeekdayGroup({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Preferred weekdays',
          style: RecurText.label.copyWith(color: RecurColors.muted),
        ),
        const SizedBox(height: RecurSpacing.sm),
        Wrap(
          spacing: RecurSpacing.sm,
          runSpacing: RecurSpacing.sm,
          children: [
            for (var i = 0; i < 7; i++)
              IntrinsicWidth(
                child: DurationPill(
                  label: _weekdayLabels[i],
                  selected: controller.weekdays.contains(i + 1),
                  onTap: () => controller.toggleWeekday(i + 1),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeWindowGroup extends StatelessWidget {
  const _TimeWindowGroup({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final windows = controller.windows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Preferred times',
          style: RecurText.label.copyWith(color: RecurColors.muted),
        ),
        const SizedBox(height: RecurSpacing.sm),
        for (var i = 0; i < windows.length; i++) ...[
          if (i > 0) const SizedBox(height: RecurSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Start',
                  value: windows[i].startMinutes,
                  onChanged: (minutes) => controller.setWindowStart(i, minutes),
                ),
              ),
              const SizedBox(width: RecurSpacing.md),
              Expanded(
                child: _TimeField(
                  label: 'End',
                  value: windows[i].endMinutes,
                  onChanged: (minutes) => controller.setWindowEnd(i, minutes),
                ),
              ),
              if (windows.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: RecurColors.muted,
                  tooltip: 'Remove this time',
                  onPressed: () => controller.removeWindow(i),
                ),
            ],
          ),
        ],
        const SizedBox(height: RecurSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.addWindow,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add a time'),
            style: TextButton.styleFrom(foregroundColor: RecurColors.primary),
          ),
        ),
        if (controller.windowError != null) ...[
          const SizedBox(height: RecurSpacing.xs),
          Text(
            controller.windowError!,
            style: RecurText.caption.copyWith(color: RecurColors.error),
          ),
        ],
      ],
    );
  }
}

/// A dropdown over the 30-minute marks between 06:00 and 22:00, styled to
/// match [RecurTextField]. Used for the preferred-window start and end
/// times; see `docs/architecture.md`'s Decisions table.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: RecurText.label.copyWith(color: RecurColors.muted)),
        const SizedBox(height: RecurSpacing.xs),
        DropdownButtonFormField<int>(
          initialValue: value,
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          style: RecurText.body.copyWith(color: RecurColors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: RecurColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RecurRadii.field),
              borderSide: const BorderSide(color: RecurColors.divider),
            ),
          ),
          items: [
            for (
              var minutes = dayStartMinutes;
              minutes <= dayEndMinutes;
              minutes += slotMinutes
            )
              DropdownMenuItem(
                value: minutes,
                child: Text(formatMinutes(minutes)),
              ),
          ],
        ),
      ],
    );
  }
}
