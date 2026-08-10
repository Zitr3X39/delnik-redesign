/// Веб-шим для flutter_local_notifications (пакет не поддерживает web).
///
/// Повторяет только те члены API, что использует ReminderService.
/// На web всё no-op: локальных уведомлений там нет. Подключается
/// условным импортом в reminder_service.dart.
library;

import 'package:timezone/timezone.dart' as tz;

class FlutterLocalNotificationsPlugin {
  Future<void> initialize(InitializationSettings settings) async {}

  T? resolvePlatformSpecificImplementation<T>() => null;

  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails? details, {
    AndroidScheduleMode? androidScheduleMode,
    UILocalNotificationDateInterpretation?
        uiLocalNotificationDateInterpretation,
    String? payload,
  }) async {}

  Future<void> cancel(int id) async {}

  Future<void> cancelAll() async {}
}

class AndroidInitializationSettings {
  const AndroidInitializationSettings(this.defaultIcon);
  final String defaultIcon;
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    this.requestAlertPermission,
    this.requestBadgePermission,
    this.requestSoundPermission,
  });
  final bool? requestAlertPermission;
  final bool? requestBadgePermission;
  final bool? requestSoundPermission;
}

class InitializationSettings {
  const InitializationSettings({this.android, this.iOS});
  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<bool?> requestNotificationsPermission() async => null;
}

class IOSFlutterLocalNotificationsPlugin {
  Future<bool?> requestPermissions({
    bool? alert,
    bool? badge,
    bool? sound,
  }) async =>
      null;
}

class NotificationDetails {
  const NotificationDetails({this.android, this.iOS});
  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;
}

class AndroidNotificationDetails {
  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.importance,
    this.priority,
  });
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final Importance? importance;
  final Priority? priority;
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails();
}

enum Importance { high }

enum Priority { high }

enum AndroidScheduleMode { inexactAllowWhileIdle }

enum UILocalNotificationDateInterpretation { absoluteTime }
