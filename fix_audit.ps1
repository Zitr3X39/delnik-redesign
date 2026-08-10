$ErrorActionPreference = "Stop"
$root = "C:\shabashka_app\lib"

function FixFile($rel, $pairs) {
    $p = Join-Path $root $rel
    if (!(Test-Path $p)) { Write-Host ("  NET FAJLA: " + $p); return }
    Copy-Item $p "$p.bak" -Force
    $c = [System.IO.File]::ReadAllText($p)
    Write-Host ("=== " + $rel + " ===")
    foreach ($pair in $pairs) {
        $old = $pair[0]
        $new = $pair[1]
        $n = ([regex]::Matches($c, [regex]::Escape($old))).Count
        if ($n -gt 0) { $c = $c.Replace($old, $new) }
        $tag = "OK"
        if ($n -eq 0) { $tag = "PROPUSHCHENO (ne najdeno)" }
        if ($n -gt 1) { $tag = "VNIMANIE: najdeno $n" }
        Write-Host ("  zamen=" + $n + "  " + $tag)
    }
    [System.IO.File]::WriteAllText($p, $c)
}

FixFile "screens\home_screen.dart" @(
    ,@("title: 'Рабочий — Уфа',", "title: 'Дельник',")
)

FixFile "providers\job_provider.dart" @(
    @("List<Review> reviewsForUser(String userId) => _reviews", "List<Review> reviewsForUser(String userId, {bool? asEmployer}) => _reviews"),
    @(".where((r) => r.targetId == userId && r.text.trim().isNotEmpty)", ".where((r) => r.targetId == userId && r.text.trim().isNotEmpty && (asEmployer == null || _isEmployerReview(r) == asEmployer))"),
    @("int completedJobsFor(String userId) {", "int completedJobsFor(String userId, {bool? asEmployer}) {"),
    @("final jobIds = _reviewsAbout(userId).map((r) => r.jobId).toSet();", "final jobIds = _reviewsAbout(userId).where((r) => asEmployer == null || _isEmployerReview(r) == asEmployer).map((r) => r.jobId).toSet();"),
    @("final profile = _performers[userId]?.completedJobs ?? 0;", "final profile = (asEmployer == true) ? 0 : (_performers[userId]?.completedJobs ?? 0);")
)

FixFile "screens\user_profile_screen.dart" @(
    @("final reviews = provider.reviewsForUser(userId);", "final reviews = provider.reviewsForUser(userId, asEmployer: asEmployer);"),
    @("final completed = provider.completedJobsFor(userId);", "final completed = provider.completedJobsFor(userId, asEmployer: asEmployer);")
)

Write-Host ""
Write-Host "Gotovo. Vse stroki dolzhny byt zamen=1. Esli gde-to zamen=0 - soobshchi mne."
