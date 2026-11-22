// Flutter's bundled Material library is used to avoid an extra UI dependency.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Design tokens for the CLEANVerse dark theme. Values follow
/// docs/VISUAL_DIRECTION.md; keep new colors here rather than inline.
abstract final class CvColors {
  static const canvas = Color(0xff141626);
  static const sidebar = Color(0xff191b2c);
  static const panel = Color(0xff1d2032);
  static const raised = Color(0xff24283d);
  static const sunken = Color(0xff171a2b);
  static const outline = Color(0xff353b53);
  static const outlineSoft = Color(0xff2b3046);
  static const text = Color(0xffedf0fc);
  static const muted = Color(0xffaeb8d0);
  static const cyan = Color(0xff73d5fb);
  static const violet = Color(0xffc2a7f5);
  static const mint = Color(0xff9bdcc5);
  static const amber = Color(0xfff2c97d);
  static const rose = Color(0xfff29fb6);
  static const onCyan = Color(0xff102031);

  /// Distinct hues for storage maps. Never rely on color alone: every
  /// segment is also labelled in text.
  static const series = [
    Color(0xff73d5fb),
    Color(0xffc2a7f5),
    Color(0xff9bdcc5),
    Color(0xfff2c97d),
    Color(0xfff29fb6),
    Color(0xff8fa8f7),
    Color(0xffb6e388),
    Color(0xffe6a6e8),
  ];
  static Color seriesAt(int index) => series[index % series.length];
}

abstract final class CvSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class CvRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
}

ThemeData buildCleanVerseTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CvColors.cyan,
    brightness: Brightness.dark,
    primary: CvColors.cyan,
    secondary: CvColors.violet,
    surface: CvColors.panel,
    error: CvColors.rose,
  );
  final base = ThemeData.dark().textTheme.apply(
    bodyColor: CvColors.text,
    displayColor: const Color(0xfff5f6ff),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: CvColors.canvas,
    textTheme: base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
    ),
    dividerColor: CvColors.outlineSoft,
    cardTheme: CardThemeData(
      color: CvColors.raised,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: CvSpace.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CvRadius.md),
        side: const BorderSide(color: CvColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CvColors.cyan,
        foregroundColor: CvColors.onCyan,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xffd7e4f9),
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Color(0xff505b77)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );
}
