import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Overlay tint applied on top of [RecurColors.primary] while the FAB is
/// pressed.
const Color _pressedOverlay = Color(0x1F1C1C19);

/// The floating "add event" action: a 56x56px rounded-square button, never
/// a circle.
class RecurFab extends StatelessWidget {
  const RecurFab({
    super.key,
    required this.onPressed,
    this.tooltip = 'Add event',
  });

  final VoidCallback onPressed;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(RecurRadii.fab);

    return SizedBox(
      width: RecurSizes.fab,
      height: RecurSizes.fab,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: RecurShadows.fab,
        ),
        child: Material(
          color: RecurColors.primary,
          borderRadius: borderRadius,
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              onTap: onPressed,
              borderRadius: borderRadius,
              overlayColor: const WidgetStatePropertyAll(_pressedOverlay),
              child: const Icon(
                Icons.add,
                size: 24,
                color: RecurColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
