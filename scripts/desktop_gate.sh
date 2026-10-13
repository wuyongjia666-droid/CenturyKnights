#!/usr/bin/env bash
# Desktop screenshot gate: 1280x720 / 1920x1080 / 2560x1440, mouse input, no mobile reflow.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; OUT="${1:-/tmp/ck_desktop}"; SHEETS="${2:-$OUT/sheets}"
export PATH="${HOME}/.local/bin:${PATH}"
rm -rf "$OUT"; mkdir -p "$OUT"; cd "$ROOT"
CK_FORCE_MOBILE=0 timeout 1200 xvfb-run -a -s "-screen 0 2600x1500x24" godot --path project --rendering-driver opengl3 \
  --scene res://tests/suites/mobile/mobile_shots.tscn -- --desktop --out="$OUT" ${DESKTOP_ONLY:+--only=$DESKTOP_ONLY} 2>&1 | grep -E 'SHOT|MOBILE|ERROR' | tail -20
python3 tools/ci/desktop_gate.py "$OUT" "$SHEETS" ${DESKTOP_GATE_ARGS:-}
