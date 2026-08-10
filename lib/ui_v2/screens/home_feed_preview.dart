import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../models/job.dart';
import '../adapters/job_card_adapter.dart';
import '../theme/app_theme_v2.dart';
import 'home_feed_screen_v2.dart';

/// Превью ленты целиком. Запуск: `flutter widget-preview start`.

void _noop() {}

List<Job> _mockJobs() {
  final now = DateTime.now();
  return [
    Job(
      id: '1',
      title: 'Разгрузить фуру с мебелью, аккуратно занести на 3 этаж',
      description: '',
      address: 'ул. Ленина, 12',
      city: 'Калининград',
      lat: 54.7104,
      lng: 20.4522,
      workersNeeded: 5,
      payPerHour: 1500,
      date: now.add(const Duration(hours: 3)),
      employerName: 'Игорь',
      category: 'Грузчики',
      applicants: const ['a', 'b', 'c'],
    ),
    Job(
      id: '2',
      title: 'Срочно нужен грузчик на вечер, оплата сразу после работы',
      description: '',
      address: 'Московский проспект, 40',
      city: 'Калининград',
      lat: 54.72,
      lng: 20.5,
      workersNeeded: 3,
      payPerHour: 3000,
      isFixedPay: true,
      date: now.add(const Duration(hours: 5)),
      employerName: 'Анна',
      category: 'Стройка/ремонт',
      isUrgent: true,
      applicants: const ['x', 'y'],
    ),
    Job(
      id: '3',
      title: 'Помочь с переездом: собрать и разобрать мебель',
      description: '',
      address: 'ул. Гагарина, 7',
      city: 'Калининград',
      lat: 54.73,
      lng: 20.51,
      workersNeeded: 2,
      payPerHour: 1200,
      date: now.add(const Duration(days: 1)),
      employerName: 'Дмитрий',
      category: 'Переезд',
      applicants: const ['q', 'w'],
    ),
    Job(
      id: '4',
      title: 'Убрать квартиру после ремонта, 60 м²',
      description: '',
      address: 'ул. Тельмана, 3',
      city: 'Калининград',
      lat: 54.715,
      lng: 20.48,
      workersNeeded: 1,
      payPerHour: 900,
      date: now.subtract(const Duration(days: 1)),
      employerName: 'Ольга',
      category: 'Уборка',
      applicants: const ['z'],
      isClosed: true,
      closedAt: now,
    ),
  ];
}

Widget _frame(Widget child, {bool dark = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildLightThemeV2(),
    darkTheme: buildDarkThemeV2(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: child,
  );
}

HomeFeedScreenV2 _feed() {
  final jobs = _mockJobs();
  return HomeFeedScreenV2(
    cityName: 'Калининград',
    onCategorySelected: (_) {},
    onSearchTap: _noop,
    onCityTap: _noop,
    cards: [
      for (final (i, j) in jobs.indexed)
        j.toCardV2(
          isFavorite: i == 1,
          employerRating: i == 2 ? null : 4.8,
          onTap: _noop,
          onFavoriteTap: _noop,
        ),
    ],
  );
}

@Preview(name: 'Лента — светлая')
Widget homeFeedLight() => _frame(_feed());

@Preview(name: 'Лента — тёмная')
Widget homeFeedDark() => _frame(_feed(), dark: true);

@Preview(name: 'Лента — пустая')
Widget homeFeedEmpty() => _frame(
      HomeFeedScreenV2(
        cityName: 'Калининград',
        onCategorySelected: (_) {},
        cards: const [],
      ),
    );
