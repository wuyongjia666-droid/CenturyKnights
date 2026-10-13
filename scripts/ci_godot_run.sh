#!/usr/bin/env bash
# One Godot run for run_ci.sh. Args: <project dir> "<name>\t<--scene|--script>\t<res path>\t<marker>"
# Writes /tmp/ck_<name>.log; on failure touches /tmp/ck_failed/<name>. Always exits 0 so xargs keeps going.
set -uo pipefail
project="$1"
IFS=$'\t' read -r name flag res marker <<<"$2"
log="/tmp/ck_${name}.log"
export XDG_DATA_HOME="/tmp/ck_xdg/${name}"
mkdir -p "$XDG_DATA_HOME"
# mobile_* runs replay a suite in forced phone mode (DeviceProfile reads CK_FORCE_MOBILE).
[[ "$name" == mobile_* ]] && export CK_FORCE_MOBILE=1
start=$SECONDS
timeout --kill-after=30 "${CK_TEST_TIMEOUT:-600}" godot --headless --path "$project" "$flag" "$res" >"$log" 2>&1
code=$?
[[ $code -eq 124 || $code -eq 137 ]] && echo "TIMEOUT after ${CK_TEST_TIMEOUT:-600}s (script failed to load or never quit?)" >>"$log"
ok=1
if [[ $code -ne 0 ]]; then
	ok=0
elif [[ -n "$marker" ]] && ! grep -qF "$marker" "$log"; then
	ok=0
elif [[ "$name" == scene_load_check ]] && grep -q "SCRIPT ERROR\|Parse Error\|^FAIL " "$log"; then
	ok=0
fi
if [[ $ok -eq 1 ]]; then
	echo "ok   ${name} ($((SECONDS - start))s)"
else
	echo "FAIL ${name} ($((SECONDS - start))s, exit ${code})"
	: >"/tmp/ck_failed/${name}"
fi
exit 0
