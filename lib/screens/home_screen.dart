import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../utils/geo.dart';
import '../widgets/glass.dart';
import '../widgets/job_card.dart';
import '../utils/categories.dart';
import '../widgets/city_picker.dart';
import '../ui_v2/ui_v2_flag.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'job_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  JobSort? _sort; // null = сортировка выключена
  DateTime? _selectedDate; // null = все даты
  String? _category; // null = все категории
  bool _showCategories = false; // категории скрыты по умолчанию (двухуровневое меню)
  int _tab = 0; // 0 = список, 1 = карта, 2 = чаты, 3 = меню

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Применяет выбранную сортировку. Вызывается только для заявок
  /// своего города — чужие города всегда идут по удалённости.
  void _applySort(List<Job> list) {
    if (_sort == JobSort.distance) {
      list.sort((a, b) => distanceFromMe(a.lat, a.lng)
          .compareTo(distanceFromMe(b.lat, b.lng)));
    } else if (_sort == JobSort.pay) {
      list.sort((a, b) => b.payPerHour.compareTo(a.payPerHour));
    } else if (_sort == JobSort.recent) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  /// Закрытые заявки — вниз группы.
  List<Job> _closedLast(List<Job> src) => [
        ...src.where((j) => !j.isClosed),
        ...src.where((j) => j.isClosed),
      ];

  /// Элементы ленты: Job — карточка, String — заголовок раздела.
  ///
  /// Сначала идут заявки города пользователя, потом — остальные города
  /// по возрастанию расстояния: чем дальше город, тем ниже его заявки.
  List<Object> _feedItems(JobProvider provider, List<Job> jobs) {
    var list = [...jobs];
    // Поиск: скрываем несовпадающие.
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase().trim();
      list = list
          .where((j) =>
              j.title.toLowerCase().contains(q) ||
              j.description.toLowerCase().contains(q) ||
              j.address.toLowerCase().contains(q))
          .toList();
    }
    // Фильтр по категории.
    if (_category != null) {
      list = list.where((j) => j.category == _category).toList();
    }
    // Фильтр по выбранному дню.
    if (_selectedDate != null) {
      final d = _selectedDate!;
      list = list
          .where((j) =>
              j.date.year == d.year &&
              j.date.month == d.month &&
              j.date.day == d.day)
          .toList();
    }
    // Разделяем на «свой город» и остальные.
    final hasCity = provider.me.city.trim().isNotEmpty;
    final mine = <Job>[];
    final others = <Job>[];
    for (final j in list) {
      if (!hasCity || provider.isJobInMyCity(j)) {
        mine.add(j);
      } else {
        others.add(j);
      }
    }

    // Сортировка чипами касается только выбранного города.
    _applySort(mine);
    others.sort((a, b) => distanceFromMyCity(a.lat, a.lng)
        .compareTo(distanceFromMyCity(b.lat, b.lng)));

    final items = <Object>[..._closedLast(mine)];
    if (others.isNotEmpty) {
      items.add('Заявки из других городов');
      items.addAll(_closedLast(others));
    }
    return items;
  }

  /// Смена города прямо из ленты — тот же выбор, что и в профиле.
  Future<void> _changeCity() async {
    final provider = context.read<JobProvider>();
    final picked = await showCityPicker(context);
    if (picked == null || !mounted) return;
    provider.updateProfile(city: picked.name);
    setState(() {});
  }

  void _toggleSort(JobSort sort) {
    setState(() => _sort = _sort == sort ? null : sort);
  }

  /// «Ближе» включается только при определённой геопозиции.
  Future<void> _toggleNearest() async {
    if (_sort == JobSort.distance) {
      setState(() => _sort = null);
      return;
    }
    final provider = context.read<JobProvider>();
    final ok = await provider.ensureLocation();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Включите геолокацию, чтобы сортировать заявки по близости'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() => _sort = JobSort.distance);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, provider, _) {
        final items = _feedItems(provider, provider.visibleJobs);
        return GlassScaffold(
          title: 'Дельник',
          showBack: false,
          actions: [
            // Переключение на новый дизайн (ветка redesign/ui-v2).
            IconButton(
              tooltip: 'Новый дизайн (beta)',
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () => UiV2Flag.setEnabled(true),
            ),
            PopupMenuButton<JobListType>(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Меню',
              onSelected: (type) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => JobListScreen(type: type)),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: JobListType.favorites,
                  child: Row(
                    children: [
                      Icon(Icons.favorite_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Избранное'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: JobListType.applications,
                  child: Row(
                    children: [
                      Icon(Icons.how_to_reg_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Мои отклики'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: JobListType.history,
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('История'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          floatingActionButton: _tab == 0
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateJobScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Заявка'),
                )
              : null,
          bottomNavigationBar: _BottomNav(
            index: _tab,
            unread: provider.totalUnread,
            onChanged: (i) {
              if (i == _tab) return;
              setState(() => _tab = i);
            },
          ),
          body: !provider.loaded
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : IndexedStack(
                  index: _tab,
                  children: [
                    RepaintBoundary(
                        child: _buildList(context, provider, items)),
                    RepaintBoundary(child: MapView(jobs: provider.visibleJobs)),
                    const RepaintBoundary(child: MessagesView()),
                    const RepaintBoundary(
                        child: ProfileScreen(embedded: true)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildList(
      BuildContext context, JobProvider provider, List<Object> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: GlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Когда удобно?',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      _CityChip(
                        city: provider.me.city,
                        onTap: _changeCity,
                      ),
                    ],
                  ),
                ),
                _CalendarStrip(
                  selected: _selectedDate,
                  onSelect: (d) => setState(() => _selectedDate = d),
                ),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Работа или адрес',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _SortChip(
                        label: 'Ближе',
                        icon: Icons.near_me_rounded,
                        selected: _sort == JobSort.distance,
                        onTap: _toggleNearest,
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        label: 'Дороже',
                        icon: Icons.payments_outlined,
                        selected: _sort == JobSort.pay,
                        onTap: () => _toggleSort(JobSort.pay),
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        label: 'Недавние',
                        icon: Icons.auto_awesome_outlined,
                        selected: _sort == JobSort.recent,
                        onTap: () => _toggleSort(JobSort.recent),
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        label: 'Категории',
                        icon: Icons.category_outlined,
                        selected: _showCategories || _category != null,
                        onTap: () => setState(
                            () => _showCategories = !_showCategories),
                      ),
                    ],
                  ),
                ),
                if (_showCategories) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SortChip(
                          label: 'Все',
                          icon: Icons.apps_rounded,
                          selected: _category == null,
                          onTap: () => setState(() => _category = null),
                        ),
                        const SizedBox(width: 8),
                        ...kJobCategories.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _SortChip(
                                label: c,
                                icon: categoryIcon(c),
                                selected: _category == c,
                                onTap: () => setState(() =>
                                    _category = _category == c ? null : c),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('Заявок не найдено',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                        child: Row(
                          children: [
                            const Icon(Icons.travel_explore_rounded,
                                size: 18, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final job = item as Job;
                    final card = JobCard(
                      job: job,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(jobId: job.id),
                        ),
                      ),
                    );
                    // В вебе staggered-анимация карточек на CanvasKit давала
                    // «мигание»/артефакт при быстрых переходах — отдаём
                    // карточку без анимации, обёрнутую в RepaintBoundary.
                    if (kIsWeb) {
                      return RepaintBoundary(
                        key: ValueKey(job.id),
                        child: card,
                      );
                    }
                    return RepaintBoundary(
                      key: ValueKey(job.id),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds:
                              280 + index * 45 > 700 ? 700 : 280 + index * 45,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: card,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }



}

/// Компактный чип текущего города в шапке ленты.
class _CityChip extends StatelessWidget {
  final String city;
  final VoidCallback onTap;
  const _CityChip({required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = city.trim().isEmpty ? 'Выбрать город' : city.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_city_rounded,
                size: 15, color: Color(0xFF0284C7)),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: Color(0xFF0284C7)),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final int unread;
  final ValueChanged<int> onChanged;
  const _BottomNav(
      {required this.index, required this.unread, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF075985).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavItem(
              label: 'Заявки',
              icon: Icons.view_agenda_outlined,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
            _NavItem(
              label: 'Карта',
              icon: Icons.map_outlined,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
            _NavItem(
              label: 'Чаты',
              icon: Icons.chat_bubble_outline,
              selected: index == 2,
              badge: unread,
              onTap: () => onChanged(2),
            ),
            _NavItem(
              label: 'Профиль',
              icon: Icons.person_outline,
              selected: index == 3,
              onTap: () => onChanged(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: selected ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0284C7) : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon,
                      size: 22,
                      color: selected ? Colors.white : Colors.black54),
                  if (badge > 0)
                    Positioned(
                      right: -7,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 17),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(9),
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelect;
  const _CalendarStrip({required this.selected, required this.onSelect});

  static const _wd = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days =
        List.generate(14, (i) => today.add(Duration(days: i)));
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
        children: [
          _DayCell(
            top: 'Все',
            bottom: '•',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...days.map((d) {
            final sel = selected != null && _sameDay(selected!, d);
            return _DayCell(
              top: _wd[d.weekday - 1],
              bottom: '${d.day}',
              selected: sel,
              onTap: () => onSelect(sel ? null : d),
            );
          }),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback onTap;
  const _DayCell({
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 46,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0284C7)
              : const Color(0xFFF3F8FC),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.75)
                : const Color(0xFF0284C7).withValues(alpha: 0.10),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              top,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white70 : Colors.black45,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              bottom,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE0F2FE)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? const Color(0xFF0284C7).withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: selected
              ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    selected ? const Color(0xFF0284C7) : Colors.black45),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? const Color(0xFF0284C7) : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
