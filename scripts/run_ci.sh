#!/usr/bin/env bash
# CI entry: smoke + layout + tactics e2e + full-chain e2e. Non-zero exit fails the pipeline.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/project"

echo "==> smoke"
godot --headless --path . --scene res://tests/smoke_runner.tscn

echo "==> layout_check"
godot --headless --path . --script res://tests/layout_check.gd

echo "==> tactics_e2e"
godot --headless --path . --scene res://tests/tactics_e2e.tscn

echo "==> full_chain_e2e"
godot --headless --path . --scene res://tests/full_chain_e2e.tscn

echo "==> CI ALL PASS"

# GitHub Actions: add .github/workflows/ci.yml that runs this script when the
# token has `workflow` scope. Local/agent CI: non-zero exit fails the pipeline.
