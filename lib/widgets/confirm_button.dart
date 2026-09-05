import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Overlay tint applied on top of [RecurColors.primary] while a button in
/// this file is pressed.
const Color _pressedOverlay = Color(0x1F1C1C19);

/// Primary button. Height [RecurSizes.touchMin] and up (fixed at 52px),
/// radius [RecurRadii.button], text [RecurText.button], no icon, no
/// elevation. Full width by default; pass [expand] false for a
/// content-sized button (e.g. the Booking access states).
///
/// Used both as the calendar screen's confirm action and as Save in the
/// event editor.
class ConfirmButton extends StatelessWidget {
  const ConfirmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.expand = true,
  });

  /// The button's text. Ignored while [busy].
  final String label;

  /// Called on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner instead of [label] and ignores taps while `true`.
  final bool busy;

  /// When `false`, the button sizes to its label's intrinsic width instead
  /// of filling the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RecurRadii.button),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled) && !busy) {
              return RecurColors.blocked;
            }
            return RecurColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled) && !busy) {
              return RecurColors.muted;
            }
            return RecurColors.onPrimary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return _pressedOverlay;
            }
            return null;
          }),
          textStyle: const WidgetStatePropertyAll(RecurText.button),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RecurColors.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Sticky bar wrapping a [ConfirmButton] with an optional summary line above
/// it, used at the bottom of the calendar screen and as the Editor's Save
/// bar. Always [RecurSizes.confirmBar] (88px) tall total, whether or not a
/// summary is shown: the button is a fixed 52px, and the vertical padding is
/// derived from what's left so the two callers can't drift apart.
class ConfirmBar extends StatelessWidget {
  const ConfirmBar({super.key, required this.summary, required this.button});

  /// Shown in [RecurText.caption] muted, above the button. When empty, the
  /// summary line (and the gap below it) is omitted entirely rather than
  /// reserving its height, so the bar stays 88px whether Booking passes a
  /// real summary or the Editor passes `''`.
  final String summary;

  final ConfirmButton button;

  /// Height of one line of [RecurText.caption] (12px font, 16/12 line
  /// height).
  static const double _summaryLineHeight = 16;

  @override
  Widget build(BuildContext context) {
    final hasSummary = summary.isNotEmpty;
    final contentHeight =
        52 + (hasSummary ? _summaryLineHeight + RecurSpacing.sm : 0);
    final verticalPadding = (RecurSizes.confirmBar - contentHeight) / 2;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: RecurColors.surface,
        boxShadow: RecurShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: RecurSizes.confirmBar,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: RecurSpacing.lg,
              vertical: verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSummary) ...[
                  Text(
                    summary,
                    style: RecurText.caption.copyWith(color: RecurColors.muted),
                  ),
                  const SizedBox(height: RecurSpacing.sm),
                ],
                button,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
