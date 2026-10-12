# CenturyKnights status overlay stills (FARM-04 status_overlay only). Run ON m173.
# Six shared RGBA overlays — not a face×status matrix. Qwen :8322 only.
#
# Dry-run:
#   powershell -File tools\farm_queue\submit_status_overlays_on_m173.ps1 -DryRun
#
# Submit the six overlays (and keep the farm warm with the rest of FARM-04 unless -OnlyStatus):
#   powershell -File tools\farm_queue\submit_status_overlays_on_m173.ps1
#   powershell -File tools\farm_queue\submit_status_overlays_on_m173.ps1 -OnlyStatus
#
# After Qwen finishes, gate + ingest from the farm root:
#   python tools\farm_queue\ingest_status_overlays.py --inbox <root>\out
#   (or the directory dual_submit wrote; pass --dry-run first)
param(
    [switch]$DryRun,
    [switch]$OnlyStatus,
    [switch]$Dual
)

$ErrorActionPreference = "Stop"
$Scripts = "D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts"
if (-not (Test-Path $Scripts)) { $Scripts = "C:\Users\m1736\.cursor\skills\aic-farm\scripts" }
$Py = "C:\Users\m1736\AppData\Local\Programs\Python\Python312\python.exe"
if (-not (Test-Path $Py)) { $Py = "python" }
$Root = "D:\AIComics\CenturyKnights_farm"
if (-not (Test-Path $Root)) {
    $Alt = "D:\CenturyKnights_farm"
    if (Test-Path $Alt) { $Root = $Alt }
}
New-Item -ItemType Directory -Force -Path $Root | Out-Null
$Submit = Join-Path $PSScriptRoot "submit_v92_stills.py"
if (-not (Test-Path $Submit)) { throw "missing $Submit" }

$SubmitArgs = @($Submit, "--root", $Root, "--scripts", $Scripts, "--farms", "FARM-04")
if ($OnlyStatus) {
    $SubmitArgs += @("--kinds", "status_overlay")
    $SubmitArgs += @("--shots-out", (Join-Path $Root "shots_v92_status_overlays.json"))
} else {
    # Full FARM-04 (scenes + expressions + status) so the farm never idles after six overlays.
    $SubmitArgs += @("--shots-out", (Join-Path $Root "shots_v92_farm04.json"))
}
if ($DryRun) { $SubmitArgs += "--dry-run" }
if ($Dual) { $SubmitArgs += "--dual" }
& $Py @SubmitArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
