import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/geo.dart';
import '../widgets/glass.dart';
import '../widgets/star_rating.dart';
import 'chat_screen.dart';
import 'edit_job_screen.dart';
import 'map_screen.dart';
import 'user_profile_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, provider, _) {
        Job? job;
        for (final j in provider.jobs) {
          if (j.id == jobId) {
            job = j;
            break;
          }
        }
        if (job == null) {
          return const GlassScaffold(
            title: 'Заявка',
            body: Center(
                child: Text('Заявка не найдена',
                    style: TextStyle(color: Colors.white))),
          );
        }
        final j = job;
        final userId = JobProvider.currentUserId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.registerView(jobId, userId);
        });
        final hasApplied = j.applicants.contains(userId);
        final isOwner = j.employerId == userId;
        final dist = formatDistance(distanceFromMe(j.lat, j.lng));

        return GlassScaffold(
          title: 'Детали заявки',
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(j.title,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800)),
                          ),
                          if (j.isClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('ЗАКРЫТО',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54)),
                            )
                          else if (j.isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt,
                                      size: 16,
                                      color: AppTheme.dangerColor),
                                  Text('СРОЧНО',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.dangerColor)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: '${j.address}  •  $dist',
                        onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobMapScreen(
                                        job: j, jobs: provider.visibleJobs),
                                  ),
                                ),
                      ),
                      _InfoRow(
                          icon: Icons.schedule,
                          text: formatDateTime(j.date)),
                      _InfoRow(
                          icon: Icons.group_outlined,
                          text:
                              'Нужно ${j.workersNeeded} чел. • откликнулось ${j.applicants.length}'),
                      _InfoRow(
                          icon: Icons.payments_outlined,
                          text: j.payText,
                          color: AppTheme.successColor),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: j.employerId,
                              fallbackName: j.employerName,
                              asEmployer: true,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 18, color: Colors.black54),
                              const SizedBox(width: 4),
                              const Text('Заказчик: ',
                                  style: TextStyle(color: Colors.black54)),
                              Flexible(
                                child: Text(j.employerName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                        decoration:
                                            TextDecoration.underline)),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Рейтинг заказчика: ',
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 13)),
                          StarRating(rating: j.rating, size: 16),
                          const SizedBox(width: 6),
                          Text(j.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_outlined,
                              size: 15, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text('${j.viewsCount} просмотров',
                              style: const TextStyle(
                                  color: Colors.black38, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Описание',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(j.description,
                          style: const TextStyle(
                              fontSize: 15, height: 1.4)),
                    ],
                  ),
                ),
                if (j.photos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _JobPhotos(photos: j.photos),
                ],
                const SizedBox(height: 12),
                _Applicants(job: j, isOwner: isOwner),
                const SizedBox(height: 12),
                const _SoberNotice(),
                const SizedBox(height: 16),
                _ActionArea(
                  job: j,
                  hasApplied: hasApplied,
                  isOwner: isOwner,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SoftActionButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Поделиться',
                        color: AppTheme.primaryColor,
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                            text: 'Подработка: ${j.title}\n'
                                '${j.payText}\n'
                                '${j.address}\n'
                                '${formatDateTime(j.date)}\n\n'
                                'Открыть заявку:\n'
                                'https://'
                                'delnik-app.ru/#/job/${j.id}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Текст заявки скопирован — можно поделиться'),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!isOwner) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SoftActionButton(
                          icon: Icons.flag_outlined,
                          label: 'Пожаловаться',
                          color: AppTheme.dangerColor,
                          onTap: () =>
                              _showJobReportDialog(context, provider, j),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionArea extends StatelessWidget {
  final Job job;
  final bool hasApplied;
  final bool isOwner;
  const _ActionArea({
    required this.job,
    required this.hasApplied,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();

    if (job.isClosed) {
      if (hasApplied && !isOwner) {
        return _WorkerActions(
          key: const ValueKey('closed-worker'),
          job: job,
        );
      }
      return const Center(
        child: Text('Заявка закрыта',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      );
    }

    if (isOwner) {
      return Column(
        children: [
          // После первого активного отклика условия блокируются. Когда все
          // отклики отменены или отклонены, редактирование снова доступно.
          BigButton(
            label: 'РЕДАКТИРОВАТЬ',
            icon: job.applicants.isEmpty
                ? Icons.edit_outlined
                : Icons.lock_outline,
            color: AppTheme.primaryColor,
            onPressed: job.applicants.isEmpty
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditJobScreen(job: job),
                      ),
                    );
                  }
                : null,
          ),
          if (job.applicants.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Пока есть активные отклики, менять условия нельзя. '
              'Если все отклики отменятся или будут отклонены, '
              'редактирование снова станет доступно.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 10),
          BigButton(
            label: 'ЗАКРЫТЬ ЗАЯВКУ',
            icon: Icons.lock_outline,
            color: AppTheme.dangerColor,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Закрыть заявку?'),
                  content: const Text(
                      'После закрытия на неё нельзя будет откликнуться.'),
                  actions: [
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('Отмена')),
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: const Text('Закрыть')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                final rateList = job.applicants
                    .map((id) => MapEntry(
                        id, provider.performerById(id)?.name ?? id))
                    .toList();
                provider.closeJob(job.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заявка закрыта')),
                );
                if (rateList.isNotEmpty) {
                  await showDialog(
                    context: context,
                    builder: (_) => _CloseRatingDialog(
                        jobId: job.id, applicants: rateList),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 6),
          // Удаление убирает заявку из облака, поэтому она пропадает
          // и у всех остальных пользователей.
          TextButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Удалить заявку?'),
                  content: const Text(
                      'Заявка исчезнет у всех пользователей вместе с перепиской '
                      'и фото. Отменить это нельзя.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Удалить',
                            style:
                                TextStyle(color: AppTheme.dangerColor))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                provider.deleteJob(job.id);
                Navigator.of(context).popUntil((r) => r.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заявка удалена')),
                );
              }
            },
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: Colors.white70),
            label: const Text('Удалить заявку',
                style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Чаты с откликнувшимися — в списке выше',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: hasApplied
          ? _WorkerActions(key: const ValueKey('applied'), job: job)
          : Column(
              key: const ValueKey('apply'),
              children: [
                BigButton(
                  label: job.isFull ? 'Мест нет' : 'Откликнуться',
                  icon: Icons.check_circle_outline,
                  color: AppTheme.successColor,
                  onPressed: job.isFull
                      ? null
                      : () async {
                          final err = await provider.applyToJob(
                              job.id, JobProvider.currentUserId);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err)),
                            );
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  'Осталось откликов сегодня: ${provider.appliesLeftToday} из ${JobProvider.maxAppliesPerDay}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Applicants extends StatelessWidget {
  final Job job;
  final bool isOwner;
  const _Applicants({required this.job, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();
    if (job.applicants.isEmpty) {
      return const SizedBox.shrink();
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Откликнулись исполнители',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              isOwner
                  ? job.isClosed
                      ? 'Теперь можно оценить исполнителей и оставить отзыв'
                      : 'До закрытия доступны чат и этапы работы'
                  : 'Список откликнувшихся',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          ...job.applicants
              .where((id) => !provider.isBlocked(id))
              .map((id) => isOwner
                  ? _ApplicantTile(job: job, id: id)
                  : _ApplicantRow(job: job, id: id)),
        ],
      ),
    );
  }
}

class _WorkerActions extends StatelessWidget {
  final Job job;
  const _WorkerActions({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();
    final me = JobProvider.currentUserId;
    final given = job.employerRatings[me] ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (job.isClosed) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Оцените работодателя',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Не кинул ли с оплатой, адекватный ли',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 8),
                Center(
                  child: StarRating(
                    rating: given,
                    size: 34,
                    interactive: true,
                    onRatingChanged: (v) {
                      final messenger = ScaffoldMessenger.of(context);
                      provider.rateEmployer(job.id, v);
                      provider.rateWithStars(
                        jobId: job.id,
                        targetId: job.employerId,
                        stars: v.toInt(),
                      );
                      messenger.showSnackBar(
                        SnackBar(
                            content: Text(
                                'Ваша оценка работодателю: ${v.toInt()}')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: given <= 0
                        ? null
                        : () => _showReviewTextDialog(
                              context,
                              provider,
                              job,
                              job.employerId,
                              given.toInt(),
                            ),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Добавить текстовый отзыв'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        BigButton(
          label: 'Открыть чат',
          icon: Icons.chat_bubble_outline,
          color: AppTheme.primaryColor,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                jobId: job.id,
                userId: JobProvider.currentUserId,
                peerName: job.employerName,
              ),
            ),
          ),
        ),
        if (!job.isClosed) ...[
          const SizedBox(height: 10),
          BigButton(
            label: 'Отменить отклик',
            icon: Icons.close,
            color: AppTheme.dangerColor,
            onPressed: () => provider.cancelApplication(
                job.id, JobProvider.currentUserId),
          ),
        ],
      ],
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  final Job job;
  final String id;
  const _ApplicantRow({required this.job, required this.id});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();
    final p = provider.performerById(id);
    final name = p?.name ?? id;
    final rating = p?.rating ?? 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF0EA5E9),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    '${rating.toStringAsFixed(1)} • ${p?.completedJobs ?? 0} работ${(p?.age ?? 0) > 0 ? ' • ${p!.age} лет' : ''}',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  final Job job;
  final String id;
  const _ApplicantTile({required this.job, required this.id});

  Future<void> _report(
      BuildContext context, JobProvider provider, String name) async {
    const reasons = [
      'Мошенничество / обман с оплатой',
      'Грубость / хамство',
      'Спам / реклама',
      'Другое',
    ];
    String? chosen;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Пожаловаться на $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined, size: 20),
                    title: Text(r),
                    onTap: () {
                      chosen = r;
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
        ],
      ),
    );
    if (chosen != null) {
      await provider.reportUser(id, chosen!);
      JobProvider.messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Жалоба отправлена. Спасибо!')),
      );
    }
  }

  Future<void> _confirmReject(
      BuildContext context, JobProvider provider, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Отклонить $name?'),
        content: const Text(
            'Исполнитель будет удалён из заявки и не сможет откликнуться '
            'на неё повторно. Он получит уведомление в чате.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Отклонить')),
        ],
      ),
    );
    if (ok != true) return;
    provider.rejectApplicant(job.id, id);
    JobProvider.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('$name отклонён от заявки')),
    );
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();
    final p = provider.performerById(id);
    final name = p?.name ?? id;
    final rating = p?.rating ?? 0.0;
    final given = job.ratings[id] ?? 0.0;
    final blocked = provider.isBlocked(id);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0EA5E9),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                        '${rating.toStringAsFixed(1)} • ${p?.completedJobs ?? 0} работ${(p?.age ?? 0) > 0 ? ' • ${p!.age} лет' : ''}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) async {
                  if (v == 'report') {
                    await _report(context, provider, name);
                  } else if (v == 'reject') {
                    await _confirmReject(context, provider, name);
                  } else if (v == 'unblock') {
                    provider.unblockUser(id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(children: [
                      Icon(Icons.flag_outlined,
                          size: 18, color: Colors.black54),
                      SizedBox(width: 10),
                      Text('Пожаловаться'),
                    ]),
                  ),
                  if (blocked)
                    const PopupMenuItem(
                      value: 'unblock',
                      child: Row(children: [
                        Icon(Icons.lock_open,
                            size: 18, color: Colors.black54),
                        SizedBox(width: 10),
                        Text('Разблокировать'),
                      ]),
                    )
                  else
                    const PopupMenuItem(
                      value: 'reject',
                      child: Row(children: [
                        Icon(Icons.person_remove_alt_1,
                            size: 18, color: Color(0xFFEF4444)),
                        SizedBox(width: 10),
                        Text('Отклонить от заявки'),
                      ]),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      jobId: job.id, userId: id, peerName: name),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.primaryColor),
              label: const Text('Открыть чат'),
            ),
          ),
          if (job.isClosed) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Оценка: ',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
                StarRating(
                  rating: given,
                  size: 22,
                  interactive: true,
                  onRatingChanged: (value) {
                    final messenger = ScaffoldMessenger.of(context);
                    provider.rateApplicant(job.id, id, value);
                    provider.rateWithStars(
                      jobId: job.id,
                      targetId: id,
                      stars: value.toInt(),
                    );
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text('Оценка ${value.toInt()} для $name')),
                    );
                  },
                ),
              ],
            ),
            if (given > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showReviewTextDialog(
                    context,
                    provider,
                    job,
                    id,
                    given.toInt(),
                    title: 'Отзыв об исполнителе',
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Добавить текстовый отзыв'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CloseRatingDialog extends StatefulWidget {
  final String jobId;
  final List<MapEntry<String, String>> applicants;
  const _CloseRatingDialog({required this.jobId, required this.applicants});

  @override
  State<_CloseRatingDialog> createState() => _CloseRatingDialogState();
}

class _CloseRatingDialogState extends State<_CloseRatingDialog> {
  final Map<String, double> _given = {};
  final Map<String, TextEditingController> _reviewControllers = {};
  bool _saving = false;

  TextEditingController _controllerFor(String id) =>
      _reviewControllers.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    for (final controller in _reviewControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();
    return AlertDialog(
      title: const Text('Оцените исполнителей'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.applicants.map((e) {
            final id = e.key;
            final name = e.value;
            final p = provider.performerById(id);
            final given = _given[id];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0EA5E9),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              '${(p?.rating ?? 0).toStringAsFixed(1)} • ${p?.completedJobs ?? 0} работ',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StarRating(
                        rating: given ?? 0,
                        size: 26,
                        interactive: true,
                        onRatingChanged: (value) {
                          setState(() => _given[id] = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controllerFor(id),
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Текстовый отзыв (необязательно)',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  if (_given.isEmpty) {
                    navigator.pop();
                    return;
                  }
                  setState(() => _saving = true);
                  for (final entry in _given.entries) {
                    provider.rateApplicant(
                        widget.jobId, entry.key, entry.value);
                    await provider.submitReview(
                      jobId: widget.jobId,
                      targetId: entry.key,
                      stars: entry.value.toInt(),
                      text: _controllerFor(entry.key).text,
                    );
                  }
                  if (!mounted) return;
                  navigator.pop();
                },
          child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
        ),
      ],
    );
  }
}

Future<void> _showJobReportDialog(
    BuildContext context, JobProvider provider, Job job) async {
  const reasons = [
    'Мошенничество или обман',
    'Спам или реклама',
    'Запрещённая работа',
    'Неверная оплата или описание',
    'Оскорбления',
    'Другое',
  ];
  final detailsController = TextEditingController();
  String? selected;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Пожаловаться на заявку'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...reasons.map((reason) => ListTile(
                    title: Text(reason),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      selected == reason
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected == reason
                          ? AppTheme.primaryColor
                          : Colors.black45,
                    ),
                    onTap: () => setDialogState(() => selected = reason),
                  )),
              TextField(
                controller: detailsController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    ),
  );
  final details = detailsController.text;
  detailsController.dispose();
  if (submitted != true || selected == null || !context.mounted) return;
  final ok = await provider.reportContent(
    targetId: job.employerId,
    jobId: job.id,
    reason: selected!,
    details: details,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'Жалоба отправлена' : 'Не удалось отправить жалобу'),
    ),
  );
}

