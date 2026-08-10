import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/performer.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import 'user_profile_screen.dart';

/// Панель разработчика: сводная статистика и список пользователей
/// с возможностью временной или постоянной блокировки.
///
/// Экран открывается только в режиме разработчика (вход по паролю).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();

    if (!provider.isModerator) {
      return GlassScaffold(
        title: 'Панель модератора',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Раздел доступен только подтверждённому модератору.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final stats = provider.adminStats;
    final users = provider.allUsers;
    final canModerate = provider.isModerator;

    return GlassScaffold(
      title: 'Панель модератора',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          if (!canModerate)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Право блокировки не подтверждено сервером. Статистика видна, но '
                'банить может только аккаунт из списка модераторов в базе.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
              ),
            ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Статистика',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatTile(
                      label: 'Пользователи',
                      value: '${stats['users'] ?? 0}',
                      hint: 'с анкетой из ${stats['usersTotal'] ?? 0}',
                      icon: Icons.people_alt_outlined,
                    ),
                    _StatTile(
                      label: 'Заблокировано',
                      value: '${stats['banned'] ?? 0}',
                      icon: Icons.block_rounded,
                      color: AppTheme.dangerColor,
                    ),
                    _StatTile(
                      label: 'Заявки',
                      value: '${stats['jobs'] ?? 0}',
                      hint: 'активных: ${stats['jobsActive'] ?? 0}',
                      icon: Icons.work_outline_rounded,
                    ),
                    _StatTile(
                      label: 'Закрытых',
                      value: '${stats['jobsClosed'] ?? 0}',
                      icon: Icons.lock_outline_rounded,
                    ),
                    _StatTile(
                      label: 'Новых за 24 ч',
                      value: '${stats['jobsToday'] ?? 0}',
                      hint: 'за неделю: ${stats['jobsWeek'] ?? 0}',
                      icon: Icons.trending_up_rounded,
                      color: AppTheme.successColor,
                    ),
                    _StatTile(
                      label: 'Отклики',
                      value: '${stats['applications'] ?? 0}',
                      icon: Icons.how_to_reg_outlined,
                    ),
                    _StatTile(
                      label: 'Отзывы',
                      value: '${stats['reviews'] ?? 0}',
                      icon: Icons.star_border_rounded,
                    ),
                    _StatTile(
                      label: 'Города',
                      value: '${stats['cities'] ?? 0}',
                      hint: 'где есть активные заявки',
                      icon: Icons.location_city_rounded,
                    ),
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
                Text('Пользователи (${users.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Заблокированные показаны сверху. Блокировка запрещает создавать '
                  'заявки и откликаться, а заявки такого пользователя скрываются из ленты.',
                  style: TextStyle(
                      color: Colors.black54, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Пока никого нет',
                        style: TextStyle(color: Colors.black54)),
                  ),
                for (final user in users)
                  _UserRow(user: user, provider: provider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.color = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EEF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          if (hint != null)
            Text(hint!,
                style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final Performer user;
  final JobProvider provider;

  const _UserRow({required this.user, required this.provider});

  String _banLabel() {
    if (!user.isBanned) return '';
    if (user.isPermanentlyBanned) return 'Заблокирован навсегда';
    final until = user.bannedUntil!;
    final left = until.difference(DateTime.now());
    if (left.inDays >= 1) return 'Блокировка ещё ${left.inDays} дн.';
    if (left.inHours >= 1) return 'Блокировка ещё ${left.inHours} ч.';
    return 'Блокировка ещё ${left.inMinutes} мин.';
  }

  Future<void> _ban(BuildContext context) async {
    final reasonController = TextEditingController();
    final choice = await showDialog<Duration?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Заблокировать ${user.name.isEmpty ? 'пользователя' : user.name}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Причина (увидит пользователь)',
                ),
                maxLength: 120,
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выберите срок блокировки:',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 8),
              _BanOption(
                label: 'На 15 минут',
                icon: Icons.timer_outlined,
                onTap: () =>
                    Navigator.pop(ctx, const Duration(minutes: 15)),
              ),
              _BanOption(
                label: 'На сутки',
                icon: Icons.today_rounded,
                onTap: () => Navigator.pop(ctx, const Duration(hours: 24)),
              ),
              _BanOption(
                label: 'На неделю',
                icon: Icons.date_range_rounded,
                onTap: () => Navigator.pop(ctx, const Duration(days: 7)),
              ),
              _BanOption(
                label: 'Навсегда',
                icon: Icons.block_rounded,
                color: AppTheme.dangerColor,
                onTap: () =>
                    Navigator.pop(ctx, const Duration(days: 36500)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );

    if (choice == null) {
      reasonController.dispose();
      return;
    }
    // «Навсегда» передаём в провайдер как duration == null.
    final permanent = choice.inDays >= 36500;
    final reason = reasonController.text;
    reasonController.dispose();
    final ok = await provider.banUser(
      user.id,
      duration: permanent ? null : choice,
      reason: reason,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Пользователь заблокирован'
            : 'Не удалось: сервер не подтвердил право модерации'),
      ),
    );
  }

  Future<void> _unban(BuildContext context) async {
    final ok = await provider.unbanUser(user.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Блокировка снята'
            : 'Не удалось: сервер не подтвердил право модерации'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banned = user.isBanned;
    final name = user.name.trim().isEmpty ? 'Без имени' : user.name.trim();
    final jobs = provider.jobsCountOf(user.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: banned ? const Color(0xFFFEF2F2) : const Color(0xFFF8FCFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: banned ? const Color(0xFFFECACA) : const Color(0xFFE7EEF4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: user.id),
                ),
              ),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (user.city.trim().isNotEmpty) user.city.trim(),
                      'заявок: $jobs',
                      'рейтинг: ${user.rating.toStringAsFixed(1)}',
                      if (!user.registered) 'анкета не заполнена',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                  if (banned) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.banReason.trim().isEmpty
                          ? _banLabel()
                          : '${_banLabel()} — ${user.banReason.trim()}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.dangerColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          banned
              ? TextButton(
                  onPressed: () => _unban(context),
                  child: const Text('Разбанить'),
                )
              : TextButton(
                  onPressed: () => _ban(context),
                  child: const Text('Бан',
                      style: TextStyle(color: AppTheme.dangerColor)),
                ),
        ],
      ),
    );
  }
}


class _BanOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _BanOption({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF0284C7);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          alignment: Alignment.centerLeft,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}
