#!/usr/bin/env bash
# Pre-push check: the fast subset of CI that fails most often, in well under 3 minutes.
# Run before every push (agents: required, see docs/ci.md).
#   scripts/precheck.sh            lints + ratchets + farm queue + key Godot suites
#   scripts/precheck.sh --no-godot python-only (about 10s)
# Compares against origin/main like a pull request does (override with CK_BASE=<branch>).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"
WITH_GODOT=1
[[ "${1:-}" == "--no-godot" ]] && WITH_GODOT=0
export GITHUB_BASE_REF="${CK_BASE:-main}"
timeout 30 git fetch -q --no-tags --filter=blob:none origin "$GITHUB_BASE_REF" 2>/dev/null ||
	echo "precheck: could not fetch origin/${GITHUB_BASE_REF}; comparing with the local copy"
start=$SECONDS

python3 -c "import PIL, numpy" 2>/dev/null || {
	echo "precheck: Pillow/numpy missing (WebP and audio checks need them): python3 -m pip install --user pillow numpy 'gdtoolkit==4.*'" >&2
	exit 1
}
command -v ffmpeg >/dev/null 2>&1 || echo "precheck: ffmpeg missing; audio suites will try to apt-install it" >&2

echo "==> farm queue"
python3 tools/farm_queue/validate_queue_v92.py >/tmp/ck_pre_farm.log 2>&1 &&
	python3 tools/farm_queue/test_submit_v92.py >>/tmp/ck_pre_farm.log 2>&1 &&
	python3 tools/farm_queue/validate_farm06_07.py >>/tmp/ck_pre_farm.log 2>&1 &&
	python3 tools/farm_queue/test_farm06_07.py >>/tmp/ck_pre_farm.log 2>&1 || {
	cat /tmp/ck_pre_farm.log
	echo "farm queue FAILED"
	exit 1
}

./scripts/run_ci.sh lint

if [[ $WITH_GODOT == 0 ]]; then
	echo "==> PRECHECK PASS (python only, $((SECONDS - start))s)"
	exit 0
fi
if ! command -v godot >/dev/null 2>&1; then
	echo "precheck: godot not found (scripts/install_godot.sh); skipped Godot suites" >&2
	echo "==> PRECHECK PASS (python only, $((SECONDS - start))s)"
	exit 0
fi

echo "==> import (and .import drift)"
(cd project && godot --headless --import >/tmp/ck_import.log 2>&1) || {
	tail -30 /tmp/ck_import.log
	echo "import FAILED"
	exit 1
}
drift="$(git status --porcelain -- 'project/*.import' 'project/**/*.import')"
if [[ -n "$drift" ]]; then
	echo "$drift" | head -20
	echo "Godot rewrote or added .import files: commit them (CI fails on this)."
	exit 1
fi

# Locale CSV, chapter/endings seeds, campaign century, portrait manifest + bank (fast mode), scene load.
mkdir -p /tmp/ck_failed
rm -f /tmp/ck_failed/*
printf '%s\t%s\t%s\t%s\n' \
	suite_portrait_bank_check.tscn --scene res://tests/suites/art/portrait_bank_check.tscn "PORTRAIT BANK PASS" \
	campaign_century --scene res://tests/campaign_century_check.tscn "CAMPAIGN CENTURY PASS" \
	suite_endings_check.tscn --scene res://tests/suites/narrative/endings_check.tscn "PASS" \
	suite_chapter_player_check.tscn --scene res://tests/suites/narrative/chapter_player_check.tscn "PASS" \
	suite_l10n_check.tscn --scene res://tests/suites/ux/l10n_check.tscn "PASS" \
	suite_expression_fallback_check.tscn --scene res://tests/suites/art/expression_fallback_check.tscn "PASS" \
	portrait_manifest --scene res://tests/portrait_manifest_check.tscn "PORTRAIT PASS" \
	scene_load_check --script res://tests/scene_load_check.gd "SCENE LOAD PASS" |
	tr '\n' '\0' | xargs -0 -P "${CK_JOBS:-$(nproc 2>/dev/null || echo 2)}" -I{} bash scripts/ci_godot_run.sh "$ROOT/project" "{}"
failed="$(ls /tmp/ck_failed)"
if [[ -n "$failed" ]]; then
	for name in $failed; do
		echo "----- ${name}"
		tail -40 "/tmp/ck_${name}.log"
	done
	echo "PRECHECK FAILED: $(echo "$failed" | tr '\n' ' ')"
	exit 1
fi
echo "==> PRECHECK PASS ($((SECONDS - start))s). Full suite: scripts/run_ci.sh"
