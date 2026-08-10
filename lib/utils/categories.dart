import 'package:flutter/material.dart';

/// Категории заявок (шабашка / дневная подработка).
/// Хранятся в поле Job.category как строка (пусто = без категории).
const List<String> kJobCategories = [
  'Грузчики',
  'Стройка/ремонт',
  'Уборка',
  'Переезд',
  'Демонтаж',
  'Двор и сад',
  'Склад',
  'Разнорабочие',
  'Другое',
];

/// Иконка для категории (используется в фильтре, форме и карточке).
IconData categoryIcon(String c) {
  switch (c) {
    case 'Грузчики':
      return Icons.inventory_2_outlined;
    case 'Стройка/ремонт':
      return Icons.construction_rounded;
    case 'Уборка':
      return Icons.cleaning_services_outlined;
    case 'Переезд':
      return Icons.local_shipping_outlined;
    case 'Демонтаж':
      return Icons.handyman_outlined;
    case 'Двор и сад':
      return Icons.grass_rounded;
    case 'Склад':
      return Icons.warehouse_outlined;
    case 'Разнорабочие':
      return Icons.engineering_outlined;
    default:
      return Icons.category_outlined;
  }
}
