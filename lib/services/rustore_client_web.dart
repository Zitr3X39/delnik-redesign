/// Веб-шим для flutter_rustore_push (пакет Android-only).
///
/// Повторяет ровно те члены API пакета, которые использует
/// PushService. На web всё no-op: пуш-уведомлений там нет.
/// Подключается условным импортом в push_service.dart.
library;

class RustorePushClient {
  RustorePushClient._();

  static void attachCallbacks({
    void Function(String token)? onNewToken,
    void Function(Object? message)? onMessageReceived,
    void Function()? onDeletedMessages,
    void Function(Object? error)? onError,
    void Function(Object? message)? onMessageOpenedApp,
  }) {}

  static Future<bool?> available() async => false;

  static Future<String> getToken() async => '';
}
