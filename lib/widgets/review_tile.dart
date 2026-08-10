import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/job_provider.dart';
import '../utils/format.dart';
import '../screens/user_profile_screen.dart';
import 'star_rating.dart';

/// Карточка отзыва. Слева — автор, комментарий и дата, справа — оценка,
/// которую поставил этот человек. По нажатию открывается профиль автора,
/// где можно проверить его отзывы. Свой отзыв можно изменить в течение 5 минут.
class ReviewTile extends StatelessWidget {
  final Review review;
  const ReviewTile({super.key, required this.review});

  Future<void> _showEditDialog(
      BuildContext context, JobProvider provider) async {
    int stars = review.stars;
    final controller = TextEditingController(text: review.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Изменить отзыв'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StarRating(
                rating: stars.toDouble(),
                size: 30,
                interactive: true,
                onRatingChanged: (v) =>
                    setDialogState(() => stars = v.toInt()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Текст отзыва',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed:
                  stars < 1 ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (saved != true || !context.mounted) return;
    final ok = await provider.editReview(
      reviewId: review.id,
      stars: stars,
      text: text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Отзыв изменён'
            : 'Не удалось изменить (возможно, 5 минут уже прошли)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final canOpen = review.authorId.isNotEmpty;
    final canEdit = provider.canEditReview(review);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: canOpen
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: review.authorId,
                        fallbackName: review.authorName,
                      ),
                    ),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF0EA5E9),
                  child: Text(
                    review.authorName.isNotEmpty
                        ? review.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (canOpen)
                            const Icon(Icons.chevron_right_rounded,
                                size: 18, color: Colors.black38),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(review.text,
                          style: const TextStyle(height: 1.35)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(formatDate(review.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                          if (canEdit) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _showEditDialog(context, provider),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_outlined,
                                        size: 13, color: Color(0xFF0284C7)),
                                    SizedBox(width: 3),
                                    Text('Изменить',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0284C7))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StarRating(rating: review.stars.toDouble(), size: 14),
                    const SizedBox(height: 3),
                    Text(
                      '${review.stars}.0',
                      style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
