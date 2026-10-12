#!/usr/bin/env bash
# Mobile landscape screenshot gate (see docs/design/mobile-landscape.md).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; OUT="${1:-/tmp/ck_mobile}"; SHEETS="${2:-$OUT/sheets}"
export PATH="${HOME}/.local/bin:${PATH}"
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$ROOT"
CK_FORCE_MOBILE=1 timeout 900 xvfb-run -a -s "-screen 0 2600x1700x24" godot --path project --rendering-driver opengl3 \
  --scene res://tests/suites/mobile/mobile_shots.tscn -- --out="$OUT" 2>&1 | grep -E 'SHOT|MOBILE|ERROR' | tail -20
python3 tools/ci/mobile_gate.py "$OUT" "$SHEETS" ${MOBILE_GATE_ARGS:-}
