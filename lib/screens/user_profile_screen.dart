import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/star_rating.dart';
import '../widgets/review_tile.dart';

/// Профиль другого пользователя (только просмотр): репутация, счётчики и
/// отзывы о его работе. Открывается по нажатию на автора отзыва.
class UserProfileScreen extends StatelessWidget {
  final String userId;
  final String fallbackName;

  /// Когда true — показываем репутацию пользователя как ЗАКАЗЧИКА (переход
  /// с карточки/деталей заявки), иначе — как исполнителя.
  final bool asEmployer;
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName = '',
    this.asEmployer = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final p = provider.performerById(userId);
    final name = (p != null && p.name.isNotEmpty)
        ? p.name
        : (fallbackName.isNotEmpty ? fallbackName : 'Пользователь');
    final reviews = provider.reviewsForUser(userId, asEmployer: asEmployer);
    final ratingValue = asEmployer
        ? provider.employerRatingFor(userId)
        : provider.ratingFor(userId);
    final ratingCount = asEmployer
        ? provider.employerRatingCountFor(userId)
        : provider.ratingCountFor(userId);
    final completed = provider.completedJobsFor(userId, asEmployer: asEmployer);
    return GlassScaffold(
      title: 'Профиль',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              radius: 24,
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.22),
                          blurRadius: 22,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StarRating(rating: ratingValue, size: 18),
                        const SizedBox(width: 7),
                        Text(
                          '${ratingValue.toStringAsFixed(1)} \u00b7 $ratingCount \u043e\u0446\u0435\u043d\u043e\u043a',
                          style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if ((p?.city ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 17, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(p!.city,
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                      label: 'Выполнено',
                      value: '$completed',
                      icon: Icons.task_alt),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                      label: 'Оценок',
                      value: '$ratingCount',
                      icon: Icons.star_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Отзывы о работе',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (reviews.isEmpty)
                    const Text('Пока нет отзывов',
                        style: TextStyle(color: Colors.black54))
                  else
                    ...reviews.take(20).map((r) => ReviewTile(review: r)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }
}
