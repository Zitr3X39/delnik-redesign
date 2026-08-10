import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/geo.dart';
import '../utils/categories.dart';
import 'glass.dart';
import 'star_rating.dart';
import '../screens/user_profile_screen.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final fav = provider.isFavorite(job.id);
    final empRating = provider.employerRatingFor(job.employerId);
    final empRatingCount = provider.employerRatingCountFor(job.employerId);
    final progress = job.workersNeeded > 0
        ? (job.applicants.length / job.workersNeeded).clamp(0.0, 1.0)
        : 0.0;
    // Адрес и метка видны всегда — расстояние считаем по координатам заявки.
    final dist = formatDistance(distanceFromMe(job.lat, job.lng));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        radius: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: const TextStyle(
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                ),
                if (job.isClosed) const _Badge(text: 'ЗАКРЫТО', color: Colors.grey),
                if (!job.isClosed && job.isUrgent)
                  const _Badge(
                      text: 'СРОЧНО',
                      color: AppTheme.dangerColor,
                      icon: Icons.bolt),
                GestureDetector(
                  onTap: () =>
                      context.read<JobProvider>().toggleFavorite(job.id),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      fav ? Icons.favorite : Icons.favorite_border,
                      color: fav ? AppTheme.dangerColor : Colors.black38,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            if (job.category.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: const Color(0xFF0284C7)
                            .withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(categoryIcon(job.category),
                          size: 13, color: const Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(job.category,
                          style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(job.address.isEmpty ? 'Адрес не указан' : job.address,
                        style: const TextStyle(color: Colors.black54))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(dist,
                      style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoPill(
                  icon: Icons.group_outlined,
                  text: '${job.workersNeeded} чел.',
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 5),
                      Text(job.payText,
                          style: const TextStyle(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE7EEF4),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  'Откликов ${job.applicants.length}/${job.workersNeeded}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.person_outline,
                    size: 13, color: Colors.black45),
                const SizedBox(width: 3),
                Flexible(
                  child: GestureDetector(
                    onTap: job.employerId.isEmpty
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(
                                  userId: job.employerId,
                                  fallbackName: job.employerName,
                                  asEmployer: true,
                                ),
                              ),
                            ),
                    child: Text(
                      job.employerName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: job.employerId.isEmpty
                              ? Colors.black54
                              : AppTheme.primaryColor,
                          decoration: job.employerId.isEmpty
                              ? null
                              : TextDecoration.underline),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if (empRatingCount > 0) ...[
                  StarRating(rating: empRating, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    empRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600),
                  ),
                ] else
                  const Text('нет оценок',
                      style:
                          TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                Text(
                  formatDateTime(job.date),
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Badge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 2),
          ],
          Text(text,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
