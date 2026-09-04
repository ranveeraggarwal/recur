import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Overlay tint applied on top of [RecurColors.primary] while a button in
/// this file is pressed.
const Color _pressedOverlay = Color(0x1F1C1C19);

/// Full-width primary button. Height [RecurSizes.touchMin] and up (fixed at
/// 52px), radius [RecurRadii.button], text [RecurText.button], no icon, no
/// elevation.
///
/// Used both as the calendar screen's confirm action and as Save in the
/// event editor.
class ConfirmButton extends StatelessWidget {
  const ConfirmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  /// The button's text. Ignored while [busy].
  final String label;

  /// Called on tap. `null` disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner instead of [label] and ignores taps while `true`.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
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

/// Sticky bar wrapping a [ConfirmButton] with a summary line above it, used
/// at the bottom of the calendar screen.
class ConfirmBar extends StatelessWidget {
  const ConfirmBar({super.key, required this.summary, required this.button});

  /// Shown in [RecurText.caption] muted, above the button.
  final String summary;

  final ConfirmButton button;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: RecurColors.surface,
        boxShadow: RecurShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(RecurSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: RecurText.caption.copyWith(color: RecurColors.muted),
              ),
              const SizedBox(height: RecurSpacing.sm),
              button,
            ],
          ),
        ),
      ),
    );
  }
}
