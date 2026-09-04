import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/theme/app_theme.dart';
import 'package:recur/theme/tokens.dart';

void main() {
  group('buildRecurTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = buildRecurTheme();
    });

    test('enables Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('sets the scaffold background to RecurColors.background', () {
      expect(theme.scaffoldBackgroundColor, RecurColors.background);
    });

    test('color scheme maps the documented tokens', () {
      expect(theme.colorScheme.primary, RecurColors.primary);
      expect(theme.colorScheme.onPrimary, RecurColors.onPrimary);
      expect(theme.colorScheme.surface, RecurColors.surface);
      expect(theme.colorScheme.onSurface, RecurColors.text);
      expect(theme.colorScheme.error, RecurColors.error);
      expect(theme.colorScheme.tertiary, RecurColors.accent);
    });

    test('app bar is flat with a surface background and no scroll tint', () {
      final appBarTheme = theme.appBarTheme;
      expect(appBarTheme.backgroundColor, RecurColors.surface);
      expect(appBarTheme.elevation, 0);
      expect(appBarTheme.scrolledUnderElevation, 0);
      expect(appBarTheme.surfaceTintColor, Colors.transparent);
      expect(appBarTheme.titleTextStyle, RecurText.title);
      expect(appBarTheme.centerTitle, isFalse);
    });

    test('cards never use Material elevation', () {
      expect(theme.cardTheme.elevation, 0);
    });

    test('ripples use the primary tint', () {
      expect(theme.splashColor, RecurColors.primaryTint);
      expect(theme.highlightColor, RecurColors.primaryTint);
    });

    test('default font family is Outfit', () {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Outfit');
    });

    test('text theme maps display, title, body, label, and caption', () {
      // ThemeData merges the supplied TextTheme onto the Material 3
      // defaults (adding a matching text decoration colour, for one), so
      // compare the properties the tokens actually specify rather than
      // full TextStyle equality.
      void expectMatchesToken(TextStyle? actual, TextStyle token) {
        expect(actual, isNotNull);
        expect(actual!.fontFamily, token.fontFamily);
        expect(actual.fontSize, token.fontSize);
        expect(actual.fontWeight, token.fontWeight);
        expect(actual.height, token.height);
        expect(actual.letterSpacing, token.letterSpacing);
        expect(actual.color, token.color);
      }

      final textTheme = theme.textTheme;
      expectMatchesToken(textTheme.displaySmall, RecurText.display);
      expectMatchesToken(textTheme.titleMedium, RecurText.title);
      expectMatchesToken(textTheme.bodyMedium, RecurText.body);
      expectMatchesToken(textTheme.labelMedium, RecurText.label);
      expectMatchesToken(textTheme.bodySmall, RecurText.caption);
    });
  });
}
