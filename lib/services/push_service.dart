import 'package:flutter/foundation.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Удалённые push-уведомления через RuStore.
/// Работают только на Android и только если у пользователя установлен RuStore.
/// На вебе и iOS всё тихо пропускается. Ошибки гасятся try/catch, чтобы
/// пуши никогда не могли уронить приложение.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;
  String? _lastToken;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Вызвать один раз при старте приложения (после Supabase.initialize).
  Future<void> init() async {
    if (!_supported || _started) return;
    _started = true;
    try {
      RustorePushClient.attachCallbacks(
        onNewToken: (token) {
          _lastToken = token;
          _saveToken(token);
        },
        onMessageReceived: (message) {},
        onDeletedMessages: () {},
        onError: (error) {
          debugPrint('RuStore push error: $error');
        },
        onMessageOpenedApp: (message) {},
      );
    } catch (e) {
      debugPrint('RuStore attachCallbacks failed: $e');
    }
  }

  /// Вызвать после входа пользователя: получить push-токен и сохранить его
  /// в таблицу push_tokens (привязка токен -> пользователь).
  Future<void> register() async {
    if (!_supported) return;
    try {
      final available = await RustorePushClient.available();
      if (available != true) return;
    } catch (e) {
      debugPrint('RuStore available failed: $e');
      return;
    }
    try {
      final token = await RustorePushClient.getToken();
      if (token.isNotEmpty) {
        _lastToken = token;
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('RuStore getToken failed: $e');
    }
  }

  /// Отвязать токен этого устройства до выхода из текущего аккаунта.
  Future<void> unregister() async {
    if (!_supported) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      var token = _lastToken ?? '';
      if (token.isEmpty) {
        final available = await RustorePushClient.available();
        if (available == true) token = await RustorePushClient.getToken();
      }
      if (token.isEmpty) return;
      await Supabase.instance.client.rpc(
        'unregister_push_token',
        params: {'p_token': token},
      );
      _lastToken = null;
    } catch (e) {
      debugPrint('push_tokens unregister failed: $e');
    }
  }

  /// Сохранить/обновить токен текущего пользователя в базе.
  Future<void> _saveToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || token.isEmpty) return;
      _lastToken = token;
      await Supabase.instance.client.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_platform': 'android',
        },
      );
    } catch (e) {
      debugPrint('push_tokens upsert failed: $e');
    }
  }
}