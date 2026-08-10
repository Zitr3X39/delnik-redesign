import 'package:flutter/material.dart';

import '../../utils/categories.dart';
import '../theme/tokens.dart';
import '../widgets/category_chips.dart';
import '../widgets/feed_search_bar.dart';

/// Лента заявок v2.
///
/// Экран — чистый UI: получает готовые карточки и колбэки, не знает
/// про провайдеры и Supabase. Подключение к данным — через коннектор
/// (`home_feed_connector.dart`), адаптер `Job -> JobCardV2` в `adapters/`.
class HomeFeedScreenV2 extends StatelessWidget {
  const HomeFeedScreenV2({
    super.key,
    required this.cards,
    this.cityName = '',
    this.categories = kJobCategories,
    this.selectedCategory,
    this.onCategorySelected,
    this.onSearchTap,
    this.onCityTap,
    this.onLogoLongPress,
    this.onRefresh,
    this.isLoading = false,
    this.floatingActionButton,
  });

  /// Готовые карточки (обычно `JobCardV2` через адаптер).
  final List<Widget> cards;

  final String cityName;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?>? onCategorySelected;
  final VoidCallback? onSearchTap;
  final VoidCallback? onCityTap;

  /// Долгое нажатие на лого-слово (переключение дизайна в коннекторе).
  final VoidCallback? onLogoLongPress;

  final Future<void> Function()? onRefresh;
  final bool isLoading;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context).textTheme;

    final list = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: GestureDetector(
                  onLongPress: onLogoLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'дельник', style: t.headlineMedium),
                        TextSpan(
                          text: '.',
                          style:
                              t.headlineMedium?.copyWith(color: c.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: FeedSearchBar(
                  cityName: cityName,
                  onTap: onSearchTap,
                  onCityTap: onCityTap,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CategoryChips(
                categories: categories,
                selected: selectedCategory,
                onSelected: onCategorySelected ?? (_) {},
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
        if (isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (cards.isEmpty)
          const SliverFillRemaining(child: _EmptyFeed())
        else
          SliverList.separated(
            itemCount: cards.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, i) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _StaggeredIn(index: i, child: cards[i]),
            ),
          ),
        // Место под нижнюю навигацию (появится с каркасом роутера).
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: onRefresh != null
            ? RefreshIndicator(onRefresh: onRefresh!, child: list)
            : list,
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Пустое состояние: мягкая плитка с глифом, без дыры на экране.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: c.placeholderGradient,
                borderRadius: AppRadii.pill,
              ),
              child: Icon(Icons.handyman_outlined,
                  size: 40, color: c.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Пока пусто', style: t.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Загляните позже или измените категорию',
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Стаггер-появление карточек: fade + подъём на 16px, 40 мс на элемент
/// (максимум на первые 10 — дальше листать всё равно некому).
/// При системном reduced-motion анимация отключается целиком.
class _StaggeredIn extends StatelessWidget {
  const _StaggeredIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;

    final delay = AppMotion.stagger * index.clamp(0, 10);
    final total = AppMotion.normal + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, value, child) {
        final v = Interval(start, 1, curve: AppMotion.enterCurve)
            .transform(value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
