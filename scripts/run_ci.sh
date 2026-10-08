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

echo "==> CI ALL PASS"

# GitHub Actions: add .github/workflows/ci.yml that runs this script when the
# token has `workflow` scope. Local/agent CI: non-zero exit fails the pipeline.