Future<void> _showReviewTextDialog(
  BuildContext context,
  JobProvider provider,
  Job job,
  String targetId,
  int stars, {
  String title = 'Отзыв о работодателе',
}) async {
  final controller = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 500,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Расскажите, как прошла работа',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  final text = controller.text;
  controller.dispose();
  if (submitted != true || !context.mounted) return;
  final ok = await provider.submitReview(
    jobId: job.id,
    targetId: targetId,
    stars: stars,
    text: text,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? 'Отзыв сохранён' : 'Не удалось сохранить отзыв')),
  );
}

/// Мягкая пилюля-кнопка для вторичных действий («Поделиться», «Пожаловаться»).
class _SoftActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SoftActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback? onTap;
  const _InfoRow(
      {required this.icon, required this.text, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: tappable
                  ? AppTheme.primaryColor
                  : (color ?? Colors.black54)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 15,
                    color: tappable
                        ? AppTheme.primaryColor
                        : (color ?? Colors.black87),
                    fontWeight: (color != null || tappable)
                        ? FontWeight.w700
                        : FontWeight.normal)),
          ),
          if (tappable)
            const Icon(Icons.map_outlined,
                size: 18, color: AppTheme.primaryColor),
        ],
      ),
    );
    if (!tappable) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }
}


class _JobPhotos extends StatelessWidget {
  final List<String> photos;
  const _JobPhotos({required this.photos});

  void _open(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Фото',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _open(context, photos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photos[i],
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 110,
                      height: 110,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                    loadingBuilder: (c, w, p) => p == null
                        ? w
                        : const SizedBox(
                            width: 110,
                            height: 110,
                            child: Center(
                                child: CircularProgressIndicator())),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Напоминание о работе в трезвом виде — видно и заказчику, и исполнителю.
class _SoberNotice extends StatelessWidget {
  const _SoberNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB45309), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Работать только трезвым. За выход на работу в состоянии '
              'опьянения — блокировка без предупреждения и ответственность '
              'перед другой стороной.',
              style: TextStyle(
                  color: Color(0xFF92400E), fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
