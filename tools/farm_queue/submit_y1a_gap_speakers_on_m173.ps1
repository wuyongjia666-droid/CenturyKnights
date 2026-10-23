# Submit the 9 Y1-A gap speakers on m173 (Qwen stills via dual_submit_stills).
# Farm mirror D:\CenturyKnights_farm\repo may be stale (broken .git / incomplete
# status_overlays), so this path validates ONLY the gap jobs file, then dry-runs
# and submits with --jobs-from.
$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

$Repo = if ($env:CK_FARM_REPO) { $env:CK_FARM_REPO } else { "D:\CenturyKnights_farm\repo" }
$FarmRoot = if ($env:CK_FARM_ROOT) { $env:CK_FARM_ROOT } else { "D:\AIComics\CenturyKnights_farm" }
$Dual = if ($env:CK_DUAL_SUBMIT) {
  $env:CK_DUAL_SUBMIT
} else {
  "D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts\dual_submit_stills.py"
}
$Py = if ($env:CK_PYTHON) { $env:CK_PYTHON } else { "python" }
$Queue = Join-Path $Repo "tools\farm_queue"
$Jobs = Join-Path $Queue "v92_y1a_gap_speakers.json"

if (-not (Test-Path $Jobs)) { throw "missing $Jobs — sync feat/y1a-nine-speaker-farm first" }
if (-not (Test-Path $Dual)) { throw "missing dual_submit at $Dual" }

Write-Host "=== GAP QUEUE SELF-CHECK ==="
& $Py -c @"
import json, sys
from pathlib import Path
p = Path(r'$Jobs')
doc = json.loads(p.read_text(encoding='utf-8'))
jobs = doc.get('jobs') or []
assert len(jobs) == 9, f'expected 9 jobs, got {len(jobs)}'
for j in jobs:
    assert j.get('kind') == 'speaker', j
    assert j.get('prompt_zh'), j.get('id')
    assert j.get('out_rel'), j.get('id')
print(f'GAP QUEUE OK jobs={len(jobs)} ids={[j[\"id\"] for j in jobs]}')
"@
if ($LASTEXITCODE -ne 0) { throw "gap self-check failed" }

Write-Host "=== DRY-RUN ==="
& $Py (Join-Path $Queue "submit_v92_stills.py") `
  --farms FARM-04 `
  --jobs-from $Jobs `
  --farm-root $FarmRoot `
  --dual-submit $Dual `
  --dry-run
if ($LASTEXITCODE -ne 0) { throw "dry-run failed" }

Write-Host "=== SUBMIT ==="
& $Py (Join-Path $Queue "submit_v92_stills.py") `
  --farms FARM-04 `
  --jobs-from $Jobs `
  --farm-root $FarmRoot `
  --dual-submit $Dual
if ($LASTEXITCODE -ne 0) { throw "submit failed" }

Write-Host "=== DONE — poll with: python tools/farm_queue/poll_v92_stills.py --farms FARM-04 --kinds speaker ==="
