import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../theme/tokens.dart';
import 'duration_pill.dart';

/// Which column of the Home grid an [EventCard] sits in. Only the corner
/// radius differs between the two.
enum CardColumn { one, two }

/// A card in the Home grid for one event type.
///
/// Takes plain values rather than data-layer objects (`EventType`,
/// `Booking`) so it does not depend on the data layer. The Home screen is
/// responsible for formatting [lastBookedText] with `formatLastBooked` and
/// setting [lastBookedIsFuture] when the latest booking starts after now.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.name,
    required this.durationMinutes,
    this.location,
    required this.lastBookedText,
    required this.lastBookedIsFuture,
    required this.column,
    required this.onTap,
    required this.onLongPress,
  });

  /// The event type's name. Max 2 lines, ellipsis.
  final String name;

  /// Booking duration in minutes, shown on a read-only [DurationPill] via
  /// `formatDuration`.
  final int durationMinutes;

  /// Optional location. When `null` the location line (and its gap) is
  /// omitted.
  final String? location;

  /// The last-booked line, already formatted (see `formatLastBooked` in
  /// `lib/core/formatting.dart`).
  final String lastBookedText;

  /// Whether the booking [lastBookedText] describes starts after now. When
  /// `true` the line is coloured `primary` instead of `muted`.
  final bool lastBookedIsFuture;

  /// Which grid column this card is in, selecting its corner radius.
  final CardColumn column;

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// What a screen reader reads for this card: the lines it shows, as one
  /// item, in the order they are laid out.
  String get _semanticsLabel {
    final String place = location == null ? '' : ', $location';
    return '$name, ${formatDuration(durationMinutes)}$place, '
        '$lastBookedText';
  }

  BorderRadius get _radius => column == CardColumn.one
      ? RecurRadii.cardColumnOne
      : RecurRadii.cardColumnTwo;

  @override
  Widget build(BuildContext context) {
    // The label carries every line, so they are excluded rather than read
    // again one by one. The hint is the only place `hold to edit` is said
    // out loud; the gesture itself is invisible.
    return Semantics(
      button: true,
      label: _semanticsLabel,
      hint: 'Double tap to book, double tap and hold to edit',
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: RecurShadows.card,
        ),
        child: Material(
          color: RecurColors.surface,
          borderRadius: _radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: _radius,
            splashColor: RecurColors.primaryTint,
            highlightColor: RecurColors.primaryTint,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: RecurSizes.cardMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(RecurSpacing.lg),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: RecurText.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RecurSpacing.sm),
                      DurationPill(label: formatDuration(durationMinutes)),
                      if (location != null) ...[
                        const SizedBox(height: RecurSpacing.sm),
                        Text(
                          location!,
                          style: RecurText.caption.copyWith(
                            color: RecurColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Expanded(child: SizedBox()),
                      Text(
                        lastBookedText,
                        style: RecurText.caption.copyWith(
                          color: lastBookedIsFuture
                              ? RecurColors.primary
                              : RecurColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
