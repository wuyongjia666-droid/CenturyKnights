#!/usr/bin/env bash
# CI entry: python lints + auto-discovered suites + smoke + layout + tactics e2e + full-chain e2e.
# Usage: run_ci.sh [all|lint|godot]   (default all)
#   lint   python checks only, no Godot
#   godot  Godot suites and e2e scenes, CK_JOBS at a time (default: CPU count)
# CK_PORTRAIT_BANK_FULL=1 replays every portrait-bank seed and decodes every bank plate
# (main, nightly). Without it the bank check replays one seed and decodes changed plates.
# Non-zero exit fails the pipeline. Last line on success is "CI ALL PASS".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-all}"
case "$MODE" in all | lint | godot) ;; *)
	echo "usage: $0 [all|lint|godot]" >&2
	exit 2
	;;
esac
if [[ -n "${GODOT_PREFIX:-}" ]]; then
	export PATH="${GODOT_PREFIX}/bin:${PATH}"
fi
export PATH="${HOME}/.local/bin:${PATH}"

check() {
	local name="$1" marker="$2"
	shift 2
	echo "==> ${name}"
	"$@" 2>&1 | tee "/tmp/ck_${name}.log"
	grep -q "$marker" "/tmp/ck_${name}.log" || {
		echo "${name} FAILED"
		exit 1
	}
}

run_lint() {
	check json_lint "JSON LINT PASS" python3 "$ROOT/tools/ci/json_lint.py"
	check style_lint "STYLE LINT PASS" python3 "$ROOT/tools/ci/style_lint.py"
	check i18n_ratchet "I18N RATCHET PASS" python3 "$ROOT/tools/ci/i18n_ratchet.py"
	check gdlint "GDLINT PASS" python3 "$ROOT/tools/ci/gdlint_changed.py"
	check export_size "EXPORT SIZE PASS" python3 "$ROOT/tools/ci/export_size_report.py"
	check board_figure_gate "BOARD FIGURE GATE PASS" python3 "$ROOT/tools/ci/board_figure_gate.py"
	if [[ "${CK_PORTRAIT_BANK_FULL:-}" == "1" ]]; then
		check portrait_bank_index "BANK INDEX PASS" python3 "$ROOT/tools/ci/portrait_bank_index.py" --all \
			--verified-cache "${CK_BANK_VERIFIED:-${HOME}/.cache/ck/bank_verified.txt}"
	else
		check portrait_bank_index "BANK INDEX PASS" python3 "$ROOT/tools/ci/portrait_bank_index.py"
	fi
	echo "==> bloodlines_v89 data (fields, world wiring, anti-trope, fixtures)"
	python3 "$ROOT/tools/check_bloodlines_v89.py"
	echo "==> art usage audit (v840 zero-leftover)"
	python3 "$ROOT/tools/audit_v840_usage.py" >/tmp/ck_audit.log || {
		cat /tmp/ck_audit.log
		echo "art audit FAILED"
		exit 1
	}
	tail -1 /tmp/ck_audit.log
}

