#!/usr/bin/env bash
# Run a bpy script produced by cli-anything-blender, with Blender 4.2 EEVEE fix.
# Usage: tools/art/cli_anything_blender_run.sh /path/to/_render_script.py
set -euo pipefail
SCRIPT="${1:?need bpy script path}"
BLENDER="${BLENDER:-$(command -v blender || true)}"
if [[ -z "$BLENDER" ]]; then
  echo "blender not on PATH" >&2
  exit 1
fi
PATCHED="$(mktemp --suffix=.py)"
# Blender 4.2 renamed EEVEE → EEVEE_NEXT
sed 's/BLENDER_EEVEE'\''/BLENDER_EEVEE_NEXT'\''/g; s/"BLENDER_EEVEE"/"BLENDER_EEVEE_NEXT"/g' \
  "$SCRIPT" > "$PATCHED"
# Avoid double-NEXT if already patched
sed -i 's/BLENDER_EEVEE_NEXT_NEXT/BLENDER_EEVEE_NEXT/g' "$PATCHED"
exec "$BLENDER" --background --python "$PATCHED"
