import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One day in the Booking day strip. 44 x 64 px, radius `pill`, vertically
/// stacked: weekday abbreviation over the day number, with a 6 px dot 4 px
/// under the number when [hasSuggestions] is true.
///
/// Takes plain values only, so it does not depend on `core` or the
/// suggestion engine. See `docs/design-system.md` for the full state table.
class DayPill extends StatelessWidget {
  const DayPill({
    super.key,
    required this.weekdayLabel,
    required this.dayNumber,
    required this.selected,
    required this.enabled,
    required this.hasSuggestions,
    required this.isToday,
    this.onTap,
  });

  /// `Mon` .. `Sun`.
  final String weekdayLabel;

  final int dayNumber;
  final bool selected;
  final bool enabled;
  final bool hasSuggestions;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(RecurRadii.pill)),
    );

    final Color fill = selected ? RecurColors.primary : Colors.transparent;
    final Color textColor = !enabled
        ? RecurColors.muted
        : selected
        ? RecurColors.onPrimary
        : isToday
        ? RecurColors.primary
        : RecurColors.text;
    final Color? dotColor = !enabled || !hasSuggestions
        ? null
        : selected
        ? RecurColors.onPrimary
        : RecurColors.accent;
    final bool showTodayRing = isToday && !selected;

    return SizedBox(
      width: RecurSizes.dayPillWidth,
      height: RecurSizes.dayPillHeight,
      child: Material(
        color: fill,
        shape: showTodayRing
            ? RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(
                  Radius.circular(RecurRadii.pill),
                ),
                side: const BorderSide(color: RecurColors.primary, width: 1),
              )
            : shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: shape,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayLabel,
                style: RecurText.caption.copyWith(color: textColor),
              ),
              const SizedBox(height: 2),
              Text(
                '$dayNumber',
                style: RecurText.label.copyWith(color: textColor),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 6,
                height: 6,
                child: dotColor == null
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
