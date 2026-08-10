import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../theme/app_theme_v2.dart';
import 'job_card_v2.dart';

/// Превью карточки заявки. Запуск: `flutter widget-preview start`.
///
/// Кейсы покрывают матрицу состояний: обычная / срочная с последним
/// местом / набранная / тёмная тема.

void _noop() {}

Widget _frame(Widget child, {bool dark = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildLightThemeV2(),
    darkTheme: buildDarkThemeV2(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

@Preview(name: 'Обычная')
Widget jobCardV2Regular() => _frame(
      const JobCardV2(
        title: 'Разгрузить фуру с мебелью, аккуратно занести на 3 этаж',
        priceText: '1 500 ₽/час',
        addressText: 'ул. Ленина, 12',
        distanceText: '2,4 км',
        timeText: 'Сегодня, 18:00',
        employerName: 'Игорь',
        employerRating: 4.8,
        slotsLeft: 2,
        workersTotal: 5,
        categoryIcon: Icons.local_shipping_outlined,
        onTap: _noop,
        onFavoriteTap: _noop,
      ),
    );

@Preview(name: 'Срочная · последнее место · в избранном')
Widget jobCardV2Urgent() => _frame(
      const JobCardV2(
        title: 'Срочно нужен грузчик на вечер, оплата сразу после работы',
        priceText: '3 000 ₽ за работу',
        addressText: 'Московский проспект, 40',
        distanceText: '800 м',
        timeText: 'Сегодня, 20:00',
        employerName: 'Анна',
        employerRating: 4.9,
        slotsLeft: 1,
        workersTotal: 3,
        categoryIcon: Icons.handyman_outlined,
        isUrgent: true,
        isFavorite: true,
        onTap: _noop,
        onFavoriteTap: _noop,
      ),
    );

@Preview(name: 'Набрана (затухает, не исчезает)')
Widget jobCardV2Full() => _frame(
      const JobCardV2(
        title: 'Помочь с переездом: собрать и разобрать мебель',
        priceText: '1 200 ₽/час',
        addressText: 'ул. Гагарина, 7',
        distanceText: '5,1 км',
        timeText: 'Завтра, 10:00',
        employerName: 'Дмитрий',
        slotsLeft: 0,
        workersTotal: 2,
        categoryIcon: Icons.move_to_inbox_outlined,
        status: JobCardStatus.full,
        onTap: _noop,
        onFavoriteTap: _noop,
      ),
    );

@Preview(name: 'Тёмная тема')
Widget jobCardV2Dark() => _frame(
      const JobCardV2(
        title: 'Разгрузить фуру с мебелью, аккуратно занести на 3 этаж',
        priceText: '1 500 ₽/час',
        addressText: 'ул. Ленина, 12',
        distanceText: '2,4 км',
        timeText: 'Сегодня, 18:00',
        employerName: 'Игорь',
        employerRating: 4.8,
        slotsLeft: 2,
        workersTotal: 5,
        categoryIcon: Icons.local_shipping_outlined,
        isUrgent: true,
        onTap: _noop,
        onFavoriteTap: _noop,
      ),
      dark: true,
    );
