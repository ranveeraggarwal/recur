import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Shows the "Booked" confirmation bottom sheet. Auto-dismisses after 2
/// seconds; tapping outside or dragging down also dismisses it (both are
/// `showModalBottomSheet`'s default behaviour). Completes once the sheet is
/// gone, however it closed.
Future<void> showConfirmationSheet(
  BuildContext context, {
  required String summary,
  required String eventTypeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: RecurColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: RecurRadii.sheet),
    builder: (sheetContext) =>
        _ConfirmationSheet(summary: summary, eventTypeName: eventTypeName),
  );
}

/// A [StatefulWidget] so the 2-second auto-dismiss [Timer] can be cancelled
/// in [dispose] if the sheet closes another way first (tap-outside, drag),
/// rather than firing against an already-popped context.
class _ConfirmationSheet extends StatefulWidget {
  const _ConfirmationSheet({
    required this.summary,
    required this.eventTypeName,
  });

  final String summary;
  final String eventTypeName;

  @override
  State<_ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends State<_ConfirmationSheet> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final eventTypeName = widget.eventTypeName;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: RecurSpacing.md,
          bottom: RecurSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: RecurSpacing.lg),
              decoration: BoxDecoration(
                color: RecurColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: RecurColors.primary,
            ),
            const SizedBox(height: RecurSpacing.md),
            Text('Booked', style: RecurText.title),
            const SizedBox(height: RecurSpacing.xs),
            Text(summary, style: RecurText.body),
            Text(
              eventTypeName,
              style: RecurText.caption.copyWith(color: RecurColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
