/// Дизайн-токены «Дельник v2».
///
/// База — как у Авито: нейтральный фон, белые карточки, плотные списки.
/// Характер — свой: тёплый оранжевый акцент, мягкие градиенты,
/// живые микро-анимации. Тёмная тема собирается из тех же токенов.
///
/// Спека: docs/redesign/DESIGN.md.
library;

import 'package:flutter/material.dart';

/// Примитивы палитры. В компонентах напрямую не используются —
/// только через [AppColorsExt].
abstract final class AppPalette {
  // Brand orange
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange300 = Color(0xFFFDBA74);
  static const orange400 = Color(0xFFFB923C);
  static const orange500 = Color(0xFFF97316);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);

  // Нейтралы (slate)
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // Функциональные
  static const green50 = Color(0xFFF0FDF4);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const red50 = Color(0xFFFEF2F2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const sky50 = Color(0xFFF0F9FF);
  static const sky400 = Color(0xFF38BDF8);
  static const sky600 = Color(0xFF0284C7);
  static const amber500 = Color(0xFFF59E0B);
  static const rose500 = Color(0xFFF43F5E);
  static const rose400 = Color(0xFFFB7185);
  static const white = Color(0xFFFFFFFF);
}

/// Семантические цвета приложения. Одни и те же имена токенов —
/// разные значения для light/dark. Доступ: `context.appColors`.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.success,
    required this.successText,
    required this.successSurface,
    required this.danger,
    required this.dangerSurface,
    required this.info,
    required this.infoSurface,
    required this.accentGradient,
    required this.urgentGradient,
    required this.placeholderGradient,
  });

  /// Фон страницы под карточками.
  final Color background;

  /// Фон карточек и поднятых поверхностей.
  final Color surface;

  /// Вторичные поверхности: чипы, инпуты, плейсхолдеры.
  final Color surfaceAlt;

  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Только декоративный текст и иконки. Не для контента.
  final Color textTertiary;

  /// Акцентная заливка (кнопки, активные состояния).
  final Color accent;

  /// Акцентный текст/иконки на светлом фоне (контраст >= 4.5:1).
  final Color accentText;

  /// Текст на акцентной заливке. Тёмный, как у Яндекса на жёлтом:
  /// белый на оранжевом не проходит WCAG.
  final Color onAccent;

  final Color success;
  final Color successText;
  final Color successSurface;
  final Color danger;
  final Color dangerSurface;
  final Color info;
  final Color infoSurface;

  /// Градиент главных CTA и «горячих» элементов.
  final Gradient accentGradient;

  /// Градиент плашки «Срочно».
  final Gradient urgentGradient;

  /// Фон плитки пустого фото.
  final Gradient placeholderGradient;

  static const light = AppColorsExt(
    background: AppPalette.slate50,
    surface: AppPalette.white,
    surfaceAlt: AppPalette.slate100,
    border: AppPalette.slate200,
    textPrimary: AppPalette.slate900,
    textSecondary: AppPalette.slate500,
    textTertiary: AppPalette.slate400,
    accent: AppPalette.orange500,
    accentText: AppPalette.orange700,
    onAccent: AppPalette.slate900,
    success: AppPalette.green600,
    successText: AppPalette.green700,
    successSurface: AppPalette.green50,
    danger: AppPalette.red500,
    dangerSurface: AppPalette.red50,
    info: AppPalette.sky600,
    infoSurface: AppPalette.sky50,
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.orange400, AppPalette.orange600],
    ),
    urgentGradient: LinearGradient(
      colors: [AppPalette.orange500, AppPalette.rose500],
    ),
    placeholderGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.slate100, AppPalette.slate200],
    ),
  );

  static const dark = AppColorsExt(
    background: AppPalette.slate900,
    surface: AppPalette.slate800,
    surfaceAlt: AppPalette.slate700,
    border: AppPalette.slate700,
    textPrimary: AppPalette.slate50,
    textSecondary: AppPalette.slate400,
    textTertiary: AppPalette.slate500,
    accent: AppPalette.orange400,
    accentText: AppPalette.orange300,
    onAccent: AppPalette.slate900,
    success: Color(0xFF4ADE80),
    successText: Color(0xFF86EFAC),
    successSurface: Color(0x1A4ADE80),
    danger: Color(0xFFF87171),
    dangerSurface: Color(0x1AF87171),
    info: AppPalette.sky400,
    infoSurface: Color(0x1A38BDF8),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.orange300, AppPalette.orange500],
    ),
    urgentGradient: LinearGradient(
      colors: [AppPalette.orange400, AppPalette.rose400],
    ),
    placeholderGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.slate800, AppPalette.slate700],
    ),
  );

  @override
  AppColorsExt copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentText,
    Color? onAccent,
    Color? success,
    Color? successText,
    Color? successSurface,
    Color? danger,
    Color? dangerSurface,
    Color? info,
    Color? infoSurface,
    Gradient? accentGradient,
    Gradient? urgentGradient,
    Gradient? placeholderGradient,
  }) {
    return AppColorsExt(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      successSurface: successSurface ?? this.successSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      accentGradient: accentGradient ?? this.accentGradient,
      urgentGradient: urgentGradient ?? this.urgentGradient,
      placeholderGradient: placeholderGradient ?? this.placeholderGradient,
    );
  }

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      accentGradient:
          Gradient.lerp(accentGradient, other.accentGradient, t)!,
      urgentGradient:
          Gradient.lerp(urgentGradient, other.urgentGradient, t)!,
      placeholderGradient:
          Gradient.lerp(placeholderGradient, other.placeholderGradient, t)!,
    );
  }
}

/// Быстрый доступ к семантическим цветам: `context.appColors`.
extension AppColorsX on BuildContext {
  AppColorsExt get appColors =>
      Theme.of(this).extension<AppColorsExt>() ?? AppColorsExt.light;
}

/// Отступы. В компонентах — только эти значения.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Радиусы. Один ритм на всё приложение.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const BorderRadius chip = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius photo = BorderRadius.all(Radius.circular(md));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(xl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Тени. Карточки в ленте теней не имеют — их отделяет фон и бордер.
/// Тень = элемент реально «поднялся» (шторки, FAB, модалки).
abstract final class AppShadows {
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

/// Моушн-токены. Анимируем только transform/opacity, ввод не блокируем.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Стаггер появления элементов списка.
  static const Duration stagger = Duration(milliseconds: 40);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
}
