import 'dart:convert';

import 'package:flutter/foundation.dart';
// Веб-сборка: flutter_local_notifications не поддерживает web, и его
// импорт ломает `flutter build web`. На web подставляется no-op шим
// (соседний файл). На Android/iOS — настоящий пакет, как и было.
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.js_interop) 'fln_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/job.dart';

/// Локальные напоминания «за 3 часа до начала работы».
///
/// Планируются прямо на устройстве, работают офлайн и НЕ требуют сервера,
/// Firebase или RuStore. Это единственный тип уведомлений, который зависит
/// только от даты, уже известной приложению (время начала работы в заявке).
///
/// Работает на Android и iOS. На web/desktop тихо отключается.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// За сколько до начала работы напоминать.
  static const Duration _lead = Duration(hours: 3);

  /// jobId -> notificationId already scheduled on this device.
  final Map<String, int> _scheduled = {};
  static const String _scheduledKey = 'job_reminders_v2';
  static const String _migrationKey = 'job_reminders_v2_migrated';

  /// Инициализация плагина и базы часовых поясов. Вызывается один раз в main().
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      _setLocalTimezoneFromDeviceOffset();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(android: android, iOS: ios);
      await _plugin.initialize(settings);
      await _restoreScheduled();
      _ready = true;
    } catch (e) {
      debugPrint('ReminderService init failed: $e');
    }
  }

  /// Запрос разрешения на уведомления (Android 13+ / iOS). Безопасно вызывать
  /// несколько раз — система покажет диалог только при необходимости.
  Future<void> requestPermission() async {
    if (!_ready || kIsWeb) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('ReminderService permission failed: $e');
    }
  }

  void _setLocalTimezoneFromDeviceOffset() {
    // Russia no longer uses DST. Map the device UTC offset to a canonical
    // Russian timezone so scheduled local wall-clock times stay correct.
    const locations = <int, String>{
      120: 'Europe/Kaliningrad',
      180: 'Europe/Moscow',
      240: 'Europe/Samara',
      300: 'Asia/Yekaterinburg',
      360: 'Asia/Omsk',
      420: 'Asia/Krasnoyarsk',
      480: 'Asia/Irkutsk',
      540: 'Asia/Yakutsk',
      600: 'Asia/Vladivostok',
      660: 'Asia/Magadan',
      720: 'Asia/Kamchatka',
    };
    final minutes = DateTime.now().timeZoneOffset.inMinutes;
    final name = locations[minutes];
    if (name == null) return;
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('ReminderService timezone failed: $e');
    }
  }

  Future<void> _restoreScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migrationKey) ?? false;
    if (!migrated) {
      // Old versions used unstable String.hashCode IDs. Remove those once;
      // current jobs will be scheduled again by the next sync.
      await _plugin.cancelAll();
      await prefs.setBool(_migrationKey, true);
      await prefs.remove(_scheduledKey);
      _scheduled.clear();
      return;
    }
    final raw = prefs.getString(_scheduledKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is num) _scheduled['${entry.key}'] = value.toInt();
        }
      }
    } catch (_) {
      _scheduled.clear();
      await prefs.remove(_scheduledKey);
    }
  }

  Future<void> _persistScheduled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scheduledKey, jsonEncode(_scheduled));
    } catch (e) {
      debugPrint('ReminderService persistence failed: $e');
    }
  }

  int _idFor(String jobId) {
    // Deterministic 31-bit FNV-1a; unlike String.hashCode this is stable
    // between application launches.
    var hash = 0x811c9dc5;
    for (final unit in jobId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Приводит запланированные напоминания в соответствие с текущим состоянием.
  ///
  /// Напоминание остаётся только если пользователь всё ещё активно откликнут
  /// на заявку (не отменил, не отклонён), заявка не закрыта, а до начала
  /// работы ещё больше 3 часов. Всё остальное отменяется. За счёт этого
  /// отмена отклика, отклонение заказчиком, закрытие или удаление заявки
  /// автоматически убирают напоминание.
  Future<void> sync(List<Job> jobs, String userId) async {
    if (!_ready || kIsWeb || userId.isEmpty) return;
    final now = DateTime.now();

    final desired = <String, Job>{};
    for (final job in jobs) {
      final active = job.applicants.contains(userId) &&
          !job.isClosed &&
          !job.rejectedApplicants.contains(userId);
      if (!active) continue;
      final fireAt = job.date.subtract(_lead);
      if (fireAt.isAfter(now)) desired[job.id] = job;
    }

    // Отменяем то, что больше не нужно.
    final toCancel =
        _scheduled.keys.where((id) => !desired.containsKey(id)).toList();
    for (final jobId in toCancel) {
      await _cancel(jobId);
    }

    // Планируем/обновляем нужные (повторный zonedSchedule с тем же id
    // просто перезаписывает предыдущее напоминание).
    for (final job in desired.values) {
      await _schedule(job);
    }
  }

  Future<void> _schedule(Job job) async {
    final id = _idFor(job.id);
    final fireAt = job.date.subtract(_lead);
    try {
      await _plugin.zonedSchedule(
        id,
        'Скоро работа',
        '«${job.title}» начнётся через 3 часа. Не опаздывай!',
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'job_reminders',
            'Напоминания о работе',
            channelDescription:
                'Напоминание за 3 часа до начала работы по заявке',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'job:${job.id}',
      );
      _scheduled[job.id] = id;
      await _persistScheduled();
    } catch (e) {
      debugPrint('ReminderService schedule failed: $e');
    }
  }

  Future<void> _cancel(String jobId) async {
    try {
      await _plugin.cancel(_idFor(jobId));
    } catch (_) {}
    _scheduled.remove(jobId);
    await _persistScheduled();
  }

  /// Cancel every reminder when the active account changes or is deleted.
  Future<void> clearAll() async {
    if (!_ready || kIsWeb) {
      _scheduled.clear();
      return;
    }
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('ReminderService cancelAll failed: $e');
    }
    _scheduled.clear();
    await _persistScheduled();
  }

  /// Явная отмена напоминания по одной заявке.
  Future<void> cancelForJob(String jobId) => _cancel(jobId);
}
