import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';
import '../models/performer.dart';
import '../models/review.dart';
import '../services/reminder_service.dart';
import '../services/push_service.dart';
import '../widgets/incoming_toast.dart';
import '../utils/geo.dart';
import '../utils/cities.dart';
import 'package:geolocator/geolocator.dart';

enum JobSort { distance, pay, recent }

class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}

class PhotoUploadResult {
  final String? url;
  final String? error;

  const PhotoUploadResult.success(this.url) : error = null;
  const PhotoUploadResult.failure(this.error) : url = null;

  bool get isSuccess => url != null && error == null;
}

class _ImageUploadFormat {
  final String extension;
  final String contentType;
  const _ImageUploadFormat(this.extension, this.contentType);
}

class _CachedChatPhotoUrl {
  final String url;
  final DateTime validUntil;

  const _CachedChatPhotoUrl(this.url, this.validUntil);
}

class JobProvider extends ChangeNotifier with WidgetsBindingObserver {
  static String currentUserId = 'currentUser';
  static String? pendingJobId;

  static String takePendingRoute() {
    final id = pendingJobId;
    pendingJobId = null;
    return id == null || id.isEmpty ? '/home' : '/job/$id';
  }
  // Активный чат — чтобы не показывать всплывающее уведомление, когда ты уже в нём.
  static String? activeChatJobId;
  static String? activeChatThreadId;
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static const String _jobsKey = 'jobs_v2';
  static const String _perfKey = 'performers_v1';
  final Map<String, _CachedChatPhotoUrl> _chatPhotoUrlCache = {};
  final Set<String> _chatPhotoUrlPending = {};

  /// Синхронно возвращает signed-ссылку из кэша. При промахе или устаревании
  /// один раз запускает фоновое обновление и уведомляет подписчиков.
  String? peekChatPhotoUrl(String path) {
    if (!isChatPhotoPath(path)) return null;

    final cached = _chatPhotoUrlCache[path];
    if (cached != null && DateTime.now().isBefore(cached.validUntil)) {
      return cached.url;
    }

    if (_chatPhotoUrlPending.add(path)) {
      resolveChatPhotoUrl(path).whenComplete(() {
        _chatPhotoUrlPending.remove(path);
        notifyListeners();
      });
    }

    // Пока идёт фоновое обновление, отдаём устаревшую ссылку: signed URL живёт
    // 60 минут, а кэш считается свежим 50, поэтому запас ещё есть.
    return cached?.url;
  }
  static const String _regKey = 'registered_v1';
  static const String _legacyLimitsKey = 'limits_v1';
  static const String _limitsKeyPrefix = 'limits_v2_';
  String get _limitsKey => '$_limitsKeyPrefix$currentUserId';
  static const String _guestIdKey = 'guest_id_v1';
  static const String _pendingJobsKey = 'pending_jobs_v1';

  // Суточные лимиты.
  static const int maxJobsPerDay = 3; // работодатель: 3 заявки в день
  static const int maxAppliesPerDay = 10; // исполнитель: 10 откликов в день
  static const int urgencyPrice = 100; // ₽ за срочность (поднятие в топ)
  static const int maxPhotoUploadBytes = 8 * 1024 * 1024;

  List<Job> _jobs = [];
  List<Job> get jobs => _jobs;

  /// Синхронизирует локальные напоминания «за 3 часа» с текущим
  /// состоянием откликов. Вызывается после любых изменений заявок.
  void _syncReminders() {
    ReminderService.instance.sync(_jobs, currentUserId);
  }

  // Список для показа текущему пользователю: скрывает заполненные
  // чужие заявки, но оставляет их откликнувшимся и работодателю.
  List<Job> get visibleJobs => _jobs
      .where((j) =>
          !j.isExpired &&
          (!j.isClosed || j.isInCloseGracePeriod) &&
          j.isVisibleTo(currentUserId) &&
          _employerVisible(j.employerId) &&
          !isBlocked(j.employerId))
      .toList();

  /// Показывать ли заявки этого заказчика. Прячем, если его профиль удалён
  /// (аккаунт удалён) или он вышел из аккаунта более 3 часов назад.
  bool _employerVisible(String employerId) {
    if (employerId == currentUserId) return true;
    if (!_remoteReady || _performers.isEmpty) return true;
    final p = _performers[employerId];
    if (p == null) return false;
    // Заблокированные админом аккаунты не показываем в ленте.
    if (p.isBanned) return false;
    final lo = p.loggedOutAt;
    if (lo != null &&
        DateTime.now().difference(lo) > const Duration(hours: 3)) {
      return false;
    }
    return true;
  }

  Timer? _expiryTimer;
  Timer? _closeVisibilityTimer;
  Timer? _messagePollTimer;
  Timer? _jobPollTimer;
  Timer? _jobRetryTimer;
  final List<RealtimeChannel> _realtimeChannels = [];
  bool _refreshing = false;
  int _refreshTick = 0;
  final Map<String, Job> _pendingJobSync = {};
  final Map<String, Performer> _performers = {};
  Map<String, Performer> get performers => _performers;
  final List<Review> _reviews = [];
  List<Review> reviewsForUser(String userId, {bool? asEmployer}) => _reviews
      .where((r) => r.targetId == userId && r.text.trim().isNotEmpty && (asEmployer == null || _isEmployerReview(r) == asEmployer))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Все отзывы о пользователе (включая без текста) — для подсчёта рейтинга.
  List<Review> _reviewsAbout(String userId) =>
      _reviews.where((r) => r.targetId == userId).toList();

  /// Средняя оценка по полученным отзывам. Отзывы надёжно
  /// синхронизируются через таблицу reviews, поэтому берём рейтинг из них.
  /// Если отзывов ещё нет — откат на значение из профиля.
  double ratingFor(String userId) {
    final rated = _reviewsAbout(userId).where((r) => r.stars > 0).toList();
    if (rated.isEmpty) return _performers[userId]?.rating ?? 0;
    final sum = rated.fold<int>(0, (a, r) => a + r.stars);
    return sum / rated.length;
  }

  int ratingCountFor(String userId) {
    final count = _reviewsAbout(userId).where((r) => r.stars > 0).length;
    final profile = _performers[userId]?.ratingCount ?? 0;
    return count > profile ? count : profile;
  }

  int completedJobsFor(String userId, {bool? asEmployer}) {
    final jobIds = _reviewsAbout(userId).where((r) => asEmployer == null || _isEmployerReview(r) == asEmployer).map((r) => r.jobId).toSet();
    final profile = (asEmployer == true) ? 0 : (_performers[userId]?.completedJobs ?? 0);
    return jobIds.length > profile ? jobIds.length : profile;
  }

  /// Отзыв — О ЗАКАЗЧИКЕ (оставлен исполнителем по заявке этого заказчика).
  bool _isEmployerReview(Review r) {
    final job = _jobById(r.jobId);
    if (job == null) return true; // роль неизвестна — учитываем как есть
    return job.employerId == r.targetId;
  }

  /// Рейтинг ЗАКАЗЧИКА по отзывам исполнителей. Показывается и на карточке
  /// в ленте, и в профиле — берём из отзывов (единый источник правды).
  double employerRatingFor(String userId) {
    final rated = _reviews
        .where((r) =>
            r.targetId == userId && r.stars > 0 && _isEmployerReview(r))
        .toList();
    if (rated.isEmpty) return _performers[userId]?.employerRating ?? 0;
    final sum = rated.fold<int>(0, (a, r) => a + r.stars);
    return sum / rated.length;
  }

  int employerRatingCountFor(String userId) {
    final count = _reviews
        .where((r) =>
            r.targetId == userId && r.stars > 0 && _isEmployerReview(r))
        .length;
    final profile = _performers[userId]?.employerRatingCount ?? 0;
    return count > profile ? count : profile;
  }

  /// Принудительно обновить данные из облака (профили/отзывы/заявки).
  Future<void> syncNow() => _refreshFromRemote();

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _registered = false;
  bool get isRegistered => _registered;


  /// Подтверждено ли право модерации НА СЕРВЕРЕ (таблица moderators).
  /// Только серверная таблица moderators даёт право блокировки;
  /// от того, чей идентификатор внесён в таблицу вручную через psql.
  bool _isModerator = false;
  bool get isModerator => _isModerator;

  /// Блокировки с сервера: id пользователя -> до какого момента.
  final Map<String, DateTime> _bans = {};
  final Map<String, String> _banReasons = {};

  // Счётчики за текущий день.
  String _limitDate = '';
  int _jobsToday = 0;
  int _appliesToday = 0;

  Performer get me =>
      _performers[currentUserId] ??
      (_performers[currentUserId] =
          Performer(id: currentUserId, name: 'Вы', city: 'Уфа'));

  Performer? performerById(String id) => _performers[id];

  /// Город заявки. У старых заявок поля нет — определяем по координатам метки.
  String cityOfJob(Job job) {
    final own = job.city.trim();
    if (own.isNotEmpty) return own;
    return RuCities.nearest(job.lat, job.lng)?.name ?? '';
  }

  /// Относится ли заявка к городу пользователя.
  bool isJobInMyCity(Job job) {
    final mine = me.city.trim();
    if (mine.isEmpty) return true;
    final jobCity = cityOfJob(job);
    if (jobCity.isNotEmpty) {
      return normalizeCity(jobCity) == normalizeCity(mine);
    }
    // Город не определён — считаем «своим», если метка рядом с городом.
    return isNearMyCity(job.lat, job.lng);
  }

