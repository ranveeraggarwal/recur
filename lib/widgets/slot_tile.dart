import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Visual appearance of a [SlotTile], mapped by the Booking screen from a
/// `Slot`'s state and whether it is the selected slot.
///
/// [blocked] is a row taken by something: a calendar event, the past, or
/// the end of the day. [doesNotFit] is a row that is free itself but too
/// close to the next event for the appointment to fit, so it keeps the
/// plain surface and only goes quiet.
enum SlotTileAppearance {
  available,
  highlighted,
  selected,
  blocked,
  doesNotFit,
}

/// One 30-minute row in the timeline. Height [RecurSizes.slotRow] (48 px),
/// with a 2 px vertical inset so tiles do not touch, radius `slot`.
///
/// Takes plain values only, so it does not depend on the suggestion engine.
/// See `docs/design-system.md` for the full state table.
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.timeLabel,
    required this.appearance,
    this.reasonText,
    this.onTap,
  });

  final String timeLabel;
  final SlotTileAppearance appearance;

  /// Shown at the right, on blocked and does-not-fit tiles only.
  final String? reasonText;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool blocked = appearance == SlotTileAppearance.blocked;
    final bool doesNotFit = appearance == SlotTileAppearance.doesNotFit;
    final bool highlighted = appearance == SlotTileAppearance.highlighted;
    final bool selected = appearance == SlotTileAppearance.selected;
    final bool interactive = !blocked && !doesNotFit;

    final Color fill = switch (appearance) {
      SlotTileAppearance.available => RecurColors.surface,
      SlotTileAppearance.highlighted => RecurColors.accentTint,
      SlotTileAppearance.selected => RecurColors.primary,
      SlotTileAppearance.blocked => RecurColors.blocked,
      SlotTileAppearance.doesNotFit => RecurColors.surface,
    };
    final Color textColor = selected
        ? RecurColors.onPrimary
        : interactive
        ? RecurColors.text
        : RecurColors.muted;

    final borderRadius = const BorderRadius.all(
      Radius.circular(RecurRadii.slot),
    );

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: RecurSpacing.lg),
      child: Row(
        children: [
          Text(timeLabel, style: RecurText.label.copyWith(color: textColor)),
          if (!interactive && reasonText != null) ...[
            const Spacer(),
            Flexible(
              child: Text(
                reasonText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RecurText.caption.copyWith(color: RecurColors.muted),
              ),
            ),
          ],
        ],
      ),
    );

    final Widget stack = Stack(
      children: [
        Positioned.fill(child: content),
        if (highlighted)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: RecurSizes.highlightBorder,
              color: RecurColors.accent,
            ),
          ),
      ],
    );

    final Widget body = Material(
      color: fill,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: interactive ? InkWell(onTap: onTap, child: stack) : stack,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(height: RecurSizes.slotRow - 4, child: body),
    );
  }
}
