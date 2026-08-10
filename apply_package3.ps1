$ErrorActionPreference = 'Stop'
$root = 'C:\shabashka_app'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root "backup_before_package3_$stamp"

function Get-Text([string]$path) {
  return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
}

function Set-Text([string]$path, [string]$text) {
  [IO.File]::WriteAllText($path, $text, $utf8)
}

function Replace-Exact(
  [string]$relative,
  [string]$old,
  [string]$new,
  [int]$expected = 1
) {
  $path = Join-Path $root $relative
  $text = (Get-Text $path).Replace("`r`n", "`n")
  $old = $old.Replace("`r`n", "`n")
  $new = $new.Replace("`r`n", "`n")
  $count = ([regex]::Matches($text, [regex]::Escape($old))).Count
  if ($count -ne $expected) {
    throw "$relative`: ожидалось совпадений $expected, найдено $count"
  }
  Set-Text $path ($text.Replace($old, $new))
}

$files = @(
  'lib\providers\job_provider.dart',
  'lib\screens\admin_screen.dart',
  'lib\screens\auth_screen.dart',
  'lib\screens\dev_login_screen.dart',
  'lib\screens\profile_screen.dart'
)

New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach ($relative in $files) {
  $source = Join-Path $root $relative
  if (-not (Test-Path $source)) { throw "Не найден файл: $source" }
  $destination = Join-Path $backup $relative
  New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
  Copy-Item $source $destination
}
Write-Host "Резервная копия: $backup" -ForegroundColor Cyan

# Новый экран ввода кода RuStore. Правильность проверяет только сервер.
$devLogin = @'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/glass.dart';

/// Ввод кода, переданного проверяющему RuStore.
/// Секрет не хранится в APK — правильность проверяет сервер.
class DevLoginScreen extends StatefulWidget {
  const DevLoginScreen({super.key});

  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Введите код проверяющего');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Проверка RuStore',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: Color(0xFF0284C7)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Демо-вход для проверяющего',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Введите код из кабинета RuStore. Демо-аккаунт работает с '
                  'обычными лимитами и не получает прав модератора.',
                  style: TextStyle(color: Colors.black54, height: 1.45),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(64)],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Код проверяющего',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('ВОЙТИ ДЛЯ ПРОВЕРКИ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'@
Set-Text (Join-Path $root 'lib\screens\dev_login_screen.dart') ($devLogin.Replace("`r`n", "`n"))

$oldAuth = @'
  /// Вход для разработчика и проверяющих из RuStore: сначала пароль,
  /// потом анонимная сессия Supabase и режим разработчика с панелью статистики.
  Future<void> _devLogin() async {
    if (!_consent) {
      _snack('Подтвердите согласие с условиями (галочка ниже)');
      return;
    }
    final unlocked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DevLoginScreen()),
    );
    if (unlocked != true || !mounted) return;
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e) {
      _snack('Не удалось войти как разработчик: $e');
      return;
    }
    if (!mounted) return;
    final provider = context.read<JobProvider>();
    await _recordConsent();
    await provider.onLoggedIn();
    provider.setDevMode(true);
    if (!mounted) return;
    // Если анкета уже заполнена — сразу в ленту, иначе просим заполнить.
    if (provider.isRegistered) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileSetupScreen(phone: ''),
        ),
      );
    }
  }
'@
$newAuth = @'
  /// Демо-вход RuStore: анонимная сессия получает доступ только после
  /// серверной проверки кода и никогда не получает прав модератора.
  Future<void> _devLogin() async {
    if (!_consent) {
      _snack('Подтвердите согласие с условиями (галочка ниже)');
      return;
    }
    final reviewerCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DevLoginScreen()),
    );
    if (reviewerCode == null || !mounted) return;

    final auth = Supabase.instance.client.auth;
    try {
      await auth.signInAnonymously();
      final approved = await Supabase.instance.client.rpc(
        'activate_reviewer_session',
        params: {'p_code': reviewerCode},
      );
      if (approved != true) {
        throw const AuthException('Неверный код проверяющего');
      }
    } catch (_) {
      try {
        await auth.signOut();
      } catch (_) {}
      if (mounted) {
        _snack('Код проверяющего неверный или временно заблокирован');
      }
      return;
    }

    if (!mounted) return;
    final provider = context.read<JobProvider>();
    await _recordConsent();
    await provider.onLoggedIn();
    if (!mounted) return;
    if (provider.isRegistered) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileSetupScreen(phone: ''),
        ),
      );
    }
  }
'@
Replace-Exact 'lib\screens\auth_screen.dart' $oldAuth $newAuth
Replace-Exact 'lib\screens\auth_screen.dart' "label: const Text('Вход для разработчика')," "label: const Text('Демо-вход для проверки RuStore'),"

