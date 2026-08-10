$ErrorActionPreference = "Stop"
$root = "C:\shabashka_app"
$lib = "$root\lib"

$svc = @'
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

  /// Сохранить/обновить токен текущего пользователя в базе.
  Future<void> _saveToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || token.isEmpty) return;
      await Supabase.instance.client.from('push_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('push_tokens upsert failed: $e');
    }
  }
}
'@
$svcDir = "$lib\services"
if (!(Test-Path $svcDir)) { New-Item -ItemType Directory -Path $svcDir | Out-Null }
[System.IO.File]::WriteAllText("$svcDir\push_service.dart", $svc)
Write-Host "sozdan: lib\services\push_service.dart"
Write-Host ""

function DoEdit($path, $old, $new) {
    if (!(Test-Path $path)) { Write-Host ("  NET FAJLA: " + $path); return }
    if (!(Test-Path "$path.bak")) { Copy-Item $path "$path.bak" -Force }
    $c = [System.IO.File]::ReadAllText($path)
    $cnt = ([regex]::Matches($c, [regex]::Escape($old))).Count
    if ($cnt -eq 1) { $c = $c.Replace($old, $new); [System.IO.File]::WriteAllText($path, $c) }
    $tag = "OK"
    if ($cnt -eq 0) { $tag = "PROPUSK (ne najdeno)" }
    if ($cnt -gt 1) { $tag = "VNIMANIE: najdeno $cnt" }
    Write-Host ("  zamen=" + $cnt + "  " + $tag + "  <- " + $path)
}

$o = @'
  timezone: ^0.9.4
'@
$n = @'
  timezone: ^0.9.4
  flutter_rustore_push: ^7.2.0
'@
DoEdit "$root\pubspec.yaml" $o $n

$o = @'
            android:value="2" />
'@
$n = @'
            android:value="2" />
        <!-- RuStore Push: ID proekta iz RuStore Console (vstavit pered relizom) -->
        <meta-data
            android:name="ru.rustore.sdk.pushclient.project_id"
            android:value="PASTE_RUSTORE_PROJECT_ID" />
'@
DoEdit "$root\android\app\src\main\AndroidManifest.xml" $o $n

$o = @'
import 'app_state.dart';
'@
$n = @'
import 'app_state.dart';
import 'services/push_service.dart';
'@
DoEdit "$lib\main.dart" $o $n

$o = @'
  await ReminderService.instance.init();
'@
$n = @'
  await PushService.instance.init();
  if (Supabase.instance.client.auth.currentSession != null) {
    PushService.instance.register();
  }
  await ReminderService.instance.init();
'@
DoEdit "$lib\main.dart" $o $n

$o = @'
import '../services/reminder_service.dart';
'@
$n = @'
import '../services/reminder_service.dart';
import '../services/push_service.dart';
'@
DoEdit "$lib\providers\job_provider.dart" $o $n

$o = @'
  Future<void> onLoggedIn() async {
'@
$n = @'
  Future<void> onLoggedIn() async {
    PushService.instance.register();
'@
DoEdit "$lib\providers\job_provider.dart" $o $n

Write-Host ""
Write-Host "Gotovo. Vse 6 strok dolzhny byt zamen=1. Prishlite vyvod mne."
