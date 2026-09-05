import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../calendar/calendar_gateway.dart';
import '../../core/formatting.dart';
import '../../core/local_date.dart';
import '../../theme/tokens.dart';
import 'event_prefill.dart';

/// How far back and forward the picker reads the calendar.
const Duration _lookBack = Duration(days: 90);
const Duration _lookAhead = Duration(days: 30);

/// Opens the copy-from-calendar sheet: one row per event title found in
/// the calendar, newest first. Returns the chosen [EventPrefill], or
/// `null` if the sheet was dismissed without choosing.
///
/// Shows an empty message rather than nothing at all when the calendar
/// cannot be read or holds nothing that could be a card.
Future<EventPrefill?> showPrefillSheet(BuildContext context) async {
  final deps = AppScope.of(context);
  final prefills = await _readPrefills(deps);
  if (!context.mounted) return null;

  return showModalBottomSheet<EventPrefill>(
    context: context,
    backgroundColor: RecurColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: RecurRadii.sheet),
    builder: (sheetContext) {
      return _PrefillSheet(
        prefills: prefills,
        onSelect: (prefill) => Navigator.of(sheetContext).pop(prefill),
      );
    },
  );
}

Future<List<EventPrefill>> _readPrefills(AppDependencies deps) async {
  try {
    if (await deps.calendar.checkAccess() != CalendarAccess.granted) {
      return const [];
    }
    final now = deps.clock.now();
    final events = await deps.calendar.listEvents(
      from: now.subtract(_lookBack),
      to: now.add(_lookAhead),
    );
    return prefillsFromEvents(events);
  } catch (_) {
    return const [];
  }
}

class _PrefillSheet extends StatelessWidget {
  const _PrefillSheet({required this.prefills, required this.onSelect});

  final List<EventPrefill> prefills;
  final ValueChanged<EventPrefill> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: RecurSpacing.md,
          bottom: RecurSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xl),
              child: Text('Copy from calendar', style: RecurText.title),
            ),
            const SizedBox(height: RecurSpacing.sm),
            if (prefills.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RecurSpacing.xl,
                  RecurSpacing.sm,
                  RecurSpacing.xl,
                  RecurSpacing.lg,
                ),
                child: Text(
                  'Nothing in your calendar to copy.',
                  style: RecurText.body.copyWith(color: RecurColors.muted),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prefills.length,
                  itemBuilder: (context, index) => _PrefillRow(
                    prefill: prefills[index],
                    onTap: () => onSelect(prefills[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(bottom: RecurSpacing.lg),
        decoration: BoxDecoration(
          color: RecurColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _PrefillRow extends StatelessWidget {
  const _PrefillRow({required this.prefill, required this.onTap});

  final EventPrefill prefill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      formatDuration(prefill.durationMinutes),
      formatDayShort(LocalDate.fromDateTime(prefill.latestStart)),
      if (prefill.location != null) prefill.location!,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: RecurColors.primaryTint,
        highlightColor: RecurColors.primaryTint,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefill.name,
                  style: RecurText.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: RecurText.caption.copyWith(color: RecurColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
