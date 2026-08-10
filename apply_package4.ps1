$ErrorActionPreference = 'Stop'

$root = 'C:\shabashka_app'
$target = Join-Path $root 'lib\providers\job_provider.dart'
$expectedBefore = 'a07135541d571636be14b58e4ba8a225248021990db683f2c0fb3671c6072d8a'
$expectedAfter = '56a57fef719526edee04e25262553c913538086081cd1515365b648abe94807b'

if (-not (Test-Path $target)) { throw "File not found: $target" }
$actualBefore = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
if ($actualBefore -ne $expectedBefore) {
    throw "Source SHA256 mismatch. Expected $expectedBefore, found $actualBefore. Nothing changed."
}

$backupDir = 'C:\shabashka_backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $backupDir "job_provider_before_package4_$stamp.dart"
Copy-Item $target $backup -Force
Write-Host "Backup: $backup"

$content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$content = $content.Replace("`r`n", "`n")

function Replace-Exact([string]$old, [string]$new, [int]$expected) {
    $old = $old.Replace("`r`n", "`n")
    $new = $new.Replace("`r`n", "`n")
    $count = ([regex]::Matches($script:content, [regex]::Escape($old))).Count
    if ($count -ne $expected) {
        throw "Exact replacement count mismatch. Expected $expected, found $count. Restore from $backup if needed."
    }
    $script:content = $script:content.Replace($old, $new)
}

$old1 = @'
  static const String _limitsKey = 'limits_v1';
'@
$new1 = @'
  static const String _legacyLimitsKey = 'limits_v1';
  static const String _limitsKeyPrefix = 'limits_v2_';
  String get _limitsKey => '$_limitsKeyPrefix$currentUserId';
'@
Replace-Exact $old1 $new1 1

$old2 = @'
  void _rollDay() {
    final t = _todayKey();
    if (_limitDate != t) {
      _limitDate = t;
      _jobsToday = 0;
      _appliesToday = 0;
    }
  }

'@
$new2 = @'
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

'@
Replace-Exact $old2 $new2 1

$old3 = @'
      final limRaw = prefs.getString(_limitsKey);
      if (limRaw != null) {
        final m = jsonDecode(limRaw) as Map<String, dynamic>;
        _limitDate = (m['date'] ?? '') as String;
        _jobsToday = (m['jobs'] ?? 0) as int;
        _appliesToday = (m['applies'] ?? 0) as int;
      }
      _rollDay();
'@
$new3 = @'
      await _loadCountersForCurrentUser(prefs);
'@
Replace-Exact $old3 $new3 1

$old4 = @'
  Future<void> onLoggedIn() async {
    PushService.instance.register();
    currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? currentUserId;
    _loaded = false;
'@
$new4 = @'
  Future<void> onLoggedIn() async {
    final nextUserId =
        Supabase.instance.client.auth.currentUser?.id ?? currentUserId;
    if (nextUserId != currentUserId) {
      currentUserId = nextUserId;
    }
    await _loadCountersForCurrentUser();
    PushService.instance.register();
    _loaded = false;
'@
Replace-Exact $old4 $new4 1

$old5 = @'
    _registered = false;
    _isModerator = false;
    await _save();
'@
$new5 = @'
    await _loadCountersForCurrentUser();
    _registered = false;
    _isModerator = false;
    await _save();
'@
Replace-Exact $old5 $new5 2

$doubleReplacement = ([string][char]0xFFFD) + ([string][char]0xFFFD)
$content = $content.Replace($doubleReplacement, [string][char]0x043D)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($target, $content, $utf8NoBom)

$actualAfter = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
if ($actualAfter -ne $expectedAfter) {
    Copy-Item $backup $target -Force
    throw "Final SHA256 mismatch. Original file restored. Found $actualAfter"
}

if ($content.Contains([char]0xFFFD)) {
    Copy-Item $backup $target -Force
    throw 'Damaged Unicode character detected. Original file restored.'
}

if (-not $content.Contains('String get _limitsKey => ''$_limitsKeyPrefix$currentUserId'';')) {
    Copy-Item $backup $target -Force
    throw 'Per-user limit key check failed. Original file restored.'
}

if (-not $content.Contains('if (old.applicants.isNotEmpty) return false;')) {
    Copy-Item $backup $target -Force
    throw 'Package 2 edit lock check failed. Original file restored.'
}

Write-Host 'PACKAGE4_LIMITS_APPLIED_OK'
Write-Host 'Next: flutter analyze'