Replace-Exact 'lib\providers\job_provider.dart' "  static const String _devKey = 'devmode_v1';`n" ''
$oldDevFields = @'
  // Режим разработчика: безлимит.
  bool _devMode = false;
  bool get devMode => _devMode;

'@
Replace-Exact 'lib\providers\job_provider.dart' $oldDevFields ''
Replace-Exact 'lib\providers\job_provider.dart' "    if (_devMode) return 9999;`n" '' 2
$oldDevRestore = @'
      // Восстанавливаем режим разработчика из сохранённого значения, чтобы
      // панель разработчика не слетала при каждом перезапуске приложения.
      _devMode = prefs.getBool(_devKey) ?? false;

'@
$newDevRestore = @'
      // Удаляем старый локальный флаг сверхправ.
      await prefs.remove('devmode_v1');

'@
Replace-Exact 'lib\providers\job_provider.dart' $oldDevRestore $newDevRestore
Replace-Exact 'lib\providers\job_provider.dart' "      await prefs.setBool(_devKey, _devMode);`n" ''
$oldSetDev = @'
  /// Режим разработчика: снимает суточные лимиты.
  void setDevMode(bool value) {
    _devMode = value;
    notifyListeners();
    _save();
  }

'@
Replace-Exact 'lib\providers\job_provider.dart' $oldSetDev ''
Replace-Exact 'lib\providers\job_provider.dart' "    _registered = false;`n" "    _registered = false;`n    _isModerator = false;`n" 2
Replace-Exact 'lib\providers\job_provider.dart' "    if (!_devMode && _jobsToday >= maxJobsPerDay) return false;" "    if (_jobsToday >= maxJobsPerDay) return false;"
Replace-Exact 'lib\providers\job_provider.dart' '  /// Удалить свою заявку (или любую — в режиме разработчика).' '  /// Удалить можно только свою заявку.'
Replace-Exact 'lib\providers\job_provider.dart' "    if (job.employerId != currentUserId && !_devMode) return;" '    if (job.employerId != currentUserId) return;'
Replace-Exact 'lib\providers\job_provider.dart' "    if (!_devMode && _appliesToday >= maxAppliesPerDay) {" "    if (_appliesToday >= maxAppliesPerDay) {"
Replace-Exact 'lib\providers\job_provider.dart' '  /// включённый на устройстве devMode сам по себе банить не позволяет.' '  /// локальные флаги не дают прав модерации.'
Replace-Exact 'lib\providers\job_provider.dart' "    if (!_devMode) return false;" "    if (!_isModerator) return false;" 2
Replace-Exact 'lib\providers\job_provider.dart' '  /// Локальный devMode такого права не даёт: база примет блокировку только' '  /// Только серверная таблица moderators даёт право блокировки;'

$oldProfileGate = @'
            // Служебный раздел: виден только после входа по паролю разработчика.
            if (context.watch<JobProvider>().devMode) ...[
'@
$newProfileGate = @'
            // Панель видна только модератору, подтверждённому сервером.
            if (context.watch<JobProvider>().isModerator) ...[
'@
Replace-Exact 'lib\screens\profile_screen.dart' $oldProfileGate $newProfileGate
Replace-Exact 'lib\screens\profile_screen.dart' "label: 'ПАНЕЛЬ РАЗРАБОТЧИКА'," "label: 'ПАНЕЛЬ МОДЕРАТОРА',"

Replace-Exact 'lib\screens\admin_screen.dart' 'if (!provider.devMode) {' 'if (!provider.isModerator) {'
Replace-Exact 'lib\screens\admin_screen.dart' "title: 'Панель разработчика'," "title: 'Панель модератора'," 2
Replace-Exact 'lib\screens\admin_screen.dart' "'Раздел доступен только при входе для разработчика.'," "'Раздел доступен только подтверждённому модератору.',"

foreach ($relative in $files) {
  $path = Join-Path $root $relative
  $text = Get-Text $path
  if ($text.Contains([char]0xFFFD)) {
    throw "Повреждённый символ найден: $relative"
  }
}
$providerText = Get-Text (Join-Path $root 'lib\providers\job_provider.dart')
if ($providerText.Contains('_devMode') -or $providerText.Contains('setDevMode')) {
  throw 'Локальный devMode удалён не полностью'
}
$authText = Get-Text (Join-Path $root 'lib\screens\auth_screen.dart')
if (-not $authText.Contains("'activate_reviewer_session'")) {
  throw 'Серверная проверка RuStore не добавлена'
}
if (-not $providerText.Contains('if (old.applicants.isNotEmpty) return false;')) {
  throw 'Не найдена блокировка редактирования заявки при откликах'
}

Write-Host 'PACKAGE3_APPLIED_OK' -ForegroundColor Green
Write-Host 'Теперь выполните: flutter analyze' -ForegroundColor Green
