import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../core/local_date.dart';
import '../theme/tokens.dart';

/// The 72 px row above a day strip: `Week of 7 Sep` between two chevrons.
///
/// Shared by Booking, which cannot go back before this week, and the
/// copy-from-calendar picker, which can go back but not past the range it
/// read. Either chevron is greyed out and inert when its callback is null.
class WeekHeader extends StatelessWidget {
  const WeekHeader({
    super.key,
    required this.weekMonday,
    required this.onPrevious,
    required this.onNext,
  });

  final LocalDate weekMonday;

  /// `null` disables the chevron.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(
                formatWeekOf(weekMonday),
                style: RecurText.label,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