  /// Текст блокировки для текущего пользователя. null — блокировки нет.
  String? get banMessage {
    final p = _performers[currentUserId];
    if (p == null || !p.isBanned) return null;
    final reason = p.banReason.trim();
    final suffix = reason.isEmpty ? '' : ' Причина: $reason';
    if (p.isPermanentlyBanned) {
      return 'Ваш аккаунт заблокирован.$suffix';
    }
    final until = p.bannedUntil!;
    final d = until.difference(DateTime.now());
    final left = d.inHours >= 24
        ? '${d.inDays} дн.'
        : d.inHours >= 1
            ? '${d.inHours} ч.'
            : '${d.inMinutes} мин.';
    return 'Ваш аккаунт временно заблокирован, осталось $left.$suffix';
  }

  void _snack(String text) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }

  Job? _jobById(String id) {
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _rollDay() {
    final t = _todayKey();
    if (_limitDate != t) {
      _limitDate = t;
      _jobsToday = 0;
      _appliesToday = 0;
    }
  }

  /// Loads daily counters for the current uid only.
  /// The old device-wide key is deliberately not migrated because it may
  /// belong to another account that previously used this device.
  Future<void> _loadCountersForCurrentUser(
      [SharedPreferences? existingPrefs]) async {
    _limitDate = '';
    _jobsToday = 0;
    _appliesToday = 0;
    try {
      final prefs = existingPrefs ?? await SharedPreferences.getInstance();
      final limRaw = prefs.getString(_limitsKey);
      if (limRaw != null) {
        final decoded = jsonDecode(limRaw);
        if (decoded is Map) {
          _limitDate = '${decoded['date'] ?? ''}';
          final jobs = decoded['jobs'];
          final applies = decoded['applies'];
          if (jobs is num) _jobsToday = jobs.toInt();
          if (applies is num) _appliesToday = applies.toInt();
        }
      }
      await prefs.remove(_legacyLimitsKey);
    } catch (_) {
      _limitDate = '';
      _jobsToday = 0;
      _appliesToday = 0;
    }
    _rollDay();
  }

  /// Сколько заявок работодатель ещё может создать сегодня.
  int get jobsLeftToday {
    _rollDay();
    final left = maxJobsPerDay - _jobsToday;
    return left < 0 ? 0 : left;
  }

  /// Сколько откликов исполнитель ещё может сделать сегодня.
  int get appliesLeftToday {
    _rollDay();
    final left = maxAppliesPerDay - _appliesToday;
    return left < 0 ? 0 : left;
  }

  /// Сколько заявок создано сегодня.
  int get jobsUsedToday {
    _rollDay();
    return _jobsToday;
  }

  /// Сколько откликов сделано сегодня.
  int get appliesUsedToday {
    _rollDay();
    return _appliesToday;
  }

  Future<void> init() async {
    final authenticatedId =
        Supabase.instance.client.auth.currentUser?.id;
    currentUserId = authenticatedId ??
        'guest_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (authenticatedId == null) {
        var guestId = prefs.getString(_guestIdKey);
        if (guestId == null || guestId.isEmpty || guestId == 'currentUser') {
          guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
          await prefs.setString(_guestIdKey, guestId);
        }
        currentUserId = guestId;
      }
      _registered = prefs.getBool(_regKey) ?? false;
      // Удаляем старый локальный флаг сверхправ.
      await prefs.remove('devmode_v1');

      await _loadCountersForCurrentUser(prefs);

      final perfRaw = prefs.getString(_perfKey);
      if (perfRaw != null) {
        final List decoded = jsonDecode(perfRaw) as List;
        for (final e in decoded) {
          final p = Performer.fromJson(e as Map<String, dynamic>);
          _performers[p.id] = p;
        }
      } else {
        _seedPerformers();
      }
      // Чистим демо-профили из старых версий, если они сохранились локально.
      _performers.removeWhere(
          (id, p) => id == 'p1' || id == 'p2' || id == 'p3');

      // Одноразовая очистка памяти: удаляем все старые заявки (закрытые и тестовые).
      await prefs.remove('jobs_v1');
      final jobsRaw = prefs.getString(_jobsKey);
      if (jobsRaw != null) {
        final List decoded = jsonDecode(jobsRaw) as List;
        _jobs = decoded
            .map((e) => Job.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _jobs = _mockJobs();
      }
      final pendingRaw = prefs.getString(_pendingJobsKey);
      if (pendingRaw != null) {
        final List decoded = jsonDecode(pendingRaw) as List;
        for (final entry in decoded) {
          try {
            final job = Job.fromJson(entry as Map<String, dynamic>);
            _pendingJobSync[job.id] = job;
          } catch (_) {}
        }
      }
    } catch (_) {
      if (_performers.isEmpty) _seedPerformers();
      if (_jobs.isEmpty) _jobs = _mockJobs();
    }

    // Не показываем локальный кэш как актуальную ленту. Сначала получаем
    // состояние Supabase, затем открываем главный экран.
    final synced = await _pullRemote();
    if (authenticatedId != null && !synced) {
      _jobs = [];
    }
    // Город из профиля задаёт центр карты и порядок заявок в ленте.
    if (me.city.trim().isNotEmpty) setMyCity(me.city);
    _loaded = true;
    notifyListeners();
    await _save();

    await _subscribeRealtime();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
    // Периодически обновляем ленту, чтобы просроченные заявки
    // исчезали сами, без действий пользователя.
    _expiryTimer ??= Timer.periodic(
        const Duration(minutes: 10), (_) => notifyListeners());
    _closeVisibilityTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final closeTransitionActive = _jobs.any((j) {
        if (!j.isClosed || j.closedAt == null) return false;
        final elapsed = now.difference(j.closedAt!).inSeconds;
        return elapsed >= 0 && elapsed <= 16;
      });
      final fullTransitionActive = _jobs.any((j) {
        if (j.fullAt == null || !j.isFull) return false;
        final elapsed = now.difference(j.fullAt!).inSeconds;
        return elapsed >= 0 && elapsed <= 16;
      });
      if (closeTransitionActive || fullTransitionActive) notifyListeners();
    });
    _messagePollTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!_refreshing) _pullMessages(notify: true);
      },
    );
    _jobPollTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshFromRemote(),
    );
    _jobRetryTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _flushPendingJobs(),
    );
  }

  // ---- Shared backend (Supabase) ----
  final _sb = Supabase.instance.client;
  bool _remoteReady = false;
  bool _firstSyncDone = false;
  int _msgSeq = 0;
  String _newMsgId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${currentUserId}_${_msgSeq++}';

  Future<void> _pullProfilesSafely() async {
    try {
      final rows = await _sb.from('shared_profiles').select();
      for (final row in (rows as List)) {
        try {
          final profile = Performer.fromJson(
            (row['data'] as Map).cast<String, dynamic>(),
          );
          // Свой телефон в общую базу не пишется — берём его из локальной
          // копии, чтобы синхронизация не затёрла собственный номер.
          if (profile.id == currentUserId) {
            final local = _performers[profile.id];
            final localPhone = local?.phone ?? '';
            if (localPhone.isNotEmpty) profile.phone = localPhone;
            // Общий профиль намеренно не содержит личные настройки. Пока
            // отдельная private-строка загружается, не затираем локальную копию.
            profile.blocked = List<String>.from(local?.blocked ?? const []);
            profile.favorites = List<String>.from(local?.favorites ?? const []);
          }
          _performers[profile.id] = profile;
        } catch (_) {
          // Одна старая повреждённая строка не блокирует всю синхронизацию.
        }
      }
      _applyBansToProfiles();
    } catch (_) {}
  }

  List<String> _privateStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(500)
        .toList();
  }

  Future<void> _pullPrivateStateSafely() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null || uid != currentUserId) return;
    try {
      final row = await _sb
          .from('private_user_state')
          .select('blocked, favorites')
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return;
      final profile = me;
      profile.blocked = _privateStringList(row['blocked']);
      profile.favorites = _privateStringList(row['favorites']);
    } catch (error, stackTrace) {
      debugPrint('Private state pull failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _pushPrivateState() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null || uid != currentUserId) return false;
    try {
      await _sb.from('private_user_state').upsert({
        'user_id': uid,
        'blocked': List<String>.from(me.blocked),
        'favorites': List<String>.from(me.favorites),
      }, onConflict: 'user_id').select('user_id').single();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Private state push failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Блокировки живут в отдельной таблице `bans`: читать может любой
  /// вошедший, писать — только модератор. Снять бан с себя невозможно.
  Future<void> _pullBansSafely() async {
    try {
      final rows = await _sb.from('bans').select();
      _bans.clear();
      _banReasons.clear();
      for (final row in (rows as List)) {
        final uid = '${row['user_id'] ?? ''}';
        if (uid.isEmpty) continue;
        final until = DateTime.tryParse('${row['banned_until']}')?.toLocal();
        if (until == null) continue;
        _bans[uid] = until;
        _banReasons[uid] = '${row['reason'] ?? ''}';
      }
      _applyBansToProfiles();
    } catch (_) {}
  }

  /// Переносим серверные блокировки в профили, чтобы лента, админка
  /// и экран блокировки работали без изменений в остальном коде.
  void _applyBansToProfiles() {
    if (_bans.isEmpty && _performers.isEmpty) return;
    for (final p in _performers.values) {
      final until = _bans[p.id];
      p.bannedUntil = until;
      p.banReason = until == null ? '' : (_banReasons[p.id] ?? '');
    }
  }

  /// Спрашиваем сервер, есть ли у нас право модерации.
  Future<void> _refreshModerator() async {
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) {
        _isModerator = false;
        return;
      }
      final row = await _sb
          .from('moderators')
          .select('uid')
          .eq('uid', uid)
          .maybeSingle();
      _isModerator = row != null;
    } catch (_) {
      _isModerator = false;
    }
  }

  Future<List<Job>?> _pullJobsSafely() async {
    // Пакет 12.2: точный адрес/координаты лежат в job_locations (серверная
    // RLS решает, какие строки видны текущему пользователю). Подставляем
    // адрес в заявки, чья локация доступна; остальные помечаем скрытыми.
    Map<String, Map<String, dynamic>> locs = const {};
    try {
      final locRows = await _sb.from('job_locations').select();
      locs = {
        for (final row in (locRows as List))
          row['job_id'].toString(): (row as Map).cast<String, dynamic>(),
      };
    } catch (_) {}
    try {
      final rows = await _sb.from('shared_jobs').select();
      final result = <Job>[];
      for (final row in (rows as List)) {
        try {
          final job = Job.fromJson(
            (row['data'] as Map).cast<String, dynamic>(),
          );
          job.chats.clear();
          final loc = locs[job.id];
          if (loc != null) {
            job.address = (loc['address'] ?? '').toString();
            // Координаты из job_locations защищены от кривых данных: если
            // вместо числа пришла строка, заявка остаётся с координатами
            // 0,0 и не роняет всю ленту.
            final locLat = (loc['lat'] ?? 0) is num
                ? ((loc['lat'] ?? 0) as num).toDouble()
                : 0.0;
            final locLng = (loc['lng'] ?? 0) is num
                ? ((loc['lng'] ?? 0) as num).toDouble()
                : 0.0;
            job.lat = locLat;
            job.lng = locLng;
          } else if (job.address.trim().isEmpty) {
            // Пакет 12.2: если адрес не подгрузился из job_locations и в самой
            // заявке его нет — координат не будет, но флаг «скрыто» не ставим,
            // чтобы адрес (если появится) всегда показывался.
          }
          result.add(job);
        } catch (_) {
          // Пропускаем только повреждённую заявку, остальные продолжают работать.
        }
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _pullRemote() async {
    await _pullProfilesSafely();
    await _pullPrivateStateSafely();
    await _pullBansSafely();
    await _refreshModerator();
    final remoteJobs = await _pullJobsSafely();
    if (remoteJobs == null) return false;

    // Не даём свежему состоянию «откатить» локальное закрытие, пока оно
    // ещё не подтверждено сервером (очередь _pendingJobSync).
    _mergePendingState(remoteJobs);
    final remoteIds = {for (final job in remoteJobs) job.id};
    _jobs = [
      ...remoteJobs,
      ..._pendingJobSync.values.where((job) => !remoteIds.contains(job.id)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _remoteReady = true;
    await _pullMessages(notify: false);
    await _pullReviews();
    _firstSyncDone = true;
    try {
      await _sb.from('shared_profiles').upsert({
        'id': me.id,
        'data': me.toSharedJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
    notifyListeners();
    return true;
  }

  Future<void> _subscribeRealtime() async {
    for (final channel in _realtimeChannels) {
      try {
        await _sb.removeChannel(channel);
      } catch (_) {}
    }
    _realtimeChannels.clear();

    try {
      final jobsChannel = _sb
          .channel('public:shared_jobs:$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_jobs',
            callback: (_) => _refreshFromRemote(),
          );
      final reviewsChannel = _sb
          .channel('public:reviews:$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reviews',
            callback: (_) => _pullReviews(),
          );
      final profilesChannel = _sb
          .channel('public:shared_profiles:$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_profiles',
            callback: (_) => _refreshFromRemote(),
          );
      final messagesChannel = _sb
          .channel('public:messages:$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) =>
                _applyRemoteMessage(payload.newRecord, notify: true),
          );

      _realtimeChannels.addAll([
        jobsChannel,
        reviewsChannel,
        profilesChannel,
        messagesChannel,
      ]);
      for (final channel in _realtimeChannels) {
        channel.subscribe();
      }
    } catch (_) {}
  }

  /// Переносит на свежую серверную версию заявки те локальные изменения,
  /// которые ещё не подтверждены сервером (очередь _pendingJobSync).
  /// Иначе фоновое обновление «откатывало» закрытие, пока запись не дошла,
  /// и закрытая заявка снова появлялась на карте и в ленте.
  void _mergePendingState(List<Job> remoteJobs) {
    for (final rj in remoteJobs) {
      final pend = _pendingJobSync[rj.id];
      if (pend == null || !pend.isClosed) continue;
      rj.isClosed = true;
      rj.closedAt = pend.closedAt;
    }
  }

  Future<void> _refreshFromRemote() async {
    if (_refreshing || _sb.auth.currentUser == null) return;
    _refreshing = true;
    try {
      _refreshTick++;
      // Профили и отзывы меняются редко — тянем их не каждый раз, а раз в
      // несколько циклов, чтобы не гонять всю базу пользователей постоянно.
      final heavy = _refreshTick % 6 == 1;
      if (heavy) {
        await _pullProfilesSafely();
        await _pullPrivateStateSafely();
      }
      final remoteJobs = await _pullJobsSafely();
      if (remoteJobs == null) return;
      if (_firstSyncDone) {
        final oldById = {for (final job in _jobs) job.id: job};
        _notifyJobDiffs(oldById, remoteJobs);
      }
      final remoteIds = {for (final job in remoteJobs) job.id};
      _mergePendingState(remoteJobs);
      // Пока наш собственный отклик (или его отмена) ещё не подтверждён
      // сервером — идёт запись или тормозит сеть — не даём фоновому
      // обновлению «сбрасывать» его: переносим наше участие из локальной
      // pending-версии в свежую версию с сервера.
      for (final rj in remoteJobs) {
        final pend = _pendingJobSync[rj.id];
        if (pend == null) continue;
        if (pend.applicants.contains(currentUserId)) {
          if (!rj.applicants.contains(currentUserId) &&
              !rj.rejectedApplicants.contains(currentUserId)) {
            rj.applicants.add(currentUserId);
          }
        } else {
          // Мы отменили отклик локально — не возвращаем себя обратно.
          rj.applicants.remove(currentUserId);
        }
      }
      _jobs = [
        ...remoteJobs,
        ..._pendingJobSync.values.where((job) => !remoteIds.contains(job.id)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _pullMessages(notify: false);
      if (heavy) await _pullReviews();
      await _save();
      notifyListeners();
      _syncReminders();
    } finally {
      _refreshing = false;
    }
  }

  // Уведомления по изменениям в облаке: новый отклик и принятие/статус.
  void _notifyJobDiffs(Map<String, Job> oldById, List<Job> newJobs) {
    for (final nj in newJobs) {
      final oj = oldById[nj.id];
      if (oj == null) continue;
      if (nj.employerId == currentUserId) {
        for (final a in nj.applicants) {
          if (a != currentUserId &&
              !oj.applicants.contains(a) &&
              !isBlocked(a)) {
            final name = _performers[a]?.name ?? 'Исполнитель';
            showInfoToast(
              title: 'Новый отклик',
              text: '$name откликнулся на «${nj.title}»',
              jobId: nj.id,
              threadId: a,
              peerName: name,
            );
          }
        }
      }
    }
  }

  /// Пишет заявку в облако. true — сервер принял запись.
  Future<bool> _pushJob(Job job) async {
    return await _pushJobResult(job) == null;
  }

  /// Пишет заявку в облако. Возвращает null при успехе или понятный текст
  /// ошибки, если сервер отклонил запись (сеть, RLS, лимит, истёкшая сессия).
  Future<String?> _pushJobResult(Job job) async {
    _pendingJobSync[job.id] = job;
    _save();
    if (!_remoteReady) return 'Нет связи с сервером';
    try {
      final data = job.toRemoteJson();
      if (job.employerId == currentUserId) {
        final payload = {
          'id': job.id,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _sb.from('shared_jobs').upsert(payload).select('id').single();
      } else {
        // Исполнитель не пересоздаёт чужую заявку заново. Берём «защищённые»
        // поля прямо с сервера как есть, чтобы триггер целостности не принял
        // изменение за редактирование чужой заявки (из-за этого на старых
        // заявках отмена отклика откатывалась обратно через пару секунд).
        try {
          final existing = await _sb
              .from('shared_jobs')
              .select('data')
              .eq('id', job.id)
              .maybeSingle();
          final srv = (existing?['data'] as Map?)?.cast<String, dynamic>();
          if (srv != null) {
            for (final k in const [
              'employerId',
              'title',
              'description',
              'address',
              'payPerHour',
              'workersNeeded',
              'date',
            ]) {
              data[k] = srv[k];
            }
            // Пакет 12.2: адрес/координаты живут в job_locations и пишутся
            // только владельцем — из чужого payload ключи убираем совсем.
            data.remove('address');
            data.remove('lat');
            data.remove('lng');
            // Список откликнувшихся берём с сервера и только добавляем/убираем
            // СЕБЯ. Иначе, если локальная версия устарела (кто-то ещё
            // откликнулся), триггер целостности примет это за «удаление чужих
            // откликов» и откатит нашу запись.
            final srvApplicants = <String>[
              ...(((srv['applicants'] ?? const []) as List)
                  .map((e) => e.toString())),
            ];
            final iAmIn = job.applicants.contains(currentUserId);
            if (iAmIn && !srvApplicants.contains(currentUserId)) {
              srvApplicants.add(currentUserId);
            } else if (!iAmIn) {
              srvApplicants.remove(currentUserId);
            }
            data['applicants'] = srvApplicants;
            // Просмотры объединяем с серверными, чтобы не терять чужие.
            final srvViews = <String>{
              ...(((srv['viewedBy'] ?? const []) as List)
                  .map((e) => e.toString())),
              ...job.viewedBy,
            };
            data['viewedBy'] = srvViews.toList();
          }
        } catch (_) {}
        final payload = {
          'id': job.id,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _sb
            .from('shared_jobs')
            .update(payload)
            .eq('id', job.id)
            .select('id')
            .single();
      }
      _pendingJobSync.remove(job.id);
      _save();
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  /// Отклик/отмена через серверный RPC: сервер сам атомарно добавляет
  /// или убирает нас в data->applicants, без перезаписи всей строки
  /// заявки клиентом. Это убирает гонку «двое откликнулись одновременно»
  /// (старый select+update затирал чужие отклики) и не гоняет весь JSON
  /// заявки при каждом действии.
  /// Возвращает null при успехе или понятный текст ошибки.
  Future<String?> _rpcApply(Job job, String userId,
      {required bool cancel}) async {
    _pendingJobSync[job.id] = job;
    _save();
    if (!_remoteReady) return 'Нет связи с сервером';
    try {
      final fn = cancel ? 'cancel_apply' : 'apply_to_job';
      final res = await _sb.rpc(fn, params: {
        'p_job_id': job.id,
        'p_user_id': userId,
      });
      // PostgREST для функции, возвращающей jsonb, отдаёт саму data
      // (иногда — обёрткой { имяФункции: data }). Берём оба варианта.
      Map<String, dynamic> data = const {};
      if (res is Map) {
        final raw = (res[fn] is Map) ? (res[fn] as Map) : res;
        data = raw.cast<String, dynamic>();
      }
      // Подтягиваем свежий список откликнувшихся — в него уже попали
      // чужие одновременные отклики, которых мы могли не знать.
      final srvApplicants = (data['applicants'] as List?)?.cast<String>();
      if (srvApplicants != null) {
        job.applicants
          ..clear()
          ..addAll(srvApplicants);
      }
      _pendingJobSync.remove(job.id);
      _save();
      return null;
    } catch (e) {
      _pendingJobSync.remove(job.id);
      _save();
      return _friendlyError(e);
    }
  }

  /// Превращает ошибку Supabase/сети в понятную пользователю строку.
  String _friendlyError(Object e) {
    final code = e is PostgrestException ? e.code ?? '' : '';
    final serverMsg = e is PostgrestException ? e.message : '';
    final combined = '$code ${e.toString()}'.toLowerCase();

    if (combined.contains('rate_limit')) {
      return 'Сервер временно ограничил это действие. Попробуйте позже.';
    }
    if (code == 'PGRST116' ||
        combined.contains('no rows returned') ||
        combined.contains('json object requested')) {
      return 'Сервер отклонил действие: запись не найдена или недоступна. '
          'Войдите заново и попробуйте ещё раз.';
    }
    if (combined.contains('42501') ||
        combined.contains('row-level security') ||
        combined.contains('permission denied') ||
        combined.contains('insufficient_privilege')) {
      return 'Недостаточно прав на сервере. Войдите заново.';
    }
    if (combined.contains('socket') ||
        combined.contains('connection') ||
        combined.contains('timeout') ||
        combined.contains('failed host lookup') ||
        combined.contains('clientexception')) {
      return 'Нет связи с сервером. Проверьте интернет.';
    }
    if (combined.contains('jwt') ||
        combined.contains('expired') ||
        combined.contains('401') ||
        combined.contains('invalid login')) {
      return 'Сессия истекла. Войдите заново.';
    }
    if (serverMsg.isNotEmpty) return serverMsg;
    return 'Не удалось сохранить на сервере. Попробуйте ещё раз.';
  }

  Future<void> _flushPendingJobs() async {
    if (_pendingJobSync.isEmpty || !_remoteReady) return;
    final pending = List<Job>.from(_pendingJobSync.values);
    for (final job in pending) {
      await _pushJob(job);
    }
  }

  Future<void> _pushProfile(Performer p) async {
    if (!_remoteReady) return;
    try {
      await _sb
          .from('shared_profiles')
          .upsert({
        'id': p.id,
        'data': p.toSharedJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Обновляет агрегаты рейтинга в ЧУЖОМ профиле через RPC — только
  /// rating/ratingCount/employerRating/employerRatingCount/completedJobs,
  /// а не весь профиль. Иначе при оценке можно перезаписать чужое имя,
  /// город или возраст устаревшими данными из своего кэша. Этот же RPC
  /// позволяет включить guard_profiles_write: он разрешает не-владельцу
  /// менять именно эти 5 полей.
  Future<void> _pushRating(Performer target) async {
    if (!_remoteReady) return;
    try {
      await _sb.rpc('update_rating', params: {
        'p_target_id': target.id,
        'p_rating': target.rating,
        'p_rating_count': target.ratingCount,
        'p_employer_rating': target.employerRating,
        'p_employer_rating_count': target.employerRatingCount,
        'p_completed_jobs': target.completedJobs,
      });
    } catch (_) {}
  }

  Future<void> _deleteRemote(String jobId) async {
    try {
      await _sb.from('shared_jobs').delete().eq('id', jobId);
      await _sb.from('messages').delete().eq('job_id', jobId);
    } catch (_) {}
  }

  // ---- Чат: отдельная таблица messages ----
  Future<void> _pullMessages({required bool notify}) async {
    try {
      final rows = await _sb.from('messages').select();
      for (final r in (rows as List)) {
        _applyRemoteMessage((r as Map).cast<String, dynamic>(), notify: notify);
      }
    } catch (_) {}
  }

  Future<void> _pullReviews() async {
    try {
      final rows = await _sb.from('reviews').select();
      _reviews
        ..clear()
        ..addAll((rows as List).map(
          (r) => Review.fromRow((r as Map).cast<String, dynamic>()),
        ));
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> submitReview({
    required String jobId,
    required String targetId,
    required int stars,
    required String text,
  }) async {
    if (stars < 1 || stars > 5 || targetId.isEmpty) return false;
    final job = _jobById(jobId);
    if (job == null) return false;
    final isParticipant = job.employerId == currentUserId ||
        job.applicants.contains(currentUserId);
    if (!isParticipant) return false;
    final review = Review(
      id: '${jobId}_${currentUserId}_$targetId',
      jobId: jobId,
      authorId: currentUserId,
      authorName: me.name.isEmpty ? 'Пользователь' : me.name,
      targetId: targetId,
      stars: stars,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    try {
      await _sb.from('reviews').upsert(review.toRow());
      _reviews.removeWhere((r) => r.id == review.id);
      _reviews.add(review);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Быстрая оценка звёздами без текста. Если текстовый отзыв уже есть —
  /// сохраняем его текст и меняем только количество звёзд.
  Future<bool> rateWithStars({
    required String jobId,
    required String targetId,
    required int stars,
  }) {
    final reviewId = '${jobId}_${currentUserId}_$targetId';
    var existingText = '';
    for (final r in _reviews) {
      if (r.id == reviewId) {
        existingText = r.text;
        break;
      }
    }
    return submitReview(
      jobId: jobId,
      targetId: targetId,
      stars: stars,
      text: existingText,
    );
  }

  /// Отзыв можно изменить только в течение 5 минут после публикации.
  static const int reviewEditWindowSeconds = 300;

  /// Можно ли ещё редактировать этот отзыв (свой и в пределах окна).
  bool canEditReview(Review r) =>
      r.authorId == currentUserId &&
      DateTime.now().difference(r.createdAt).inSeconds <
          reviewEditWindowSeconds;

  /// Сколько секунд осталось на редактирование (0 — окно закрыто).
  int reviewEditSecondsLeft(Review r) {
    final left = reviewEditWindowSeconds -
        DateTime.now().difference(r.createdAt).inSeconds;
    return left < 0 ? 0 : left;
  }

  /// Изменить свой отзыв в пределах 5 минут. Дата создания не сбрасывается,
  /// поэтому окно редактирования не продлевается повторными правками.
  Future<bool> editReview({
    required String reviewId,
    required int stars,
    required String text,
  }) async {
    if (stars < 1 || stars > 5) return false;
    final idx = _reviews.indexWhere((r) => r.id == reviewId);
    if (idx == -1) return false;
    final old = _reviews[idx];
    if (old.authorId != currentUserId) return false;
    if (DateTime.now().difference(old.createdAt).inSeconds >=
        reviewEditWindowSeconds) {
      return false;
    }
    final updated = Review(
      id: old.id,
      jobId: old.jobId,
      authorId: old.authorId,
      authorName: old.authorName,
      targetId: old.targetId,
      stars: stars,
      text: text.trim(),
      createdAt: old.createdAt,
    );
    try {
      await _sb.from('reviews').upsert(updated.toRow());
      _reviews[idx] = updated;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyRemoteMessage(Map<String, dynamic> r, {required bool notify}) {
    final jobId = (r['job_id'] ?? '') as String;
    final threadId = (r['thread_id'] ?? '') as String;
    final id = (r['id'] ?? '') as String;
    final job = _jobById(jobId);
    if (job == null) return;
    final isOwner = job.employerId == currentUserId;
    final isOwnWorkerThread = threadId == currentUserId &&
        (job.applicants.contains(currentUserId) ||
            job.rejectedApplicants.contains(currentUserId));
    final isOwnersWorkerThread = isOwner &&
        (job.applicants.contains(threadId) ||
            job.rejectedApplicants.contains(threadId));
    if (!isOwnWorkerThread && !isOwnersWorkerThread) return;
    final thread = job.chatWith(threadId);
    final msg = ChatMessage(
      id: id,
      senderId: (r['sender_id'] ?? '') as String,
      senderName: (r['sender_name'] ?? '') as String,
      text: (r['text'] ?? '') as String,
      imageUrl: (r['image_url'] ?? '') as String,
      time: DateTime.tryParse('${r["created_at"]}')?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse('${r["read_at"]}')?.toLocal(),
    );
    final existingIndex =
        id.isEmpty ? -1 : thread.indexWhere((m) => m.id == id);
    if (existingIndex >= 0) {
      thread[existingIndex] = msg;
    } else {
      thread.add(msg);
    }
    thread.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    final inActiveChat =
        activeChatJobId == jobId && activeChatThreadId == threadId;
    final incomingFromUser = msg.senderId.isNotEmpty &&
        msg.senderId != currentUserId &&
        !isBlocked(msg.senderId);
    final systemMessageForWorker = msg.senderId.isEmpty &&
        threadId == currentUserId &&
        job.employerId != currentUserId;
    final isNewMessage = existingIndex < 0;
    if (notify &&
        isNewMessage &&
        msg.readAt == null &&
        !inActiveChat &&
        (incomingFromUser || systemMessageForWorker)) {
      showIncomingToast(
        jobId: jobId,
        threadId: threadId,
        senderName: msg.senderName,
        text: msg.text,
      );
    }
    if (inActiveChat && msg.senderId != currentUserId && msg.readAt == null) {
      markThreadRead(jobId, threadId);
    }
    if (notify) notifyListeners();
  }

  Future<void> markThreadRead(String jobId, String threadId) async {
    if (_sb.auth.currentUser == null) return;
    try {
      await _sb
          .from('messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('job_id', jobId)
          .eq('thread_id', threadId)
          .neq('sender_id', currentUserId);
      await _pullMessages(notify: false);
      notifyListeners();
    } catch (_) {}
  }

  static _ImageUploadFormat? _detectImageFormat(Uint8List bytes) {
    if (bytes.lengthInBytes >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return const _ImageUploadFormat('jpg', 'image/jpeg');
    }
    if (bytes.lengthInBytes >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return const _ImageUploadFormat('png', 'image/png');
    }
    if (bytes.lengthInBytes >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return const _ImageUploadFormat('webp', 'image/webp');
    }
    return null;
  }

  static String? photoValidationError(Uint8List bytes) {
    if (bytes.isEmpty) return 'Файл фотографии пуст.';
    if (bytes.lengthInBytes > maxPhotoUploadBytes) {
      return 'Фото больше 8 МБ. Выберите файл меньшего размера.';
    }
    if (_detectImageFormat(bytes) == null) {
      return 'Разрешены только изображения JPG, PNG или WebP.';
    }
    return null;
  }

  /// Загружает проверенное изображение в Supabase Storage и возвращает
  /// либо публичную ссылку, либо понятную причину отказа.
  Future<PhotoUploadResult> uploadPhoto(Uint8List bytes) async {
    if (_sb.auth.currentUser == null) {
      return const PhotoUploadResult.failure(
        'Сессия истекла. Войдите снова и повторите загрузку.',
      );
    }
    final validationError = photoValidationError(bytes);
    if (validationError != null) {
      return PhotoUploadResult.failure(validationError);
    }
    final format = _detectImageFormat(bytes)!;
    final path =
        '$currentUserId/${DateTime.now().microsecondsSinceEpoch}.${format.extension}';
    try {
      await _sb.storage.from('photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: format.contentType,
              upsert: false,
              cacheControl: '3600',
            ),
          );
      return PhotoUploadResult.success(
        _sb.storage.from('photos').getPublicUrl(path),
      );
    } catch (error, stackTrace) {
      debugPrint('Photo upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const PhotoUploadResult.failure(
        'Не удалось загрузить фото. Проверьте интернет и повторите попытку.',
      );
    }
  }

  static bool isChatPhotoPath(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return false;
    }

    final parts = value.split('/');
    return parts.length == 4 && parts.every((part) => part.isNotEmpty);
  }

  /// Загружает вложение чата в private bucket chat_photos.
  /// В messages.image_url сохраняется путь объекта, а не публичная ссылка.
  Future<PhotoUploadResult> uploadChatPhoto(
    Uint8List bytes, {
    required String jobId,
    required String threadId,
  }) async {
    if (_sb.auth.currentUser == null) {
      return const PhotoUploadResult.failure(
        'Сессия истекла. Войдите снова и повторите загрузку.',
      );
    }

    if (jobId.isEmpty ||
        threadId.isEmpty ||
        jobId.contains('/') ||
        threadId.contains('/')) {
      return const PhotoUploadResult.failure(
        'Некорректный идентификатор чата.',
      );
    }

    final validationError = photoValidationError(bytes);
    if (validationError != null) {
      return PhotoUploadResult.failure(validationError);
    }

    final format = _detectImageFormat(bytes)!;
    final path =
        '$currentUserId/$jobId/$threadId/${DateTime.now().microsecondsSinceEpoch}.${format.extension}';

    try {
      await _sb.storage.from('chat_photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: format.contentType,
              upsert: false,
              cacheControl: '3600',
            ),
          );

      return PhotoUploadResult.success(path);
    } catch (error, stackTrace) {
      debugPrint('Chat photo upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      return const PhotoUploadResult.failure(
        'Не удалось загрузить фото. Проверьте интернет и повторите попытку.',
      );
    }
  }

  /// Создаёт короткую signed-ссылку для отображения private-фото чата.
  Future<String?> resolveChatPhotoUrl(String path) async {
    if (!isChatPhotoPath(path)) return null;

    final cached = _chatPhotoUrlCache[path];
    if (cached != null && DateTime.now().isBefore(cached.validUntil)) {
      return cached.url;
    }

    try {
      final url =
          await _sb.storage.from('chat_photos').createSignedUrl(path, 3600);

      _chatPhotoUrlCache[path] = _CachedChatPhotoUrl(
        url,
        DateTime.now().add(const Duration(minutes: 50)),
      );

      return url;
    } catch (error, stackTrace) {
      debugPrint('Chat photo signed URL failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Удаляет уже загруженные private-фото, если отправка сообщения не удалась.
  Future<void> deleteUploadedChatPhotos(Iterable<String> paths) async {
    await _deleteChatPhotos(paths.toList());
  }

  /// Удаляет private-вложения чата по сохранённым путям объектов.
  Future<void> _deleteChatPhotos(List<String> paths) async {
    if (paths.isEmpty || _sb.auth.currentUser == null) return;

    final validPaths = paths.where(isChatPhotoPath).toSet().toList();
    if (validPaths.isEmpty) return;

    try {
      await _sb.storage.from('chat_photos').remove(validPaths);

      for (final path in validPaths) {
        _chatPhotoUrlCache.remove(path);
      }
    } catch (error, stackTrace) {
      debugPrint('Chat photo cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
  /// Публичный rollback для файлов, загруженных до неудачного сохранения
  /// заявки или сообщения.
  Future<void> deleteUploadedPhotos(Iterable<String> urls) async {
    await _deletePhotos(urls.toList());
  }

  /// Удаляет файлы фото из Supabase Storage (bucket "photos") по их публичным
  /// ссылкам. Профильные аватарки сюда НЕ передаются — удаляются только фото
  /// заявок и вложения из их чатов.
  Future<void> _deletePhotos(List<String> urls) async {
    if (urls.isEmpty || _sb.auth.currentUser == null) return;
    const marker = '/photos/';
    final paths = <String>[];
    for (final url in urls) {
      final i = url.indexOf(marker);
      if (i < 0) continue;
      final path = url.substring(i + marker.length);
      if (path.isNotEmpty) paths.add(path);
    }
    if (paths.isEmpty) return;
    try {
      await _sb.storage.from('photos').remove(paths);
    } catch (error, stackTrace) {
      debugPrint('Photo cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<DateTime?> _pushMessage(
      String jobId, String threadId, ChatMessage m) async {
    if (!_remoteReady) return null;
    try {
      final row = await _sb.from('messages').insert({
        'id': m.id,
        'job_id': jobId,
        'thread_id': threadId,
        'sender_id': m.senderId,
        'sender_name': m.senderName,
        'text': m.text,
        if (m.imageUrl.isNotEmpty) 'image_url': m.imageUrl,
      }).select('created_at').single();
      return DateTime.tryParse('${row['created_at']}')?.toLocal() ??
          DateTime.now();
    } catch (_) {
      return null;
    }
  }

  // ---- Геолокация ----
  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      setGpsPosition(pos.latitude, pos.longitude);
      notifyListeners();
    } catch (_) {}
  }

  /// Запрашивает геопозицию для сортировки «Ближе». Возвращает true, если
  /// местоположение определено (иначе сортировку по расстоянию не включаем).
  Future<bool> ensureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return false;
      }
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      setGpsPosition(pos.latitude, pos.longitude);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _seedPerformers() {
    // Демо-профили (Иван Петров и др.) убраны: они попадали в статистику
    // панели разработчика и искажали счётчики. Оставляем только заглушку
    // текущего пользователя; реальные профили приходят из облака.
    _performers.putIfAbsent(
      currentUserId,
      () => Performer(id: currentUserId, name: 'Вы', city: 'Уфа'),
    );
  }

  // Тестовые заявки убраны.
  List<Job> _mockJobs() => [];

  Future<void> resetToMock() async {
    _jobs = _mockJobs();
    _performers.clear();
    _seedPerformers();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _jobsKey, jsonEncode(_jobs.map((j) => j.toJson()).toList()));
      await prefs.setString(
          _pendingJobsKey,
          jsonEncode(
              _pendingJobSync.values.map((j) => j.toJson()).toList()));
      await prefs.setString(
          _perfKey,
          jsonEncode(_performers.values.map((profile) {
            final data = profile.toJson();
            // Не оставляем настройки других аккаунтов в общем кэше устройства.
            if (profile.id != currentUserId) {
              data.remove('blocked');
              data.remove('favorites');
            }
            return data;
          }).toList()));
      await prefs.setBool(_regKey, _registered);
      await prefs.setString(
          _limitsKey,
          jsonEncode({
            'date': _limitDate,
            'jobs': _jobsToday,
            'applies': _appliesToday,
          }));
    } catch (_) {}
  }

  // ——— Регистрация / профиль ———

  /// Первичная регистрация: телефон привязывается к профилю навсегда.
  void registerUser({
    required String phone,
    required String name,
    required int age,
    required String city,
  }) {
    final p = me;
    p.phone = phone;
    p.name = name;
    p.age = age;
    p.city = city;
    p.loggedOutAt = null;
    // Явный флаг анкеты: он, в отличие от phone, попадает в общую базу,
    // поэтому после переустановки и на другом устройстве анкета больше не спрашивается.
    p.registered = true;
    p.createdAt ??= DateTime.now();
    setMyCity(city);
    _registered = true;
    notifyListeners();
    _save();
    _pushProfile(me);
  }

  /// Редактирование профиля (телефон менять нельзя).
  void updateProfile({String? name, int? age, String? city}) {
    final p = me;
    if (name != null) p.name = name;
    if (age != null) p.age = age;
    if (city != null && city.trim().isNotEmpty) {
      p.city = city.trim();
      // Смена города сразу перестраивает ленту и центр карты.
      setMyCity(p.city);
    }
    p.registered = true;
    notifyListeners();
    _save();
    _pushProfile(p);
  }


  /// Пересобрать личность после входа по номеру: берём id из сессии,
  /// подтягиваем облако и определяем, зарегистрирован ли уже профиль.
  Future<void> onLoggedIn() async {
    final nextUserId =
        Supabase.instance.client.auth.currentUser?.id ?? currentUserId;
    if (nextUserId != currentUserId) {
      currentUserId = nextUserId;
    }
    await _loadCountersForCurrentUser();
    PushService.instance.register();
    _loaded = false;
    notifyListeners();
    final synced = await _pullRemote();
    if (!synced) _jobs = [];
    await _subscribeRealtime();
    final p = _performers[currentUserId];
    // Раньше смотрели на phone, но его вырезает toSharedJson — из облака он
    // всегда приходил пустым, и пользователя каждый раз вело заполнять анкету заново.
    // ВАЖНО: getter me создаёт черновой профиль с именем 'Вы'. Его нельзя
    // считать заполненной анкетой, иначе новый пользователь проскакивает
    // экран регистрации. Поэтому имя 'Вы' в проверке не считается настоящим.
    final hasRealName =
        p != null && p.name.trim().isNotEmpty && p.name.trim() != 'Вы';
    _registered = p != null && (p.registered || hasRealName);
    if (p != null) {
      if (p.city.trim().isNotEmpty) setMyCity(p.city);
      if (_registered && !p.registered) {
        // Добиваем флаг старым профилям, чтобы больше не угадывать по имени.
        p.registered = true;
        _pushProfile(p);
      }
    }
    if (p != null && p.loggedOutAt != null) {
      p.loggedOutAt = null;
      _pushProfile(p);
    }
    _loaded = true;
    await _save();
    notifyListeners();
  }

  /// Выход из аккаунта. Следующий вход — заново по номеру телефона и коду.
  Future<void> logout() async {
    final previousUserId = currentUserId;
    // Отмечаем момент выхода: заявки живут ещё 3 часа, чтобы можно было
    // вернуться. Если не вернуться — их скроет лента и уберёт серверная чистка.
    try {
      final meProfile = _performers[currentUserId];
      if (meProfile != null) {
        meProfile.loggedOutAt = DateTime.now();
        await _pushProfile(meProfile);
      }
    } catch (_) {}
    await _pushPrivateState();
    await PushService.instance.unregister();
    await ReminderService.instance.clearAll();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      var guestId = prefs.getString(_guestIdKey);
      if (guestId == null || guestId.isEmpty || guestId == 'currentUser') {
        guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
        await prefs.setString(_guestIdKey, guestId);
      }
      currentUserId = guestId;
    } catch (_) {
      currentUserId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
    }
    final previousProfile = _performers[previousUserId];
    previousProfile?.blocked.clear();
    previousProfile?.favorites.clear();
    await _loadCountersForCurrentUser();
    _registered = false;
    _isModerator = false;
    await _save();
    notifyListeners();
  }

  /// Сбросить суточные счётчики (созданные заявки и отклики за сегодня).
  void resetCounters() {
    _limitDate = _todayKey();
    _jobsToday = 0;
    _appliesToday = 0;
    notifyListeners();
    _save();
  }

  // ——— Заявки ———

  /// Создать заявку. Возвращает false, если исчерпан суточный лимit (2/день).
  bool addJob(Job job) {
    _rollDay();
    final ban = banMessage;
    if (ban != null) {
      _snack(ban);
      return false;
    }
    if (_jobsToday >= maxJobsPerDay) return false;
    _jobs.insert(0, job);
    _jobsToday++;
    notifyListeners();
    _save();
    _pushJob(job).then((synced) {
      if (!synced) {
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Нет связи с сервером. Заявка будет отправлена автоматически.',
            ),
          ),
        );
      }
    });
    return true;
  }

  /// Закрыть свою заявку.
  void closeJob(String jobId) {
    final job = _jobById(jobId);
    if (job == null) return;
    if (job.employerId != currentUserId || job.isClosed) return;
    job.isClosed = true;
    job.closedAt = DateTime.now();
    // Засчитываем «Выполнено» при закрытии: тем, кого работодатель уже оценил
    // или подтвердил выполнение работы.
    final creditIds = <String>{...job.ratings.keys, ...job.employerDone};
    for (final performerId in creditIds) {
      _creditCompletedWork(job, performerId);
    }
    for (final entry in job.chats.entries) {
      final sys = ChatMessage(
        id: _newMsgId(),
        senderId: currentUserId,
        senderName: 'Система',
        text: 'Заявка закрыта заказчиком',
        time: DateTime.now(),
      );
      entry.value.add(sys);
      _pushMessage(jobId, entry.key, sys);
    }
    messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
            'Заявка закрыта и сохранена в профиле → «Мои заявки»'),
        duration: Duration(seconds: 4),
      ),
    );
    notifyListeners();
    _save();
    // Через 15 секунд карточка исчезнет из ленты и карты. Саму запись и чат
    // сохраняем в истории участников.
    _pushJob(job);
    _syncReminders();
    Timer(const Duration(seconds: 15), () {
      notifyListeners();
      _save();
    });
  }

  /// Редактировать свою заявку можно только до первого активного отклика.
  /// Если все отклики отменены или отклонены, редактирование снова доступно.
  bool updateJob(Job updated) {
    final index = _jobs.indexWhere((j) => j.id == updated.id);
    if (index < 0) return false;
    final old = _jobs[index];
    if (old.employerId != currentUserId) return false;
    if (old.isClosed) return false;
    if (old.applicants.isNotEmpty) return false;

    // Фото, убранные из заявки, удаляем и из хранилища.
    final removedPhotos =
        old.photos.where((u) => !updated.photos.contains(u)).toList();

    _jobs[index] = updated;
    notifyListeners();
    _save();
    _syncReminders();
    _pushJob(updated).then((synced) {
      if (!synced) {
        _snack('Нет связи с сервером. Изменения отправятся автоматически.');
      }
    });
    if (removedPhotos.isNotEmpty) _deletePhotos(removedPhotos);

    // Участникам чатов сообщаем, что условия изменились.
    for (final entry in updated.chats.entries) {
      final sys = ChatMessage(
        id: _newMsgId(),
        senderId: currentUserId,
        senderName: 'Система',
        text: 'Заказчик изменил условия заявки',
        time: DateTime.now(),
      );
      entry.value.add(sys);
      _pushMessage(updated.id, entry.key, sys);
    }
    return true;
  }

  /// Удалить можно только свою заявку.
  /// Запись удаляется из облака, поэтому исчезает и у других пользователей.
  void deleteJob(String jobId) {
    final job = _jobById(jobId);
    if (job == null) return;
    if (job.employerId != currentUserId) return;
    // Собираем ссылки на фото самой заявки и вложения из её чатов, чтобы
    // удалить их из хранилища (аватарки профилей это не затрагивает).
    final photoUrls = <String>[
      ...job.photos,
      for (final thread in job.chats.values)
        for (final m in thread)
          if (m.imageUrl.isNotEmpty) m.imageUrl,
    ];
    _jobs.removeWhere((j) => j.id == jobId);
    notifyListeners();
    _save();
    _syncReminders();
    _deleteRemote(jobId);
    _deletePhotos(
      photoUrls.where((url) => !isChatPhotoPath(url)).toList(),
    );
    _deleteChatPhotos(
      photoUrls.where(isChatPhotoPath).toList(),
    );
  }

  /// Откликнуться на заявку. Возвращает текст ошибки или null при успехе.
  /// Дожидается ответа сервера: если запись отклонена, локальные изменения
  /// откатываются, чтобы на экране не оставался «призрачный» отклик, которого
  /// на сервере нет.
  Future<String?> applyToJob(String jobId, String userId) async {
    _rollDay();
    final job = _jobById(jobId);
    if (job == null) return 'Заявка недоступна';
    if (userId != currentUserId) return 'Не удалось определить пользователя';
    if (job.employerId == currentUserId) return 'Нельзя откликнуться на свою заявку';
    if (job.isClosed) return 'Заявка закрыта';
    if (job.rejectedApplicants.contains(userId)) {
      return 'Работодатель отклонил вашу заявку';
    }
    if (job.applicants.contains(userId)) return null; // уже откликнулись
    if (job.isFull) return 'Мест больше нет';
    if (_appliesToday >= maxAppliesPerDay) {
      return 'Лимит $maxAppliesPerDay откликов в день исчерпан';
    }
    job.applicants.add(userId);
    _appliesToday++;
    // Как только мест не осталось — запоминаем момент заполнения.
    if (job.isFull && job.fullAt == null) job.fullAt = DateTime.now();
    final sys = ChatMessage(
      id: _newMsgId(),
      senderId: currentUserId,
      senderName: 'Система',
      text: 'Исполнитель откликнулся на заявку',
      time: DateTime.now(),
    );
    job.chatWith(userId).add(sys);
    notifyListeners();
    _save();
    final err = await _rpcApply(job, userId, cancel: false);
    if (err != null) {
      // Сервер не принял отклик (сеть, RLS, лимит) — откатываем локально,
      // чтобы не показывать отклик, которого нет в облаке.
      job.applicants.remove(userId);
      if (_appliesToday > 0) _appliesToday--;
      if (!job.isFull) job.fullAt = null;
      job.chatWith(userId).remove(sys);
      _pendingJobSync.remove(job.id);
      _save();
      notifyListeners();
      return err;
    }
    _pushMessage(jobId, userId, sys);
    _syncReminders();
    return null;
  }

  Future<void> cancelApplication(String jobId, String userId) async {
    final job = _jobById(jobId);
    if (job == null) return;
    if (job.applicants.remove(userId)) {
      _rollDay();
      // Освободилось место — заявка снова видна всем, сбрасываем таймер.
      if (!job.isFull) job.fullAt = null;
      if (_appliesToday > 0) _appliesToday--; // отклик возвращается в лимит
      final sys = ChatMessage(
        id: _newMsgId(),
        senderId: currentUserId,
        senderName: 'Система',
        text: 'Исполнитель отменил отклик',
        time: DateTime.now(),
      );
      job.chatWith(userId).add(sys);
      notifyListeners();
      _save();
      final err = await _rpcApply(job, userId, cancel: true);
      if (err != null) {
        // Сервер не принял отмену (сеть, RLS) — возвращаем отклик на место,
        // иначе на экране будет «отменено», а на сервере отклик останется.
        if (!job.applicants.contains(userId)) job.applicants.add(userId);
        if (_appliesToday >= 0) _appliesToday++; // возврат лимита был ошибочным
        if (job.isFull && job.fullAt == null) job.fullAt = DateTime.now();
        job.chatWith(userId).remove(sys);
        _pendingJobSync.remove(job.id);
        _save();
        notifyListeners();
        messengerKey.currentState?.showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      _pushMessage(jobId, userId, sys);
      _syncReminders();
    }
  }

  /// Работодатель отклоняет исполнителя от своей заявки: место
  /// освобождается, повторно откликнуться нельзя, в чат уходит уведомление.
  void rejectApplicant(String jobId, String userId) {
    final job = _jobById(jobId);
    if (job == null || job.employerId != currentUserId) return;
    job.applicants.remove(userId);
    if (!job.rejectedApplicants.contains(userId)) {
      job.rejectedApplicants.add(userId);
    }
    job.stages.remove(userId);
    job.employerDone.remove(userId);
    job.workerDone.remove(userId);
    if (!job.isFull) job.fullAt = null;
    final sys = ChatMessage(
      id: _newMsgId(),
      senderId: currentUserId,
      senderName: 'Система',
      text: 'Работодатель отклонил вас',
      time: DateTime.now(),
    );
    job.chatWith(userId).add(sys);
    notifyListeners();
    _save();
    _pushJob(job);
    _pushMessage(jobId, userId, sys);
    _syncReminders();
  }

  /// Засчитать просмотр заявки (уникально по пользователю). Автора заявки
  /// не считаем. В облако пишем только при первом просмотре пользователем.
  void registerView(String jobId, String userId) {
    if (userId.isEmpty) return;
    final job = _jobById(jobId);
    if (job == null) return;
    if (job.employerId == userId) return;
    if (job.viewedBy.contains(userId)) return;
    job.viewedBy.add(userId);
    notifyListeners();
    _save();
    _pushJob(job);
  }

  /// Безвозвратное удаление выполняет серверная Edge Function. Локальное
  /// состояние очищаем только после явного подтверждения сервера.
  Future<void> deleteAccount() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const AccountDeletionException(
        'Сессия истекла. Войдите снова и повторите удаление аккаунта.',
      );
    }

    try {
      final response = await _sb.functions.invoke(
        'delete-account',
        body: const {'confirm': 'DELETE'},
      );
      final data = response.data;
      final success = data is Map && data['success'] == true;
      if (response.status < 200 || response.status >= 300 || !success) {
        throw StateError('delete-account returned no success confirmation');
      }
    } catch (error, stackTrace) {
      debugPrint('delete-account failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final details = error.toString();
      if (details.contains('moderator_account_protected')) {
        throw const AccountDeletionException(
          'Аккаунт модератора защищён от удаления.',
        );
      }
      throw const AccountDeletionException(
        'Не удалось удалить аккаунт. Данные не считаются удалёнными. '
        'Проверьте интернет и повторите попытку.',
      );
    }

    await ReminderService.instance.clearAll();
    try {
      await _sb.auth.signOut();
    } catch (error) {
      // Auth user уже удалён сервером. Ошибка выхода не отменяет успешное
      // удаление, а локальную модель всё равно очищаем ниже.
      debugPrint('Local signOut after account deletion failed: $error');
    }

    _jobs.clear();
    _pendingJobSync.clear();
    _performers.clear();
    _reviews.clear();
    _remoteReady = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString(_guestIdKey, guestId);
      currentUserId = guestId;
    } catch (_) {
      currentUserId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
    }
    await _loadCountersForCurrentUser();
    _registered = false;
    _isModerator = false;
    await _save();
    notifyListeners();
  }

  Future<bool> sendMessage(String jobId, String userId, String text,
      {String imageUrl = ''}) async {
    final job = _jobById(jobId);
    if (job == null || (text.trim().isEmpty && imageUrl.isEmpty)) return false;
    final isOwner = job.employerId == currentUserId;
    final allowed = isOwner
        ? job.applicants.contains(userId)
        : userId == currentUserId && job.applicants.contains(currentUserId);
    if (!allowed) return false;
    final peerId = isOwner ? userId : job.employerId;
    if (isBlocked(peerId)) return false;
    final msg = ChatMessage(
      id: _newMsgId(),
      senderId: currentUserId,
      senderName: me.name.isEmpty ? 'Пользователь' : me.name,
      text: text.trim(),
      imageUrl: imageUrl,
      time: DateTime.now(),
    );
    final serverTime = await _pushMessage(jobId, userId, msg);
    if (serverTime == null) return false;
    final confirmedMessage = ChatMessage(
      id: msg.id,
      senderId: msg.senderId,
      senderName: msg.senderName,
      text: msg.text,
      imageUrl: msg.imageUrl,
      time: serverTime,
      readAt: null,
    );
    final thread = job.chatWith(userId);
    final existingIndex = thread.indexWhere((m) => m.id == msg.id);
    if (existingIndex >= 0) {
      thread[existingIndex] = confirmedMessage;
    } else {
      thread.add(confirmedMessage);
    }
    thread.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    notifyListeners();
    _save();
    return true;
  }

  List<ChatMessage> messagesFor(String jobId, String userId) {
    final job = _jobById(jobId);
    if (job == null) return [];
    return job.chatWith(userId);
  }

  /// Подтянуть свежие сообщения из облака (на случай пропущенного realtime-события).
  Future<void> refreshMessages() async {
    await _pullMessages(notify: true);
  }

  void rateJob(String jobId, double rating) {
    final job = _jobById(jobId);
    if (job == null) return;
    final total = job.rating * job.ratingCount + rating;
    job.ratingCount++;
    job.rating = total / job.ratingCount;
    notifyListeners();
    _save();
    _pushJob(job);
  }

  /// Оценка исполнителя работодателем — только один раз за заявку.
  /// Возвращает false, если этот исполнитель уже был оценён.
  bool rateApplicant(String jobId, String performerId, double rating) {
    final p = _performers[performerId];
    if (p == null) return false;
    Job? job;
    for (final j in _jobs) {
      if (j.id == jobId) {
        job = j;
        break;
      }
    }
    final prev = job?.ratings[performerId];
    if (prev != null) {
      // Меняем прошлую оценку — количество оценок не растёт.
      if (p.ratingCount > 0) {
        p.rating = (p.rating * p.ratingCount - prev + rating) / p.ratingCount;
      } else {
        p.rating = rating;
      }
    } else {
      final total = p.rating * p.ratingCount + rating;
      p.ratingCount++;
      p.rating = total / p.ratingCount;
    }
    if (job != null) {
      job.ratings[performerId] = rating;
      if (!job.ratedApplicants.contains(performerId)) {
        job.ratedApplicants.add(performerId);
      }
      _creditCompletedWork(job, performerId);
      _pushJob(job);
    }
    notifyListeners();
    _save();
    _pushRating(p); // только агрегаты, а не весь чужой профиль
    return true;
  }

  /// Рабочий оценивает работодателя (репутация заказчика). Можно менять оценку.
  bool rateEmployer(String jobId, double rating) {
    final job = _jobById(jobId);
    if (job == null) return false;
    final emp = _performers[job.employerId];
    if (emp == null) return false;
    final prev = job.employerRatings[currentUserId];
    if (prev != null) {
      if (emp.employerRatingCount > 0) {
        emp.employerRating =
            (emp.employerRating * emp.employerRatingCount - prev + rating) /
                emp.employerRatingCount;
      } else {
        emp.employerRating = rating;
      }
    } else {
      final total = emp.employerRating * emp.employerRatingCount + rating;
      emp.employerRatingCount++;
      emp.employerRating = total / emp.employerRatingCount;
    }
    job.employerRatings[currentUserId] = rating;
    notifyListeners();
    _save();
    _pushJob(job);
    _pushRating(emp); // только агрегаты, а не весь чужой профиль
    return true;
  }

  // ——— Статусы работы по шагам ———

  void _stageSystemMessage(Job job, String workerId, String text) {
    final sys = ChatMessage(
      id: _newMsgId(),
      senderId: currentUserId,
      senderName: 'Система',
      text: text,
      time: DateTime.now(),
    );
    job.chatWith(workerId).add(sys);
    _pushMessage(job.id, workerId, sys);
  }

  void acceptApplicant(String jobId, String workerId) {
    final job = _jobById(jobId);
    if (job == null) return;
    job.stages[workerId] = JobStage.accepted;
    _stageSystemMessage(job, workerId, 'Работодатель принял ваш отклик');
    notifyListeners();
    _save();
    _pushJob(job);
  }

  void startWork(String jobId, String workerId) {
    final job = _jobById(jobId);
    if (job == null) return;
    job.stages[workerId] = JobStage.inProgress;
    _stageSystemMessage(job, workerId, 'Работа начата');
    notifyListeners();
    _save();
    _pushJob(job);
  }

  /// Подтвердить завершение. byEmployer=true — подтверждает работодатель.
  void confirmDone(String jobId, String workerId, {required bool byEmployer}) {
    final job = _jobById(jobId);
    if (job == null) return;
    final wasCompleted = job.employerDone.contains(workerId) &&
        job.workerDone.contains(workerId);
    if (byEmployer) {
      if (!job.employerDone.contains(workerId)) {
        job.employerDone.add(workerId);
      }
    } else {
      if (!job.workerDone.contains(workerId)) {
        job.workerDone.add(workerId);
      }
    }
    _stageSystemMessage(
        job,
        workerId,
        byEmployer
            ? 'Работодатель подтвердил завершение'
            : 'Исполнитель подтвердил завершение');
    final nowCompleted = job.employerDone.contains(workerId) &&
        job.workerDone.contains(workerId);
    if (!wasCompleted && nowCompleted) {
      job.stages[workerId] = JobStage.completed;
      _stageSystemMessage(job, workerId, 'Работа завершена ✅');
    }
    notifyListeners();
    _save();
    _pushJob(job);
  }

  // ——— Жалобы и блокировка ———

  // ——— Панель разработчика ———

  /// Демо-профили из старых версий (их нельзя учитывать в статистике).
  static const Set<String> _fakeSeedIds = {'p1', 'p2', 'p3'};

  /// «Настоящий» профиль: не гость, не черновик «Вы» и не старая заглушка.
  bool _isRealProfile(Performer p) {
    if (p.id.startsWith('guest_')) return false;
    if (_fakeSeedIds.contains(p.id)) return false;
    final name = p.name.trim();
    if (name.isEmpty || name == 'Вы') return false;
    return true;
  }

  /// Только реальные пользователи (без гостей, черновиков и демо-профилей).
  Iterable<Performer> get _realProfiles =>
      _performers.values.where(_isRealProfile);

  /// Сводная статистика для экрана разработчика.
  Map<String, int> get adminStats {
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    // Города считаем только по активным заявкам, иначе «городов 1, активных 0».
    final cities = <String>{};
    for (final j in _jobs) {
      if (j.isClosed || j.isExpired) continue;
      final c = cityOfJob(j);
      if (c.isNotEmpty) cities.add(normalizeCity(c));
    }
    final real = _realProfiles.toList();
    return {
      'users': real.where((p) => p.registered).length,
      'usersTotal': real.length,
      'banned': real.where((p) => p.isBanned).length,
      'jobs': _jobs.length,
      'jobsActive':
          _jobs.where((j) => !j.isClosed && !j.isExpired).length,
      'jobsClosed': _jobs.where((j) => j.isClosed).length,
      'jobsToday': _jobs.where((j) => j.createdAt.isAfter(dayAgo)).length,
      'jobsWeek': _jobs.where((j) => j.createdAt.isAfter(weekAgo)).length,
      'applications':
          _jobs.fold<int>(0, (sum, j) => sum + j.applicants.length),
      'reviews': _reviews.length,
      'cities': cities.length,
    };
  }

  /// Все реальные профили: сначала заблокированные, потом по имени.
  List<Performer> get allUsers {
    final list = _realProfiles.toList();
    list.sort((a, b) {
      if (a.isBanned != b.isBanned) return a.isBanned ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Сколько заявок создал пользователь (для карточки в админке).
  int jobsCountOf(String userId) =>
      _jobs.where((j) => j.employerId == userId).length;

  /// Заблокировать аккаунт. duration == null — навсегда.
  ///
  /// Блокировка пишется в таблицу `bans` на сервере. База пропустит
  /// запись только если наш идентификатор внесён в `moderators`, поэтому
  /// локальные флаги не дают прав модерации.
  Future<bool> banUser(String userId,
      {Duration? duration, String reason = ''}) async {
    if (!_isModerator) return false;
    if (userId == currentUserId) return false;
    final p = _performers[userId];
    if (p == null) return false;
    final until = duration == null
        ? DateTime.utc(9999, 1, 1)
        : DateTime.now().add(duration);
    try {
      await _sb.from('bans').upsert({
        'user_id': userId,
        'banned_until': until.toUtc().toIso8601String(),
        'reason': reason.trim(),
      });
    } catch (_) {
      return false;
    }
    _bans[userId] = until;
    _banReasons[userId] = reason.trim();
    p.bannedUntil = until;
    p.banReason = reason.trim();
    notifyListeners();
    await _save();
    return true;
  }

  /// Снять блокировку.
  Future<bool> unbanUser(String userId) async {
    if (!_isModerator) return false;
    final p = _performers[userId];
    if (p == null) return false;
    try {
      final res =
          await _sb.from('bans').delete().eq('user_id', userId).select();
      if ((res as List).isEmpty) return false;
    } catch (_) {
      return false;
    }
    _bans.remove(userId);
    _banReasons.remove(userId);
    p.bannedUntil = null;
    p.banReason = '';
    notifyListeners();
    await _save();
    return true;
  }

  bool isBlocked(String userId) => me.blocked.contains(userId);

  void blockUser(String userId) {
    if (userId.isEmpty || userId == currentUserId) return;
    if (!me.blocked.contains(userId)) {
      me.blocked.add(userId);
      notifyListeners();
      _save();
      _pushPrivateState();
    }
  }

  void unblockUser(String userId) {
    if (me.blocked.remove(userId)) {
      notifyListeners();
      _save();
      _pushPrivateState();
    }
  }

  /// Пожаловаться на пользователя. Жалоба уходит в таблицу reports (если создана).
  Future<void> reportUser(String targetId, String reason) async {
    await reportContent(targetId: targetId, reason: reason);
  }

  Future<bool> reportContent({
    required String targetId,
    required String reason,
    String? jobId,
    String details = '',
  }) async {
    try {
      await _sb.from('reports').insert({
        'id': _newMsgId(),
        'reporter_id': currentUserId,
        'target_id': targetId,
        'job_id': jobId,
        'reason': reason,
        'details': details.trim(),
        'status': 'new',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  void _creditCompletedWork(Job job, String performerId) {
    // Засчитываем только подтверждённых исполнителей: оценённых или
    // отмеченных работодателем как выполнивших работу.
    final confirmed = job.ratings.containsKey(performerId) ||
        job.employerDone.contains(performerId);
    if (!job.isClosed ||
        !confirmed ||
        job.completedCreditedApplicants.contains(performerId)) {
      return;
    }
    final performer = _performers[performerId];
    if (performer == null) return;
    job.completedCreditedApplicants.add(performerId);
    performer.completedJobs++;
    _pushRating(performer); // только completedJobs, а не весь чужой профиль
  }

  // ——— Избранное / история / мои заявки ———

  bool isFavorite(String jobId) => me.favorites.contains(jobId);

  void toggleFavorite(String jobId) {
    if (me.favorites.contains(jobId)) {
      me.favorites.remove(jobId);
    } else {
      me.favorites.add(jobId);
    }
    notifyListeners();
    _save();
    _pushPrivateState();
  }

  // Избранное показывает ВСЕ сохранённые заявки, включая закрытые и
  // просроченные — иначе сохранённая закрытая заявка исчезала из избранного.
  List<Job> get favoriteJobs =>
      _jobs.where((j) => me.favorites.contains(j.id)).toList();

  List<Job> get myJobs =>
      _jobs.where((j) => j.employerId == currentUserId).toList();

  List<Job> get myApplications =>
      _jobs.where((j) => j.applicants.contains(currentUserId)).toList();

  /// Активные (не закрытые и не просроченные) заявки, которые я создал.
  List<Job> get myActiveJobs => _jobs
      .where((j) =>
          j.employerId == currentUserId && !j.isClosed && !j.isExpired)
      .toList();

  /// Активные отклики — заявки, на которые я откликнулся и которые ещё в силе.
  List<Job> get myActiveApplications => _jobs
      .where((j) =>
          j.applicants.contains(currentUserId) &&
          !j.isClosed &&
          !j.isExpired)
      .toList();

  /// История — завершённые/закрытые/просроченные заявки, где я участвовал
  /// (как заказчик или как откликнувшийся). Свежие сверху.
  List<Job> get historyJobs {
    final me = currentUserId;
    final list = _jobs
        .where((j) =>
            (j.employerId == me || j.applicants.contains(me)) &&
            (j.isClosed || j.isExpired))
        .toList()
      ..sort((a, b) =>
          (b.closedAt ?? b.date).compareTo(a.closedAt ?? a.date));
    return list;
  }

  /// Сумма непрочитанных сообщений во всех чатах пользователя — для бейджа.
  int get totalUnread {
    final me = currentUserId;
    var count = 0;
    for (final job in _jobs) {
      if (isBlocked(job.employerId)) continue;
      if (job.employerId == me) {
        for (final applicantId in job.applicants) {
          if (isBlocked(applicantId)) continue;
          final msgs = job.chats[applicantId];
          if (msgs == null) continue;
          count += msgs
              .where((m) => m.senderId != me && m.readAt == null)
              .length;
        }
      } else if (job.applicants.contains(me)) {
        final msgs = job.chats[me];
        if (msgs == null) continue;
        count += msgs
            .where((m) => m.senderId != me && m.readAt == null)
            .length;
      }
    }
    return count;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _closeVisibilityTimer?.cancel();
    _messagePollTimer?.cancel();
    _jobPollTimer?.cancel();
    _jobRetryTimer?.cancel();
    for (final channel in _realtimeChannels) {
      _sb.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _sb.auth.currentUser != null) {
      _refreshFromRemote();
      _pullMessages(notify: true);
    }
  }
}
