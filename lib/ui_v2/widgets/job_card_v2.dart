import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/app_theme_v2.dart';

/// Состояние карточки заявки.
enum JobCardStatus { open, full, closed }

/// Карточка заявки v2.
///
/// Чистый UI-компонент: принимает готовые строки и колбэки, не знает
/// про `Job` и провайдеры. Адаптер `Job -> JobCardV2` живёт рядом
/// с экранами.
///
/// Правила (docs/redesign/DESIGN.md):
/// - цена — первая строка, табличные цифры;
/// - вся карточка — один тап-таргет; сердце — отдельная зона 44x44;
/// - единственный цветной элемент — тег «Срочно»;
/// - набранные/закрытые карточки затухают, а не выдёргиваются из ленты.
class JobCardV2 extends StatelessWidget {
  const JobCardV2({
    super.key,
    required this.title,
    required this.priceText,
    required this.addressText,
    required this.distanceText,
    required this.timeText,
    required this.employerName,
    required this.slotsLeft,
    required this.workersTotal,
    required this.categoryIcon,
    required this.onTap,
    this.photoUrl,
    this.employerRating,
    this.status = JobCardStatus.open,
    this.isUrgent = false,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  final String title;

  /// «1 500 ₽/час» или «3 000 ₽ за работу».
  final String priceText;

  final String addressText;

  /// «2,4 км».
  final String distanceText;

  /// «Сегодня, 18:00».
  final String timeText;

  final String employerName;
  final double? employerRating;

  final int slotsLeft;
  final int workersTotal;

  final String? photoUrl;
  final IconData categoryIcon;

  final JobCardStatus status;
  final bool isUrgent;
  final bool isFavorite;

  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context).textTheme;
    final dimmed = status != JobCardStatus.open;

    final card = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Photo(
                photoUrl: photoUrl,
                categoryIcon: categoryIcon,
                tag: switch (status) {
                  JobCardStatus.closed => _PhotoTag.closed,
                  JobCardStatus.full => _PhotoTag.full,
                  JobCardStatus.open when isUrgent => _PhotoTag.urgent,
                  JobCardStatus.open => null,
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              priceText,
                              style: AppTextStyles.price(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (onFavoriteTap != null)
                          _FavoriteButton(
                            isFavorite: isFavorite,
                            onTap: onFavoriteTap!,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      title,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '$distanceText · $addressText',
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: c.textTertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            timeText,
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (status == JobCardStatus.open) ...[
                          Text('  ·  ', style: t.bodySmall),
                          if (slotsLeft <= 1)
                            Text(
                              'Осталось последнее место',
                              style: t.labelMedium
                                  ?.copyWith(color: c.accentText),
                            )
                          else
                            Flexible(
                              child: Text(
                                'Осталось $slotsLeft из $workersTotal',
                                style: t.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employerName,
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (employerRating != null) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppPalette.amber500),
                          Text(
                            ' ${employerRating!.toStringAsFixed(1)}',
                            style: t.labelMedium
                                ?.copyWith(color: c.textPrimary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return _PressScale(
      child: dimmed ? Opacity(opacity: 0.55, child: card) : card,
    );
  }
}

/// Сердце избранного: минимальный тап-таргет 44x44,
/// визуально выходит за верхний правый угол текста.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Transform.translate(
      offset: const Offset(10, -10),
      child: IconButton(
        onPressed: onTap,
        tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        iconSize: 22,
        color: isFavorite ? c.danger : c.textTertiary,
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        ),
      ),
    );
  }
}

enum _PhotoTag { urgent, full, closed }

/// Фото 96x96: либо снимок, либо плитка с глифом категории.
/// В углу — единственный цветной тег карточки.
class _Photo extends StatelessWidget {
  const _Photo({
    required this.categoryIcon,
    this.photoUrl,
    this.tag,
  });

  final String? photoUrl;
  final IconData categoryIcon;
  final _PhotoTag? tag;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    final Widget image = hasPhoto
        ? Image.network(
            photoUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : _PhotoPlaceholder(icon: categoryIcon),
            errorBuilder: (context, error, stackTrace) =>
                _PhotoPlaceholder(icon: categoryIcon),
          )
        : _PhotoPlaceholder(icon: categoryIcon);

    final Widget? tagWidget = switch (tag) {
      _PhotoTag.urgent => _Tag(
          label: 'СРОЧНО',
          icon: Icons.bolt_rounded,
          decoration:
              BoxDecoration(gradient: c.urgentGradient, borderRadius: AppRadii.chip),
        ),
      _PhotoTag.full => _Tag(
          label: 'НАБРАНО',
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.chip,
            border: Border.all(color: c.border),
          ),
          textColor: c.textSecondary,
        ),
      _PhotoTag.closed => _Tag(
          label: 'ЗАКРЫТО',
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.chip,
            border: Border.all(color: c.border),
          ),
          textColor: c.textSecondary,
        ),
      null => null,
    };

    return ClipRRect(
      borderRadius: AppRadii.photo,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (tagWidget != null)
              Positioned(left: 4, top: 4, child: tagWidget),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: c.placeholderGradient),
      child: Center(
        child: Icon(icon, size: 32, color: c.textTertiary),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.decoration,
    this.icon,
    this.textColor,
  });

  final String label;
  final BoxDecoration decoration;
  final IconData? icon;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    // Текст на градиенте — тёмный: белый на оранжевом не проходит
    // контраст даже 3:1 (как чёрный на жёлтом у Яндекса).
    final color = textColor ?? AppPalette.slate900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Тап по карточке: мягкий scale 0.985 с возвратом.
/// Анимируется только transform, ввод не блокируется.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
