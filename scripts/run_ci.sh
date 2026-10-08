#!/usr/bin/env bash
# CI entry: json lint + auto-discovered suites + smoke + layout + tactics e2e + full-chain e2e.
# Non-zero exit fails the pipeline. Last line on success is "CI ALL PASS".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${GODOT_PREFIX:-}" ]]; then
	export PATH="${GODOT_PREFIX}/bin:${PATH}"
fi
export PATH="${HOME}/.local/bin:${PATH}"
if ! command -v godot >/dev/null 2>&1; then
	echo "godot not found. Run scripts/install_godot.sh first." >&2
	exit 1
fi

echo "==> json_lint"
python3 "$ROOT/tools/ci/json_lint.py" 2>&1 | tee /tmp/ck_json_lint.log
grep -q "JSON LINT PASS" /tmp/ck_json_lint.log || { echo "json_lint FAILED"; exit 1; }

echo "==> style_lint"
python3 "$ROOT/tools/ci/style_lint.py" 2>&1 | tee /tmp/ck_style_lint.log
grep -q "STYLE LINT PASS" /tmp/ck_style_lint.log || { echo "style_lint FAILED"; exit 1; }

echo "==> i18n_ratchet"
python3 "$ROOT/tools/ci/i18n_ratchet.py" 2>&1 | tee /tmp/ck_i18n_ratchet.log
grep -q "I18N RATCHET PASS" /tmp/ck_i18n_ratchet.log || { echo "i18n_ratchet FAILED"; exit 1; }

echo "==> export_size"
python3 "$ROOT/tools/ci/export_size_report.py" 2>&1 | tee /tmp/ck_export_size.log
grep -q "EXPORT SIZE PASS" /tmp/ck_export_size.log || { echo "export_size FAILED"; exit 1; }

cd "$ROOT/project"

echo "==> suites"
suite_files=()
if [[ -d "$ROOT/project/tests/suites" ]]; then
	while IFS= read -r -d '' suite_file; do
		suite_files+=("$suite_file")
	done < <(find "$ROOT/project/tests/suites" -type f \( -name '*_check.tscn' -o -name '*_check.gd' \) -print0 | sort -z)
fi
echo "suites discovered: ${#suite_files[@]}"
for suite_file in "${suite_files[@]}"; do
	# A *_check.gd next to *_check.tscn is the scene script (extends Node). Godot
	# runs it through the scene; launching it with --script would fail.
	if [[ "$suite_file" == *.gd && -f "${suite_file%.gd}.tscn" ]]; then
		continue
	fi
	suite_rel="${suite_file#"$ROOT/project/"}"
	suite_name="$(basename "$suite_file")"
	suite_log="/tmp/ck_suite_${suite_name}.log"
	echo "==> suite ${suite_name}"
	if [[ "$suite_file" == *.tscn ]]; then
		godot --headless --path . --scene "res://${suite_rel}" >"$suite_log" 2>&1 || {
			echo "suite ${suite_name} FAILED"
			cat "$suite_log"
			exit 1
		}
	else
		godot --headless --path . --script "res://${suite_rel}" >"$suite_log" 2>&1 || {
			echo "suite ${suite_name} FAILED"
			cat "$suite_log"
			exit 1
		}
	fi
	grep -q "PASS" "$suite_log" || {
		echo "suite ${suite_name} FAILED (no PASS)"
		cat "$suite_log"
		exit 1
	}
done

echo "==> smoke"
godot --headless --path . --scene res://tests/smoke_runner.tscn

echo "==> layout_check"
godot --headless --path . --script res://tests/layout_check.gd

echo "==> touch_router"
godot --headless --path . --script res://tests/touch_router_check.gd 2>&1 | tee /tmp/ck_touch.log
grep -q "TOUCH ROUTER PASS" /tmp/ck_touch.log || { echo "touch_router FAILED"; exit 1; }

echo "==> genome_check (v8.7 inheritance laws)"
godot --headless --path . --script res://tests/genome_check.gd 2>&1 | tee /tmp/ck_genome.log
grep -q "GENOME PASS" /tmp/ck_genome.log || { echo "genome_check FAILED"; exit 1; }

