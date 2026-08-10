import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Горизонтальная лента категорий над списком заявок.
///
/// Невыбранные — тихие белые чипы с бордером. Выбранная — единственная
/// «горячая» плашка блока: акцентный градиент + тёмный текст (контраст).
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;

  /// null = «Все».
  final String? selected;

  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final value = i == 0 ? null : categories[i - 1];
          return _Chip(
            label: value ?? 'Все',
            selected: value == selected,
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: AppRadii.pill,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enterCurve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? c.accentGradient : null,
          color: selected ? null : c.surface,
          borderRadius: AppRadii.pill,
          border: selected ? null : Border.all(color: c.border),
        ),
        child: Text(
          label,
          style: t.labelMedium?.copyWith(
            color: selected ? c.onAccent : c.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
