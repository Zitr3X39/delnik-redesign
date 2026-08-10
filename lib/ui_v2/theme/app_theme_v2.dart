import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Тема «Дельник v2». Собирается целиком из токенов (tokens.dart).
///
/// Важно: `textScaler` здесь НЕ зажимается — масштаб шрифта системы
/// уважаем, вёрстку чиним констрейнтами, а не капом шрифта.
library;

ThemeData buildLightThemeV2() => _buildTheme(AppColorsExt.light, Brightness.light);

ThemeData buildDarkThemeV2() => _buildTheme(AppColorsExt.dark, Brightness.dark);

/// Текстовые стили вне TextTheme.
abstract final class AppTextStyles {
  /// Цена — самый жирный текст на экране. Табличные цифры, чтобы
  /// колонка цен не плясала при скролле.
  static TextStyle price(AppColorsExt c, {double size = 20}) => TextStyle(
        fontFamily: 'NotoSans',
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: c.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

TextTheme _textTheme(AppColorsExt c) {
  return TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: c.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      color: c.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 26 / 20,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 22 / 17,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: c.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 22 / 15,
      fontWeight: FontWeight.w400,
      color: c.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400,
      color: c.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w700,
      color: c.onAccent,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 16 / 13,
      fontWeight: FontWeight.w600,
      color: c.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w600,
      color: c.textSecondary,
    ),
  ).apply(fontFamily: 'NotoSans');
}

ThemeData _buildTheme(AppColorsExt c, Brightness brightness) {
  final textTheme = _textTheme(c);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.info,
    onSecondary: AppPalette.white,
    error: c.danger,
    onError: AppPalette.white,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceAlt,
    outline: c.border,
  );

  final radiusMd = BorderRadius.circular(AppRadii.md);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    textTheme: textTheme,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: c.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        disabledBackgroundColor: c.surfaceAlt,
        disabledForegroundColor: c.textTertiary,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: c.border),
        textStyle: textTheme.labelLarge?.copyWith(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accentText,
        textStyle: textTheme.labelLarge?.copyWith(color: c.accentText),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
      border: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide(color: c.danger),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.surface),
      shape: RoundedRectangleBorder(borderRadius: radiusMd),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.surfaceAlt,
      circularTrackColor: c.surfaceAlt,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.accentText,
      unselectedItemColor: c.textTertiary,
      selectedLabelStyle: textTheme.labelSmall,
      unselectedLabelStyle: textTheme.labelSmall,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
