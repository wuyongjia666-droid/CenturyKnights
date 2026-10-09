# CenturyKnights v9.2 one-shot stills (FARM-01..05). Run this ON m173.
# Default: Qwen http://192.168.9.244:8322 only.
#   dual_submit_stills.py --sn-backend local --only qwen
# SenseNova local :8329 is optional. Its stills look worse, so it stays idle
# unless you pass -Dual (or set CK_FARM_DUAL=1). Dual then uses
#   --spread --sn-backend local --only both
# Never SN cloud / SN api / Qwen *Api nodes / Flux.
# CK_FARM_ALLOW_QWEN_ONLY is obsolete; Qwen-only is already the default.
#
# Dry-run (no LAN probe, no submit):
#   powershell -File tools\farm_queue\submit_v92_on_m173.ps1 -DryRun
#   python tools\farm_queue\validate_queue_v92.py
#
# Submit the full stills batch to Qwen:
#   powershell -File tools\farm_queue\submit_v92_on_m173.ps1
#
# Optional dual fill (only when you still want SenseNova):
#   powershell -File tools\farm_queue\submit_v92_on_m173.ps1 -Dual
#
# Output root (created if needed):
#   D:\AIComics\CenturyKnights_farm
#   fallback D:\CenturyKnights_farm
# Staged shots JSON: <root>\shots_v92_farm.json
#   JSON list, not {"shots":[...]}. load_shots reads each object's "label".
#   "id" is the same string as "label".
# Repo destinations stay on each shot as out_path (project/assets/art/...).
#
# Poll only when an operator asks (this script does not loop):
#   python tools\farm_queue\submit_v92_stills.py --poll
#   Invoke-WebRequest http://192.168.9.244:8322/queue -UseBasicParsing
#   Invoke-WebRequest http://192.168.9.244:8329/queue -UseBasicParsing
#
# Dual opt-in without -Dual:
#   $env:CK_FARM_DUAL = "1"
#   powershell -File tools\farm_queue\submit_v92_on_m173.ps1
# There is no --only switch. Qwen down aborts (exit 2). Dual with SenseNova
# down aborts (exit 3) instead of silently dropping back to Qwen.
#
# aic-farm scripts (first path that exists):
#   D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts
#   C:\Users\m1736\.cursor\skills\aic-farm\scripts
param([switch]$DryRun, [switch]$Dual)

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
$SubmitArgs = @($Submit, "--root", $Root, "--scripts", $Scripts)
if ($DryRun) { $SubmitArgs += "--dry-run" }
if ($Dual) { $SubmitArgs += "--dual" }
& $Py @SubmitArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
