import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import '../theme/app_theme.dart';
import '../utils/censor.dart';
import '../utils/cities.dart';
import '../widgets/city_picker.dart';
import '../widgets/glass.dart';
import '../widgets/star_rating.dart';
import '../widgets/review_tile.dart';
import 'admin_screen.dart';
import 'job_detail_screen.dart';
import '../app_info.dart';

class ProfileScreen extends StatefulWidget {
  /// Когда true — экран встроен как вкладка (без своей шапки и нижнего бара,
  /// их предоставляет HomeScreen). Когда false — открывается как обычный экран.
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _deletingAccount = false;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _phoneController;

  /// Город выбирается из справочника — так мы знаем его координаты.
  String _city = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<JobProvider>().syncNow();
    });
    final me = context.read<JobProvider>().me;
    _nameController = TextEditingController(text: me.name);
    _ageController =
        TextEditingController(text: me.age > 0 ? '${me.age}' : '');
    _city = me.city;
    _phoneController = TextEditingController(text: me.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final city = _city.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя')),
      );
      return;
    }
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите город')),
      );
      return;
    }
    if (RegExp(r'[0-9]').hasMatch(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(noDigitsMessage)),
      );
      return;
    }
    if (containsProfanity(name) || containsProfanity(city)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(profanityMessage)),
      );
      return;
    }
    final age = int.tryParse(_ageController.text) ?? 0;
    if (age < 18 || age > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Возраст должен быть от 18 до 99 лет')),
      );
      return;
    }
    context.read<JobProvider>().updateProfile(
          name: name,
          age: age,
          city: city,
        );
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранён')),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
            'Чтобы снова войти, потребуется почта и код из письма. '
            'Анкета и история сохранятся.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Выйти')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<JobProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (r) => false);
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Профиль, заявки, сообщения, отзывы и фотографии будут удалены '
          'без возможности восстановления. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить',
                  style: TextStyle(color: AppTheme.dangerColor))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await context.read<JobProvider>().deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (r) => false);
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось удалить аккаунт. Повторите попытку позже.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final me = provider.me;
    final uid = JobProvider.currentUserId;
    final reviews = provider.reviewsForUser(uid);
    final ratingValue = provider.ratingFor(uid);
    final ratingCount = provider.ratingCountFor(uid);
    final completed = provider.completedJobsFor(uid);
    final body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, widget.embedded ? 110 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
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
                      radius: 43,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(me.name.isEmpty ? 'Без имени' : me.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                          '${ratingValue.toStringAsFixed(1)} · $ratingCount оценок',
                          style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (me.city.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 17, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(me.city,
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
                  child: _StatCard(
                      label: 'Выполнено',
                      value: '$completed',
                      icon: Icons.task_alt),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                      label: 'Оценок',
                      value: '$ratingCount',
                      icon: Icons.star_outline),
                ),
              ],
            ),
            if (reviews.isNotEmpty) ...[
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
                    ...reviews.take(10).map((r) => ReviewTile(review: r)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            GlassCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_ind_rounded,
                          size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text('Мои заявки',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${provider.myJobs.length}',
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Заявки остаются здесь даже после закрытия — ничего не пропадает.',
                    style: TextStyle(color: Colors.black54, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  if (provider.myJobs.isEmpty)
                    const Text('Вы ещё не создавали заявок',
                        style: TextStyle(color: Colors.black54))
                  else
                    ...provider.myJobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    JobDetailScreen(jobId: job.id),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F8FC),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      job.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (job.isClosed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey
                                            .withValues(alpha: 0.18),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text('ЗАКРЫТО',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w800)),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text('АКТИВНА',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.successColor,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Colors.black38),
                                ],
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('Личные данные',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: (_editing
                                  ? AppTheme.primaryColor
                                  : AppTheme.successColor)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _editing ? 'Редактирование' : 'Заполнено',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _editing
                                ? AppTheme.primaryColor
                                : AppTheme.successColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                            _editing ? Icons.check : Icons.edit_outlined,
                            color: AppTheme.primaryColor),
                        onPressed: () {
                          if (_editing) {
                            _save();
                          } else {
                            setState(() => _editing = true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    enabled: _editing,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Имя',
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ageController,
                    enabled: _editing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Возраст',
                        prefixIcon: Icon(Icons.cake_outlined)),
                  ),
                  const SizedBox(height: 12),
                  CityField(
                    value: _city,
                    enabled: _editing,
                    onSelected: (RuCity c) => setState(() => _city = c.name),
                  ),
                  const SizedBox(height: 12),
                  // Почта привязана и не редактируется.
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Почта (привязана)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: me.phone.isEmpty ? 'не указан' : me.phone,
                    ),
                    controller: _phoneController,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _editing
                        ? Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: BigButton(
                              label: 'СОХРАНИТЬ ИЗМЕНЕНИЯ',
                              icon: Icons.save_outlined,
                              color: AppTheme.primaryColor,
                              onPressed: _save,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Счётчики за сегодня',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Создано заявок: ${context.watch<JobProvider>().jobsUsedToday} из ${JobProvider.maxJobsPerDay}\nОткликов сделано: ${context.watch<JobProvider>().appliesUsedToday} из ${JobProvider.maxAppliesPerDay}',
                    style: const TextStyle(color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            ),
            // Панель видна только модератору, подтверждённому сервером.
            if (context.watch<JobProvider>().isModerator) ...[
              const SizedBox(height: 12),
              BigButton(
                label: 'ПАНЕЛЬ МОДЕРАТОРА',
                icon: Icons.insights_rounded,
                color: const Color(0xFF0F172A),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                ),
              ),
            ],
            const SizedBox(height: 12),
            BigButton(
              label: 'ВЫЙТИ ИЗ АККАУНТА',
              icon: Icons.logout_rounded,
              color: AppTheme.dangerColor,
              onPressed: _confirmLogout,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed:
                  _deletingAccount ? null : _confirmDeleteAccount,
              icon: _deletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined,
                      size: 18, color: Colors.white70),
              label: Text(
                _deletingAccount ? 'Удаляем аккаунт…' : 'Удалить аккаунт',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Дельник v$kAppVersion • created by $kAppAuthor',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    if (widget.embedded) return body;
    return GlassScaffold(
      title: 'Профиль',
      actions: [
        IconButton(
          icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
          onPressed: () {
            if (_editing) {
              _save();
            } else {
              setState(() => _editing = true);
            }
          },
        ),
      ],
      body: body,
    );
  }

}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
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
              style:
                  const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }
}
