import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds Recur's single [ThemeData], assembled entirely from
/// `lib/theme/tokens.dart`. See `docs/design-system.md` for the source of
/// these values.
ThemeData buildRecurTheme() {
  final colorScheme = ColorScheme.light(
    primary: RecurColors.primary,
    onPrimary: RecurColors.onPrimary,
    surface: RecurColors.surface,
    onSurface: RecurColors.text,
    error: RecurColors.error,
    onError: RecurColors.onPrimary,
    tertiary: RecurColors.accent,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: RecurText.fontFamily,
    scaffoldBackgroundColor: RecurColors.background,
    colorScheme: colorScheme,
    splashColor: RecurColors.primaryTint,
    highlightColor: RecurColors.primaryTint,
    appBarTheme: AppBarTheme(
      backgroundColor: RecurColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: RecurText.title,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(elevation: 0),
    textTheme: const TextTheme(
      displaySmall: RecurText.display,
      titleMedium: RecurText.title,
      bodyMedium: RecurText.body,
      labelMedium: RecurText.label,
      bodySmall: RecurText.caption,
    ),
  );
}
