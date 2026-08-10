import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class AppTheme {
  // Небесно-голубая палитра (облака + небо).
  static const Color primaryColor = Color(0xFF0284C7);
  static const Color accentColor = Color(0xFFFB923C);
  static const Color successColor = Color(0xFF16A34A);
  static const Color dangerColor = Color(0xFFEF4444);

  // Градиент фона — от светлого неба к голубому.
  static const List<Color> bgGradient = [
    Color(0xFF7DD3FC),
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
  ];

  static const String fontFamily = 'NotoSans';

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // На iOS — родной Cupertino-переход: работает свайп «назад» от
        // левого края экрана (нативный жест iOS). Кастомный fade его ломал.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: _SmoothPageTransitions(),
        TargetPlatform.windows: _SmoothPageTransitions(),
        TargetPlatform.linux: _SmoothPageTransitions(),
      },
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 6,
        shadowColor: Color(0x80FB923C),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      headerBackgroundColor: primaryColor,
      headerForegroundColor: Colors.white,
      dividerColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      todayBorder: const BorderSide(color: primaryColor, width: 1.5),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// Плавный переход между экранами: мягкое проявление (без сдвига).
class _SmoothPageTransitions extends PageTransitionsBuilder {
  const _SmoothPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // В вебе (CanvasKit) даже плавное проявление при быстрых переходах
    // между разделами иногда оставляло артефакт на кадр — отдаём сразу.
    if (kIsWeb) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // Только плавное проявление, без сдвига: раньше сдвиг на 3% оставлял
    // на один кадр прозрачную полосу у края экрана — сквозь неё и был
    // виден «артефакт» при быстрых переходах между экранами.
    return FadeTransition(opacity: curved, child: child);
  }
}
