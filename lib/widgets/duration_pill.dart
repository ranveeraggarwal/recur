import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A small rounded label showing a duration or a custom name.
///
/// Read-only (no [InkWell], `primaryTint` fill, `primary` text) when
/// [onTap] is `null` — the look used on [EventCard]. Tappable pills (the
/// Editor) show `surface` with a `divider` border when [selected] is
/// `false`, or `primary` fill with `onPrimary` text when [selected] is
/// `true`.
class DurationPill extends StatelessWidget {
  const DurationPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  /// The text shown, e.g. `formatDuration(45)` (`45 min`) or a custom
  /// label such as `Custom`.
  final String label;

  /// Whether this pill is the selected choice. Ignored when [onTap] is
  /// `null` (the read-only look always wins).
  final bool selected;

  /// Tapped to select this pill. `null` renders the read-only look and
  /// omits the [InkWell] entirely.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final readOnly = onTap == null;

    final Color fill;
    final Color textColor;
    final Border? border;
    if (readOnly) {
      fill = RecurColors.primaryTint;
      textColor = RecurColors.primary;
      border = null;
    } else if (selected) {
      fill = RecurColors.primary;
      textColor = RecurColors.onPrimary;
      border = null;
    } else {
      fill = RecurColors.surface;
      textColor = RecurColors.text;
      border = Border.all(color: RecurColors.divider, width: 1);
    }

    final content = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: BorderRadius.circular(RecurRadii.pill),
      ),
      child: Text(label, style: RecurText.label.copyWith(color: textColor)),
    );

    if (readOnly) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RecurRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RecurRadii.pill),
        splashColor: RecurColors.primaryTint,
        highlightColor: RecurColors.primaryTint,
        child: content,
      ),
    );
  }
}
