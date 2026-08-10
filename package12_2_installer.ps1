# Пакет 12.2 — клиент: чтение адресов из job_locations (приватность адреса)
# Протокол: preflight SHA -> backup -> dry-run якорей -> запись -> post SHA -> flutter analyze -> авто-rollback.
# Без exit: при сбое — return ДО записи либо откат из backup.
$ErrorActionPreference = 'Stop'
$root = 'C:\shabashka_app'
$files = @(
  'lib\models\job.dart',
  'lib\providers\job_provider.dart',
  'lib\screens\job_detail_screen.dart',
  'lib\widgets\job_card.dart',
  'lib\screens\map_screen.dart',
  'lib\screens\edit_job_screen.dart'
)
$expectedBefore = @{
  'lib\models\job.dart' = '08c0bfdd775df5c7aeee909b59f2c5d849d2e97311afa5e5c2d9c13ac0b414fb'
  'lib\providers\job_provider.dart' = '4726d7e52d75905e279dd952fd9e2ef3b7411fa8ff4c95067a500def4fb1e327'
  'lib\screens\job_detail_screen.dart' = 'd3a367217c65e63ee6f7cf071f496a9bd0345c58d8e68e938daadcc721d12029'
  'lib\widgets\job_card.dart' = '76888ed40b32f71004502af96884865d23adc15de930a45f9fa836d3af019f28'
  'lib\screens\map_screen.dart' = 'fbaa6366a6b2df72336aa77751881d7e0082b017969b463cb726da9baa86ad0e'
  'lib\screens\edit_job_screen.dart' = '28e6c5d606eb04bbc0f950161c2d61020fb25420ac659f8fcc3d79b2453da211'
}
$expectedAfter = @{
  'lib\models\job.dart' = '32da9db9b6d57830eb1fa225e8d9bdf74b93caa922e57719d033c6e96d8151ae'
  'lib\providers\job_provider.dart' = 'ff24e876069cd1f368f4a06390d5f67c5e3a2097a39ec016c63a9e5df8631602'
  'lib\screens\job_detail_screen.dart' = 'c399f9903e7b7bafc1bfc29b4bf764b8e186a73f4d04e3a8e3ccad875c9212d7'
  'lib\widgets\job_card.dart' = 'abef8e28aa0f7571f924a7fd421ad84abbb48c28218099724b022a028ffabc2e'
  'lib\screens\map_screen.dart' = '93cc4d525a0973c8988acef1c296bf1ebf931d98373840153b144da7a41b0e48'
  'lib\screens\edit_job_screen.dart' = '5c9b0cd3429a73bf70010826a5633f4dd5d114b0c04e63c2a83af536c7246e31'
}

function Lf([string]$s) { return ($s -replace "`r`n", "`n") }
$script:edits = @()
function Add-Edit([string]$f, [string]$o, [string]$n) {
  $script:edits += @{ File = $f; Old = (Lf $o); New = (Lf $n) }
}

# ===== 13 якорных замен (песочница: ALL_12_2_ANCHORS_OK) =====
$editOld = @'
  final String address;
'@
$editNew = @'
  String address;

  /// true — сервер скрыл точный адрес (заявка укомплектована чужими
  /// откликами). Показываем город/«адрес после отклика», не метку на карте.
  /// Не сериализуется: при каждой синхронизации выставляется заново.
  bool locationHidden;
'@
Add-Edit 'lib\models\job.dart' $editOld $editNew

$editOld = @'
  final double lat;
  final double lng;
'@
$editNew = @'
  double lat;
  double lng;
'@
Add-Edit 'lib\models\job.dart' $editOld $editNew

$editOld = @'
    required this.address,
'@
$editNew = @'
    required this.address,
    this.locationHidden = false,
'@
Add-Edit 'lib\models\job.dart' $editOld $editNew

$editOld = @'
      address: json['address'] as String,
'@
$editNew = @'
      address: (json['address'] ?? '') as String,
'@
Add-Edit 'lib\models\job.dart' $editOld $editNew

$editOld = @'
  Future<List<Job>?> _pullJobsSafely() async {
    try {
      final rows = await _sb.from('shared_jobs').select();
      final result = <Job>[];
      for (final row in (rows as List)) {
        try {
          final job = Job.fromJson(
            (row['data'] as Map).cast<String, dynamic>(),
          );
          job.chats.clear();
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
'@
$editNew = @'
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
            job.lat = ((loc['lat'] ?? 0) as num).toDouble();
            job.lng = ((loc['lng'] ?? 0) as num).toDouble();
          } else if (job.address.trim().isEmpty) {
            job.locationHidden = true;
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
'@
Add-Edit 'lib\providers\job_provider.dart' $editOld $editNew

$editOld = @'
            ]) {
              data[k] = srv[k];
            }
'@
$editNew = @'
            ]) {
              data[k] = srv[k];
            }
            // Пакет 12.2: адрес/координаты живут в job_locations и пишутся
            // только владельцем — из чужого payload ключи убираем совсем.
            data.remove('address');
            data.remove('lat');
            data.remove('lng');
'@
Add-Edit 'lib\providers\job_provider.dart' $editOld $editNew

$editOld = @'
        final dist = formatDistance(distanceFromMe(j.lat, j.lng));
'@
$editNew = @'
        final dist = j.locationHidden
            ? ''
            : formatDistance(distanceFromMe(j.lat, j.lng));
'@
Add-Edit 'lib\screens\job_detail_screen.dart' $editOld $editNew

