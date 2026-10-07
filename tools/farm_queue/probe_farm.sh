#!/usr/bin/env bash
# CenturyKnights farm probe — m173 LAN Comfy
# Prefer Qwen :8322; dual SenseNova local :8329. Never SN cloud / *Api nodes.
set -euo pipefail
QWEN="${COMFYUI_QWEN:-http://192.168.9.244:8322}"
SN="${COMFYUI_SN:-http://192.168.9.244:8329}"
echo "[probe] $(date -Iseconds) Qwen=$QWEN SN=$SN"
ok=0
for url in "$QWEN/system_stats" "$QWEN/v1/models" "$SN/system_stats"; do
  code=$(curl -sS -m 4 -o /tmp/ck_farm_probe.json -w "%{http_code}" "$url" || true)
  echo "  $url -> HTTP $code"
  if [[ "$code" == "200" ]]; then ok=1; fi
done
if [[ "$ok" -eq 1 ]]; then
  echo "[probe] FARM REACHABLE — run tools/farm_queue/submit_ck_v720_queue.py"
  exit 0
fi
echo "[probe] FARM UNREACHABLE — box not on m173 LAN or Comfy down"
exit 1
