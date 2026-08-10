import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Верхняя плашка ленты: поиск + город. Как у Авито — поиск всегда
/// под пальцем, но в наших токенах и радиусах.
///
/// Пока это «псевдо-поле»: тап открывает поисковый флоу (отдельная
/// задача), поэтому виджет принимает колбэки, а не контроллер.
class FeedSearchBar extends StatelessWidget {
  const FeedSearchBar({
    super.key,
    this.hintText = 'Найти подработку',
    this.cityName = '',
    this.onTap,
    this.onCityTap,
  });

  final String hintText;
  final String cityName;
  final VoidCallback? onTap;
  final VoidCallback? onCityTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: c.textTertiary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      hintText,
                      style: t.bodyMedium?.copyWith(color: c.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (cityName.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: onCityTap,
            child: Container(
              height: 48,
              constraints: const BoxConstraints(maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: c.accentText),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      cityName,
                      style: t.labelMedium?.copyWith(color: c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
