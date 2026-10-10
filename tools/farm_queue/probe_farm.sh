#!/usr/bin/env bash
# CenturyKnights farm probe — m173 LAN Comfy
# Default stills submit is Qwen :8322 only. SenseNova :8329 is optional (-Dual).
# Never SN cloud / *Api nodes.
set -euo pipefail
QWEN="${COMFYUI_QWEN:-http://192.168.9.244:8322}"
SN="${COMFYUI_SN:-http://192.168.9.244:8329}"
echo "[probe] $(date -Iseconds) Qwen=$QWEN SN=$SN"
q_ok=0
s_ok=0
for url in "$QWEN/system_stats" "$QWEN/v1/models"; do
  code=$(curl -sS -m 4 -o /tmp/ck_farm_probe.json -w "%{http_code}" "$url" || true)
  echo "  $url -> HTTP $code"
  if [[ "$code" == "200" ]]; then q_ok=1; fi
done
code=$(curl -sS -m 4 -o /tmp/ck_farm_probe.json -w "%{http_code}" "$SN/system_stats" || true)
echo "  $SN/system_stats -> HTTP $code"
if [[ "$code" == "200" ]]; then s_ok=1; fi
if [[ "$q_ok" -eq 1 ]]; then
  echo "[probe] QWEN REACHABLE — on m173 run tools/farm_queue/submit_v92_on_m173.ps1 (FARM-01..05, Qwen-only)"
  if [[ "$s_ok" -eq 1 ]]; then
    echo "[probe] SenseNova :8329 is up; default stills leave it idle. Pass -Dual only to spread."
  fi
  exit 0
fi
echo "[probe] QWEN UNREACHABLE — box not on m173 LAN or Comfy :8322 down"
exit 1
