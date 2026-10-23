# Submit the 9 Y1-A gap speakers on m173 (Qwen stills via dual_submit_stills).
# Farm mirror D:\CenturyKnights_farm\repo may be stale (broken .git / incomplete
# status_overlays), so this path self-checks the 9-job file only, then dry-runs
# and submits with --jobs-from.
#
# Dry-run:
#   powershell -File tools\farm_queue\submit_y1a_gap_speakers_on_m173.ps1 -DryRun
#
# Submit:
#   powershell -File tools\farm_queue\submit_y1a_gap_speakers_on_m173.ps1
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

$Queue = $PSScriptRoot
$Jobs = Join-Path $Queue "v92_y1a_gap_speakers.json"
$Submit = Join-Path $Queue "submit_v92_stills.py"
if (-not (Test-Path $Jobs)) { throw "missing $Jobs — sync feat/y1a-nine-speaker-farm first" }
if (-not (Test-Path $Submit)) { throw "missing $Submit" }
if (-not (Test-Path (Join-Path $Scripts "dual_submit_stills.py"))) {
    throw "missing dual_submit_stills.py under $Scripts"
}

Write-Host "=== GAP QUEUE SELF-CHECK ==="
& $Py -c @"
import json
from pathlib import Path
p = Path(r'$Jobs')
doc = json.loads(p.read_text(encoding='utf-8'))
jobs = doc.get('jobs') or []
assert len(jobs) == 9, f'expected 9 jobs, got {len(jobs)}'
for j in jobs:
    assert j.get('kind') == 'speaker', j
    assert j.get('positive'), j.get('id')
    assert j.get('out_path'), j.get('id')
print(f'GAP QUEUE OK jobs={len(jobs)} ids={[j[\"id\"] for j in jobs]}')
"@
if ($LASTEXITCODE -ne 0) { throw "gap self-check failed" }

$SubmitArgs = @(
    $Submit,
    "--root", $Root,
    "--scripts", $Scripts,
    "--farms", "FARM-04",
    "--jobs-from", $Jobs,
    "--shots-out", (Join-Path $Root "shots_v92_y1a_gap_speakers.json")
)
if ($DryRun) { $SubmitArgs += "--dry-run" }
if ($Dual) { $SubmitArgs += "--dual" }

if ($DryRun) {
    Write-Host "=== DRY-RUN ==="
} else {
    Write-Host "=== SUBMIT (Qwen-only) ==="
}
& $Py @SubmitArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $DryRun) {
    Write-Host "=== DONE — poll: python tools\farm_queue\submit_v92_stills.py --poll ==="
}
