#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../project"
godot --headless --path . --scene res://tests/smoke_runner.tscn
