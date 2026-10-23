# CenturyKnights Y1-A gap speakers (FARM-04 speaker only, nine plates). Run ON m173.
# Queue: tools/farm_queue/v92_y1a_gap_speakers.json (make_y1a_gap_speakers.py).
# Qwen :8322 only. Does not resubmit plates already on disk.
#
# Dry-run:
#   powershell -File tools\farm_queue\submit_y1a_gap_speakers_on_m173.ps1 -DryRun
#
# Submit the nine missing plates:
#   powershell -File tools\farm_queue\submit_y1a_gap_speakers_on_m173.ps1
#
# After Qwen finishes, gate + ingest from the farm root:
#   python tools\farm_queue\ingest_story_speakers.py --inbox <root>\out
#   python tools\art\build_portrait_tiers.py
param(
    [switch]$DryRun,
    [switch]$Dual
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
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
$Queue = Join-Path $PSScriptRoot "v92_y1a_gap_speakers.json"
if (-not (Test-Path $Queue)) { throw "missing $Queue — run make_y1a_gap_speakers.py first" }

$SubmitArgs = @(
    $Submit,
    "--root", $Root,
    "--scripts", $Scripts,
    "--farms", "FARM-04",
    "--kinds", "speaker",
    "--jobs-from", $Queue,
    "--missing-disk",
    "--shots-out", (Join-Path $Root "shots_v92_y1a_gap_speakers.json")
)
if ($DryRun) { $SubmitArgs += "--dry-run" }
if ($Dual) { $SubmitArgs += "--dual" }
& $Py @SubmitArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