echo "==> bloodlines_v89 data (fields, world wiring, anti-trope, fixtures)"
python3 "$ROOT/tools/check_bloodlines_v89.py"

echo "==> bloodline_v89 (ten blood laws, pools, verify, succession, portrait clauses)"
godot --headless --path . --scene res://tests/bloodline_v89_check.tscn 2>&1 | tee /tmp/ck_bloodline.log
grep -q "BLOODLINE V89 PASS" /tmp/ck_bloodline.log || { echo "bloodline_v89 FAILED"; exit 1; }

echo "==> court_v90 (lamp seat, marriage rites, royal houses, titles, regalia)"
godot --headless --path . --scene res://tests/court_v90_check.tscn 2>&1 | tee /tmp/ck_court.log
grep -q "COURT V90 PASS" /tmp/ck_court.log || { echo "court_v90 FAILED"; exit 1; }

echo "==> court_ui (codex, dossier, blood test, rites, gazette, titles, safe area)"
godot --headless --path . --scene res://tests/court_ui_check.tscn 2>&1 | tee /tmp/ck_court_ui.log
grep -q "COURT UI PASS" /tmp/ck_court_ui.log || { echo "court_ui FAILED"; exit 1; }

echo "==> portrait_manifest (v8.9 plan A genome plates)"
godot --headless --path . --scene res://tests/portrait_manifest_check.tscn 2>&1 | tee /tmp/ck_portrait.log
grep -q "PORTRAIT PASS" /tmp/ck_portrait.log || { echo "portrait_manifest FAILED"; exit 1; }

echo "==> kinship_portrait (3-gen descriptor resemblance)"
godot --headless --path . --scene res://tests/kinship_portrait_check.tscn 2>&1 | tee /tmp/ck_kinship.log
grep -q "KINSHIP PASS" /tmp/ck_kinship.log || { echo "kinship_portrait FAILED"; exit 1; }

echo "==> enemy_themes (reused GLB kits)"
godot --headless --path . --scene res://tests/enemy_theme_check.tscn 2>&1 | tee /tmp/ck_enemy_theme.log
grep -q "ENEMY THEME PASS" /tmp/ck_enemy_theme.log || { echo "enemy_themes FAILED"; exit 1; }

echo "==> scene_load_check"
godot --headless --path . --script res://tests/scene_load_check.gd 2>&1 | tee /tmp/ck_scene_load.log
if grep -q "SCRIPT ERROR\|Parse Error\|^FAIL " /tmp/ck_scene_load.log || ! grep -q "SCENE LOAD PASS" /tmp/ck_scene_load.log; then echo "scene_load_check FAILED"; exit 1; fi

echo "==> art usage audit (v840 zero-leftover)"
python3 "$ROOT/tools/audit_v840_usage.py" > /tmp/ck_audit.log || { cat /tmp/ck_audit.log; echo "art audit FAILED"; exit 1; }
tail -1 /tmp/ck_audit.log

echo "==> tactics_e2e"
godot --headless --path . --scene res://tests/tactics_e2e.tscn

echo "==> full_chain_e2e"
godot --headless --path . --scene res://tests/full_chain_e2e.tscn

echo "==> atlas_e2e (v8.7 overworld: travel → city → smith → commission → battle → turn-in → save/load)"
godot --headless --path . --scene res://tests/atlas_e2e.tscn 2>&1 | tee /tmp/ck_atlas_e2e.log
grep -q "=== ATLAS E2E PASS ===" /tmp/ck_atlas_e2e.log || { echo "atlas_e2e FAILED"; exit 1; }

echo "==> save_roundtrip (v9.1 fields, v8.7/v8.8 migration)"
godot --headless --path . --scene res://tests/save_roundtrip_check.tscn 2>&1 | tee /tmp/ck_save.log
grep -q "SAVE ROUNDTRIP PASS" /tmp/ck_save.log || { echo "save_roundtrip FAILED"; exit 1; }

echo "==> campaign_century (100-year scripted company)"
godot --headless --path . --scene res://tests/campaign_century_check.tscn 2>&1 | tee /tmp/ck_campaign.log
grep -q "CAMPAIGN CENTURY PASS" /tmp/ck_campaign.log || { echo "campaign_century FAILED"; exit 1; }

echo "==> CI ALL PASS"
