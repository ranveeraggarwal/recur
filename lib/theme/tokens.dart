import 'package:flutter/material.dart';

/// Design tokens for Recur, transcribed from `docs/design-system.md`.
///
/// Nowhere else in `lib/` should a colour, size, radius, shadow, or text
/// style be written out by hand: reach for one of these classes instead.

/// Colour tokens.
class RecurColors {
  const RecurColors._();

  /// The page background, warm sand.
  static const Color background = Color(0xFFF4EFE6);

  /// Cards, sheets, fields, the app bar.
  static const Color surface = Color(0xFFFAF7F2);

  /// Primary text. Nearly black, never pure black.
  static const Color text = Color(0xFF1C1C19);

  /// Secondary text, hour labels, hints, disabled text.
  static const Color muted = Color(0xFF938F85);

  /// Forest green: buttons, FAB, selected states, links, check marks.
  static const Color primary = Color(0xFF2C4A3B);

  /// Text/icons on top of [primary] (same value as [surface]).
  static const Color onPrimary = Color(0xFFFAF7F2);

  /// Cedar: highlighted slots and attention only, never buttons.
  static const Color accent = Color(0xFF8A4B38);

  /// Highlighted slot fill: [accent] at 8% opacity.
  static const Color accentTint = Color(0x148A4B38);

  /// Pressed state overlay on surfaces: [primary] at 8% opacity.
  static const Color primaryTint = Color(0x142C4A3B);

  /// Blocked/past slot fill, disabled button fill.
  static const Color blocked = Color(0xFFE9E3D8);

  /// Timeline hour lines, sheet handle.
  static const Color divider = Color(0xFFE3DDD2);

  /// Validation text (a slightly redder cedar).
  static const Color error = Color(0xFF9A4A3A);
}

/// Typography tokens. Family is `Outfit`, vendored in `assets/fonts`.
class RecurText {
  const RecurText._();

  static const String fontFamily = 'Outfit';

  /// App bar titles on Home. 600 28px/34px.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: RecurColors.text,
  );

  /// Screen titles, card names, sheet titles. 600 20px/26px.
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: RecurColors.text,
  );

  /// Body copy, field input, list rows. 400 16px/22px.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: RecurColors.text,
  );

  /// Pills, buttons, day pill labels, form labels. 500 14px/18px.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: RecurColors.text,
  );

  /// Hour labels, "last booked", helper/error text. 400 12px/16px.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: RecurColors.text,
  );

  /// ConfirmButton and Save. 500 16px/20px.
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: RecurColors.text,
  );
}

/// Spacing tokens.
class RecurSpacing {
  const RecurSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radius tokens.
class RecurRadii {
  const RecurRadii._();

  /// Cards in the left column: topLeft 16, topRight 4, bottomRight 16,
  /// bottomLeft 16.
  static const BorderRadius cardColumnOne = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
  );

  /// Cards in the right column: the mirror of [cardColumnOne].
  static const BorderRadius cardColumnTwo = BorderRadius.only(
    topLeft: Radius.circular(4),
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
  );

  static const double button = 12;
  static const double pill = 999;
  static const double field = 12;

  /// Top corners only, for sheets.
  static const BorderRadius sheet = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
  );

  static const double slot = 8;
  static const double fab = 16;
}

/// Shadow tokens.
class RecurShadows {
  const RecurShadows._();

  /// Offset (0, 12), blur 24, spread -4, primary at 8%.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x142C4A3B),
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  /// Offset (0, 8), blur 16, spread -4, primary at 16%.
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x292C4A3B),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  /// Offset (0, -8), blur 24, spread -4, primary at 10%.
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x1A2C4A3B),
      offset: Offset(0, -8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];
}

/// Size tokens.
class RecurSizes {
  const RecurSizes._();

  /// Minimum tappable height.
  static const double touchMin = 44;

  /// One 30-minute timeline row.
  static const double slotRow = 48;

  /// Left gutter for hour labels.
  static const double hourGutter = 56;

  static const double dayPillWidth = 44;
  static const double dayPillHeight = 64;

  static const double fab = 56;

  /// Sticky bar total height, including padding.
  static const double confirmBar = 88;

  /// SlotTile highlighted left border.
  static const double highlightBorder = 3;
}
