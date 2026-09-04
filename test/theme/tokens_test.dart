import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recur/theme/tokens.dart';

void main() {
  group('RecurColors', () {
    test('matches the documented hex values', () {
      expect(RecurColors.background, const Color(0xFFF4EFE6));
      expect(RecurColors.surface, const Color(0xFFFAF7F2));
      expect(RecurColors.text, const Color(0xFF1C1C19));
      expect(RecurColors.muted, const Color(0xFF938F85));
      expect(RecurColors.primary, const Color(0xFF2C4A3B));
      expect(RecurColors.onPrimary, const Color(0xFFFAF7F2));
      expect(RecurColors.accent, const Color(0xFF8A4B38));
      expect(RecurColors.accentTint, const Color(0x148A4B38));
      expect(RecurColors.primaryTint, const Color(0x142C4A3B));
      expect(RecurColors.blocked, const Color(0xFFE9E3D8));
      expect(RecurColors.divider, const Color(0xFFE3DDD2));
      expect(RecurColors.error, const Color(0xFF9A4A3A));
    });

    test('no token is pure black or pure white', () {
      final tokens = <Color>[
        RecurColors.background,
        RecurColors.surface,
        RecurColors.text,
        RecurColors.muted,
        RecurColors.primary,
        RecurColors.onPrimary,
        RecurColors.accent,
        RecurColors.blocked,
        RecurColors.divider,
        RecurColors.error,
      ];
      for (final token in tokens) {
        expect(token, isNot(const Color(0xFF000000)));
        expect(token, isNot(const Color(0xFFFFFFFF)));
      }
    });
  });

  group('RecurText', () {
    test('every style uses Outfit, no tracking, and the documented size', () {
      const styles = <TextStyle>[
        RecurText.display,
        RecurText.title,
        RecurText.body,
        RecurText.label,
        RecurText.caption,
        RecurText.button,
      ];
      for (final style in styles) {
        expect(style.fontFamily, 'Outfit');
        expect(style.letterSpacing, 0);
        expect(style.color, RecurColors.text);
      }

      expect(RecurText.display.fontSize, 28);
      expect(RecurText.display.fontWeight, FontWeight.w600);
      expect(RecurText.display.height, closeTo(34 / 28, 1e-9));

      expect(RecurText.title.fontSize, 20);
      expect(RecurText.title.fontWeight, FontWeight.w600);
      expect(RecurText.title.height, closeTo(26 / 20, 1e-9));

      expect(RecurText.body.fontSize, 16);
      expect(RecurText.body.fontWeight, FontWeight.w400);
      expect(RecurText.body.height, closeTo(22 / 16, 1e-9));

      expect(RecurText.label.fontSize, 14);
      expect(RecurText.label.fontWeight, FontWeight.w500);
      expect(RecurText.label.height, closeTo(18 / 14, 1e-9));

      expect(RecurText.caption.fontSize, 12);
      expect(RecurText.caption.fontWeight, FontWeight.w400);
      expect(RecurText.caption.height, closeTo(16 / 12, 1e-9));

      expect(RecurText.button.fontSize, 16);
      expect(RecurText.button.fontWeight, FontWeight.w500);
      expect(RecurText.button.height, closeTo(20 / 16, 1e-9));
    });
  });

  group('RecurSpacing', () {
    test('matches the documented scale', () {
      expect(RecurSpacing.xs, 4);
      expect(RecurSpacing.sm, 8);
      expect(RecurSpacing.md, 12);
      expect(RecurSpacing.lg, 16);
      expect(RecurSpacing.xl, 24);
      expect(RecurSpacing.xxl, 32);
    });
  });

  group('RecurRadii', () {
    test('card column radii mirror each other', () {
      expect(RecurRadii.cardColumnOne.topLeft, const Radius.circular(16));
      expect(RecurRadii.cardColumnOne.topRight, const Radius.circular(4));
      expect(RecurRadii.cardColumnOne.bottomRight, const Radius.circular(16));
      expect(RecurRadii.cardColumnOne.bottomLeft, const Radius.circular(16));

      expect(RecurRadii.cardColumnTwo.topLeft, const Radius.circular(4));
      expect(RecurRadii.cardColumnTwo.topRight, const Radius.circular(16));
      expect(RecurRadii.cardColumnTwo.bottomRight, const Radius.circular(16));
      expect(RecurRadii.cardColumnTwo.bottomLeft, const Radius.circular(16));
    });

    test('matches the documented scalar radii', () {
      expect(RecurRadii.button, 12);
      expect(RecurRadii.pill, 999);
      expect(RecurRadii.field, 12);
      expect(RecurRadii.slot, 8);
      expect(RecurRadii.fab, 16);
      expect(RecurRadii.sheet.topLeft, const Radius.circular(20));
      expect(RecurRadii.sheet.topRight, const Radius.circular(20));
      expect(RecurRadii.sheet.bottomLeft, Radius.zero);
      expect(RecurRadii.sheet.bottomRight, Radius.zero);
    });
  });

  group('RecurShadows', () {
    test(
      'card shadow is primary at 8%, offset (0, 12), blur 24, spread -4',
      () {
        final shadow = RecurShadows.card.single;
        expect(shadow.color, const Color(0x142C4A3B));
        expect(shadow.offset, const Offset(0, 12));
        expect(shadow.blurRadius, 24);
        expect(shadow.spreadRadius, -4);
      },
    );

    test('fab shadow is primary at 16%, offset (0, 8), blur 16, spread -4', () {
      final shadow = RecurShadows.fab.single;
      expect(shadow.color, const Color(0x292C4A3B));
      expect(shadow.offset, const Offset(0, 8));
      expect(shadow.blurRadius, 16);
      expect(shadow.spreadRadius, -4);
    });

    test(
      'sheet shadow is primary at 10%, offset (0, -8), blur 24, spread -4',
      () {
        final shadow = RecurShadows.sheet.single;
        expect(shadow.color, const Color(0x1A2C4A3B));
        expect(shadow.offset, const Offset(0, -8));
        expect(shadow.blurRadius, 24);
        expect(shadow.spreadRadius, -4);
      },
    );
  });

  group('RecurSizes', () {
    test('matches the documented sizes', () {
      expect(RecurSizes.touchMin, 44);
      expect(RecurSizes.slotRow, 48);
      expect(RecurSizes.hourGutter, 56);
      expect(RecurSizes.dayPillWidth, 44);
      expect(RecurSizes.dayPillHeight, 64);
      expect(RecurSizes.fab, 56);
      expect(RecurSizes.confirmBar, 88);
      expect(RecurSizes.highlightBorder, 3);
    });
  });
}