$editOld = @'
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: '${j.address}  •  $dist',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                JobMapScreen(job: j, jobs: provider.jobs),
                          ),
                        ),
                      ),
'@
$editNew = @'
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: j.locationHidden
                            ? 'Адрес станет доступен после отклика'
                            : '${j.address}  •  $dist',
                        onTap: j.locationHidden
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobMapScreen(
                                        job: j, jobs: provider.jobs),
                                  ),
                                ),
                      ),
'@
Add-Edit 'lib\screens\job_detail_screen.dart' $editOld $editNew

$editOld = @'
    final dist = formatDistance(distanceFromMe(job.lat, job.lng));
'@
$editNew = @'
    final dist = job.locationHidden
        ? 'после отклика'
        : formatDistance(distanceFromMe(job.lat, job.lng));
'@
Add-Edit 'lib\widgets\job_card.dart' $editOld $editNew

$editOld = @'
                    child: Text(job.address,
'@
$editNew = @'
                    child: Text(job.locationHidden ? 'Адрес после отклика' : job.address,
'@
Add-Edit 'lib\widgets\job_card.dart' $editOld $editNew

$editOld = @'
    final active = widget.jobs;
'@
$editNew = @'
    final active = widget.jobs;
    // Пакет 12.2: заявки со скрытым сервером адресом на карту не ставим —
    // у постороннего их координат нет (RLS job_locations).
    final mappable = active.where((job) => !job.locationHidden).toList();
'@
Add-Edit 'lib\screens\map_screen.dart' $editOld $editNew

$editOld = @'
              markers: active.map((job) {
'@
$editNew = @'
              markers: mappable.map((job) {
'@
Add-Edit 'lib\screens\map_screen.dart' $editOld $editNew

$editOld = @'
    var street = j.address;
    var house = '';
    final marker = j.address.indexOf(', д. ');
'@
$editNew = @'
    // Пакет 12.2: сервер скрыл адрес (заявка укомплектована чужими
    // откликами) — форму открываем с пустым адресом, а не с мусором.
    var street = j.locationHidden ? '' : j.address;
    var house = '';
    final marker = j.locationHidden ? -1 : j.address.indexOf(', д. ');
'@
Add-Edit 'lib\screens\edit_job_screen.dart' $editOld $editNew

# ===== 1. Preflight SHA исходников =====
foreach ($f in $files) {
  $p = Join-Path $root $f
  if (!(Test-Path $p)) { Write-Host "PREFLIGHT_FAIL: нет файла $f"; return }
  $sha = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
  Write-Host "before $f $sha"
  if ($sha -ne $expectedBefore[$f]) {
    Write-Host "PREFLIGHT_FAIL: $f — исходник отличается от эталона, стоп. Ничего не менял."
    return
  }
}
Write-Host 'PREFLIGHT_SHA_OK'

# ===== 2. Backup =====
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$bk = "C:\shabashka_backups\package12_2_$ts"
New-Item -ItemType Directory -Force -Path $bk | Out-Null
foreach ($f in $files) { Copy-Item (Join-Path $root $f) (Join-Path $bk ($f -replace '[\\/]', '_')) }
Write-Host "BACKUP_OK $bk"

# ===== 3. Dry-run якорей (до любой записи) =====
$anchorFail = $false
foreach ($e in $script:edits) {
  $p = Join-Path $root $e.File
  $t = Lf ([IO.File]::ReadAllText($p))
  $cnt = ([regex]::Matches($t, [regex]::Escape($e.Old))).Count
  if ($cnt -ne 1) {
    Write-Host "ANCHOR_FAIL $($e.File): вхождений $cnt (нужен 1)"
    $anchorFail = $true
  }
}
if ($anchorFail) { Write-Host 'DRY_RUN_FAIL — ничего не записано.'; return }
Write-Host 'DRY_RUN_ANCHORS_OK 13/13'

# ===== 4. Запись (UTF-8 без BOM, LF — как исходники) =====
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($e in $script:edits) {
  $p = Join-Path $root $e.File
  $t = Lf ([IO.File]::ReadAllText($p))
  $t = $t.Replace($e.Old, $e.New)
  [IO.File]::WriteAllText($p, $t, $utf8)
}
Write-Host 'PATCH_WRITTEN'

# ===== 5. Post SHA =====
$postBad = $false
foreach ($f in $files) {
  $sha = (Get-FileHash (Join-Path $root $f) -Algorithm SHA256).Hash.ToLower()
  Write-Host "after  $f $sha"
  if ($sha -ne $expectedAfter[$f]) { Write-Host "POST_SHA_MISMATCH $f"; $postBad = $true }
}
if ($postBad) {
  Write-Host 'POST_SHA_FAIL — откатываю из backup.'
  foreach ($f in $files) { Copy-Item (Join-Path $bk ($f -replace '[\\/]', '_')) (Join-Path $root $f) -Force }
  return
}

# ===== 6. flutter analyze (с авто-rollback при ошибке) =====
Push-Location $root
$out = (& flutter analyze 2>&1 | Out-String)
Pop-Location
Write-Host $out
if ($out -notmatch 'No issues found') {
  Write-Host 'ANALYZE_FAIL — откатываю из backup.'
  foreach ($f in $files) { Copy-Item (Join-Path $bk ($f -replace '[\\/]', '_')) (Join-Path $root $f) -Force }
  return
}
Write-Host 'PACKAGE12_2_APPLIED_OK'
