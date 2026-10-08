#!/usr/bin/env bash
# Windows Desktop release for the Godot 4.3 "Windows Desktop" preset.
# Exits 2 with a short message when Godot 4.3 or the matching export templates
# are missing. Does not print signing secrets (this preset is unsigned).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/project"
OUT="$ROOT/exports/CenturyKnights.exe"

fail() {
	echo "ERROR: $*" >&2
	exit 2
}

GODOT_BIN="${GODOT:-}"
if [[ -z "$GODOT_BIN" ]]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT_BIN="godot"
	elif command -v godot4 >/dev/null 2>&1; then
		GODOT_BIN="godot4"
	fi
fi
if [[ -z "$GODOT_BIN" ]]; then
	fail "未找到 Godot 4.3 可执行文件。请安装 Godot 4.3 并加入 PATH，或设置 GODOT=/path/to/godot。"
fi

VER="$("$GODOT_BIN" --version 2>/dev/null || true)"
if ! printf '%s' "$VER" | grep -Eq '^4\.3\.'; then
	fail "需要 Godot 4.3（headless 导出）。当前: ${VER:-无法读取版本}。请安装 Godot 4.3，或设置 GODOT 指向该版本。"
fi

templates_dir() {
	case "$(uname -s)" in
		MINGW*|MSYS*|CYGWIN*)
			printf '%s\n' "${APPDATA}/Godot/export_templates/4.3.stable"
			;;
		Darwin)
			printf '%s\n' "$HOME/Library/Application Support/Godot/export_templates/4.3.stable"
			;;
		*)
			printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.3.stable"
			;;
	esac
}

TPL="$(templates_dir)"
if [[ ! -f "$TPL/windows_release_x86_64.exe" ]]; then
	fail "未找到 Godot 4.3 Windows 导出模板（$TPL/windows_release_x86_64.exe）。请安装与编辑器同版本的 Export Templates 4.3.stable。"
fi

if [[ ! -f "$PROJECT/export_presets.cfg" ]]; then
	fail "工程里没有 export_presets.cfg，或缺少名为「Windows Desktop」的预设。"
fi
if ! grep -q 'name="Windows Desktop"' "$PROJECT/export_presets.cfg"; then
	fail "export_presets.cfg 里没有「Windows Desktop」预设。"
fi

mkdir -p "$(dirname "$OUT")"
echo "导出 Windows Desktop → $OUT"
echo "Godot=$VER"
echo "模板=$TPL"
"$GODOT_BIN" --headless --path "$PROJECT" --export-release "Windows Desktop" "$OUT"
if [[ ! -f "$OUT" ]]; then
	fail "导出结束但没有生成 $OUT。"
fi
echo "完成: $OUT"
