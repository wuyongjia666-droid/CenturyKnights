#!/usr/bin/env bash
# Capture 12 screens x 2 ratios under Xvfb and reject warm/gold frames.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/ck_shots}"
if [[ -n "${GODOT_PREFIX:-}" ]]; then
	export PATH="${GODOT_PREFIX}/bin:${PATH}"
fi
export PATH="${HOME}/.local/bin:${PATH}"
if ! command -v godot >/dev/null 2>&1; then
	echo "godot not found. Run scripts/install_godot.sh first." >&2
	exit 1
fi
python3 -c "import numpy, PIL" 2>/dev/null || python3 -m pip install --quiet numpy pillow
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"
xvfb-run -a -s "-screen 0 1200x2500x24" \
	godot --path project --rendering-driver opengl3 \
	--scene res://tests/suites/infra/capture_check.tscn -- --out="$OUT"
python3 "$ROOT/tools/ci/shot_style.py" "$OUT"