# One line per Godot run: name<TAB>--scene|--script<TAB>res path<TAB>pass marker (empty = exit code only).
godot_tasks() {
	local suite_file suite_rel name
	local -a heavy=() rest=()
	if [[ -d "$ROOT/project/tests/suites" ]]; then
		while IFS= read -r -d '' suite_file; do
			# A *_check.gd next to *_check.tscn is the scene script; Godot runs it through the scene.
			if [[ "$suite_file" == *.gd && -f "${suite_file%.gd}.tscn" ]]; then
				continue
			fi
			suite_rel="${suite_file#"$ROOT/project/"}"
			name="$(basename "$suite_file")"
			local flag="--script"
			[[ "$suite_file" == *.tscn ]] && flag="--scene"
			local line
			line="$(printf 'suite_%s\t%s\tres://%s\tPASS' "$name" "$flag" "$suite_rel")"
			case "$name" in
			portrait_bank_check.* | music_director_check.* | barks_check.* | endings_check.* | blood_payoff_check.* | placeholder_check.* | sfx_check.*)
				heavy+=("$line")
				;;
			*) rest+=("$line") ;;
			esac
		done < <(find "$ROOT/project/tests/suites" -type f \( -name '*_check.tscn' -o -name '*_check.gd' \) -print0 | sort -z)
	fi
	# Slowest first so the parallel pool drains evenly.
	printf '%s\n' "${heavy[@]}"
	printf '%s\t%s\t%s\t%s\n' \
		bloodline_v89 --scene res://tests/bloodline_v89_check.tscn "BLOODLINE V89 PASS" \
		campaign_century --scene res://tests/campaign_century_check.tscn "CAMPAIGN CENTURY PASS"
	printf '%s\n' "${rest[@]}"
	printf '%s\t%s\t%s\t%s\n' \
		smoke --scene res://tests/smoke_runner.tscn "" \
		layout_check --script res://tests/layout_check.gd "" \
		touch_router --script res://tests/touch_router_check.gd "TOUCH ROUTER PASS" \
		genome_check --script res://tests/genome_check.gd "GENOME PASS" \
		court_v90 --scene res://tests/court_v90_check.tscn "COURT V90 PASS" \
		court_ui --scene res://tests/court_ui_check.tscn "COURT UI PASS" \
		mobile_court_ui --scene res://tests/court_ui_check.tscn "COURT UI PASS" \
		portrait_manifest --scene res://tests/portrait_manifest_check.tscn "PORTRAIT PASS" \
		kinship_portrait --scene res://tests/kinship_portrait_check.tscn "KINSHIP PASS" \
		enemy_themes --scene res://tests/enemy_theme_check.tscn "ENEMY THEME PASS" \
		scene_load_check --script res://tests/scene_load_check.gd "SCENE LOAD PASS" \
		tactics_e2e --scene res://tests/tactics_e2e.tscn "" \
		full_chain_e2e --scene res://tests/full_chain_e2e.tscn "" \
		atlas_e2e --scene res://tests/atlas_e2e.tscn "=== ATLAS E2E PASS ===" \
		save_roundtrip --scene res://tests/save_roundtrip_check.tscn "SAVE ROUNDTRIP PASS"
}

run_godot() {
	if ! command -v godot >/dev/null 2>&1; then
		echo "godot not found. Run scripts/install_godot.sh first." >&2
		exit 1
	fi
	local jobs="${CK_JOBS:-$(nproc 2>/dev/null || echo 2)}"
	local tasks=/tmp/ck_tasks.tsv
	godot_tasks >"$tasks"
	rm -rf /tmp/ck_failed /tmp/ck_xdg
	mkdir -p /tmp/ck_failed
	echo "suites discovered: $(grep -c '^suite_' "$tasks")"
	echo "==> godot runs: $(wc -l <"$tasks") with ${jobs} in parallel"
	local started=$SECONDS
	# Each run gets its own XDG_DATA_HOME so user:// saves never leak between parallel suites.
	# Suites with wall-clock budgets run alone after the pool so CPU contention cannot fail them.
	local timed='^suite_(perf_boot_check|ai_regression_check|impact_check|terrain_check)\.'
	grep -vE "$timed" "$tasks" | tr '\n' '\0' | xargs -0 -P "$jobs" -I{} bash "$ROOT/scripts/ci_godot_run.sh" "$ROOT/project" "{}"
	grep -E "$timed" "$tasks" | tr '\n' '\0' | xargs -0 -P 1 -I{} bash "$ROOT/scripts/ci_godot_run.sh" "$ROOT/project" "{}"
	echo "==> godot runs finished in $((SECONDS - started))s"
	local failed
	failed="$(ls /tmp/ck_failed)"
	if [[ -n "$failed" ]]; then
		for name in $failed; do
			echo "----- ${name} FAILED, log follows"
			cat "/tmp/ck_${name}.log"
		done
		echo "FAILED: $(echo "$failed" | tr '\n' ' ')"
		exit 1
	fi
}

if [[ "$MODE" != godot ]]; then
	run_lint
fi
if [[ "$MODE" != lint ]]; then
	run_godot
fi
echo "==> CI ALL PASS"
