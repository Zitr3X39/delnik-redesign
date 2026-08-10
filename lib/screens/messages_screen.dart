import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'chat_screen.dart';

/// Одна переписка в списке чатов.
class _Thread {
  final String jobId;
  final String threadUserId; // ключ переписки (id исполнителя)
  final String peerName; // собеседник
  final String jobTitle;
  final bool jobClosed;
  final ChatMessage last;
  final int unread;
  _Thread({
    required this.jobId,
    required this.threadUserId,
    required this.peerName,
    required this.jobTitle,
    required this.jobClosed,
    required this.last,
    required this.unread,
  });
}

/// Вкладка «Чаты»: все переписки текущего пользователя —
/// как работодателя (с откликнувшимися), так и исполнителя (с заказчиком).
class MessagesView extends StatelessWidget {
  const MessagesView({super.key});

  List<_Thread> _threads(JobProvider provider) {
    final me = JobProvider.currentUserId;
    final list = <_Thread>[];
    for (final job in provider.jobs) {
      if (job.employerId == me) {
        for (final applicantId in job.applicants) {
          if (provider.isBlocked(applicantId)) continue;
          final msgs = job.chats[applicantId];
          if (msgs == null || msgs.isEmpty) continue;
          list.add(_Thread(
            jobId: job.id,
            threadUserId: applicantId,
            peerName:
                provider.performerById(applicantId)?.name ?? 'Исполнитель',
            jobTitle: job.title,
            jobClosed: job.isClosed,
            last: msgs.last,
            unread: msgs
                .where((m) => m.senderId != me && m.readAt == null)
                .length,
          ));
        }
      } else if (job.applicants.contains(me)) {
        if (provider.isBlocked(job.employerId)) continue;
        final msgs = job.chats[me];
        if (msgs == null || msgs.isEmpty) continue;
        list.add(_Thread(
          jobId: job.id,
          threadUserId: me,
          peerName: job.employerName,
          jobTitle: job.title,
          jobClosed: job.isClosed,
          last: msgs.last,
          unread: msgs
              .where((m) => m.senderId != me && m.readAt == null)
              .length,
        ));
      }
    }
    list.sort((a, b) => b.last.time.compareTo(a.last.time));
    return list;
  }

  String _timeLabel(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    if (d == today) return '${two(t.hour)}:${two(t.minute)}';
    if (d == today.subtract(const Duration(days: 1))) return 'вчера';
    return '${two(t.day)}.${two(t.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final threads = _threads(provider);
    if (threads.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Чатов пока нет.\nОткликнитесь на заявку или дождитесь отклика — '
            'переписка появится здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.4),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: threads.length,
      itemBuilder: (context, i) {
        final t = threads[i];
        final mine = t.last.senderId == JobProvider.currentUserId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            radius: 20,
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  jobId: t.jobId,
                  userId: t.threadUserId,
                  peerName: t.peerName,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF0EA5E9),
                  child: Text(
                    t.peerName.isNotEmpty
                        ? t.peerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel(t.last.time),
                            style: const TextStyle(
                                color: Colors.black45, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.jobTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (t.jobClosed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('закрыто',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mine ? 'Вы: ${t.last.text}' : t.last.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.unread > 0
                                    ? Colors.black87
                                    : Colors.black54,
                                fontWeight: t.unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (t.unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                '${t.unread}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
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
        );
      },
    );
  }
}
