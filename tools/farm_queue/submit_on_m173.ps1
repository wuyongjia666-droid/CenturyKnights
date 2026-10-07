# Run ON m173 when 192.168.9.244 is reachable. Dual-submit all CK v7.21 shots.
$ErrorActionPreference = "Stop"
$Scripts = "D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts"
if (-not (Test-Path $Scripts)) { $Scripts = "C:\Users\m1736\.cursor\skills\aic-farm\scripts" }
$Py = "C:\Users\m1736\AppData\Local\Programs\Python\Python312\python.exe"
if (-not (Test-Path $Py)) { $Py = "python" }
$Root = "D:\AIComics\CenturyKnights_farm"
$Shots = Join-Path $PSScriptRoot "shots_v721.json"
# If shots live next to this script after CopyToBox reverse: keep local copy path
if (-not (Test-Path $Shots)) { $Shots = "C:\Users\m1736\CenturyKnights_farm\shots_v721.json" }
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Write-Host "Probe Qwen..."
try { Invoke-WebRequest "http://192.168.9.244:8322/system_stats" -TimeoutSec 5 -UseBasicParsing | Out-Null } catch { throw "Qwen :8322 unreachable: $_" }
Write-Host "Probe SN local..."
try { Invoke-WebRequest "http://192.168.9.244:8329/system_stats" -TimeoutSec 5 -UseBasicParsing | Out-Null } catch { throw "SN :8329 unreachable: $_" }
& $Py (Join-Path $Scripts "dual_submit_stills.py") --root $Root --shots-json $Shots --spread --sn-backend local --only both
Write-Host "SUBMITTED dual queue — poll only when operator asks"
