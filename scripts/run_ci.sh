#!/usr/bin/env bash
# CI entry: smoke + layout + tactics e2e + full-chain e2e. Non-zero exit fails the pipeline.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/project"

echo "==> smoke"
godot --headless --path . --scene res://tests/smoke_runner.tscn

echo "==> layout_check"
godot --headless --path . --script res://tests/layout_check.gd

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

echo "==> CI ALL PASS"

# GitHub Actions: add .github/workflows/ci.yml that runs this script when the
# token has `workflow` scope. Local/agent CI: non-zero exit fails the pipeline.
