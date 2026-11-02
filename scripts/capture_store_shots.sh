#!/usr/bin/env bash
# Capture five store-listing landscape frames (≥1080p) via Godot + Xvfb.
# Usage: bash scripts/capture_store_shots.sh [/tmp/ck-store-shots]
# Does not upload or spend. PNGs stay out of git; write/copy manifest for the gate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/ck-store-shots}"
if [[ -n "${GODOT_PREFIX:-}" ]]; then
	export PATH="${GODOT_PREFIX}/bin:${PATH}"
fi
export PATH="${HOME}/.local/bin:${PATH}"
if ! command -v godot >/dev/null 2>&1; then
	echo "godot not found. Run scripts/install_godot.sh first." >&2
	exit 1
fi
if ! command -v xvfb-run >/dev/null 2>&1; then
	echo "xvfb-run not found (needed for real frames)." >&2
	exit 1
fi
python3 -c "import PIL" 2>/dev/null || python3 -m pip install --quiet pillow
rm -rf "$OUT"
mkdir -p "$OUT"
cd "$ROOT"
# 1920x1080+ virtual screen; opengl3 matches capture_screens.sh / shots CI job.
xvfb-run -a -s "-screen 0 1920x1200x24" \
	godot --path project --rendering-driver opengl3 \
	--scene res://tests/suites/store/store_listing_shots.tscn -- --out="$OUT"
# Prefer docs/store/shots for local engineering path (gitignored PNGs).
DOCS_SHOTS="$ROOT/docs/store/shots"
mkdir -p "$DOCS_SHOTS"
shopt -s nullglob
for png in "$OUT"/*.png; do
	cp -f "$png" "$DOCS_SHOTS/$(basename "$png")"
done
if [[ -f "$OUT/manifest.json" ]]; then
	cp -f "$OUT/manifest.json" "$DOCS_SHOTS/manifest.json"
	# Also keep a committed-friendly copy under docs/store (sha filled by gate helper).
	python3 "$ROOT/tools/ci/store_shots_check.py" --write-manifest-from "$OUT" --manifest "$ROOT/docs/store/shots-manifest.json" || true
fi
echo "STORE SHOTS CAPTURE DONE out=$OUT docs=$DOCS_SHOTS"
