#!/usr/bin/env bash
# Debug APK for the Godot 4.3 "Android" preset.
# Exits 2 with a short message when the Android SDK, JDK, Godot, or the
# Gradle build template is missing. Does not print keystore passwords.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/project"
OUT="$ROOT/exports/android/CenturyKnights-debug.apk"

fail() {
	echo "ERROR: $*" >&2
	exit 2
}

if [[ -f "$PROJECT/android/signing.local.env" ]]; then
	set -a
	# shellcheck disable=SC1091
	source "$PROJECT/android/signing.local.env"
	set +a
fi

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$SDK" && -n "${LOCALAPPDATA:-}" && -d "$LOCALAPPDATA/Android/Sdk" ]]; then
	SDK="$LOCALAPPDATA/Android/Sdk"
elif [[ -z "$SDK" && -d "$HOME/Android/Sdk" ]]; then
	SDK="$HOME/Android/Sdk"
fi
if [[ -z "$SDK" || ! -d "$SDK/platform-tools" ]]; then
	fail "未找到 Android SDK（需要 platform-tools）。请安装 SDK 并设置 ANDROID_SDK_ROOT 或 ANDROID_HOME。Linux 常见路径 ~/Android/Sdk，Windows 常见路径 %LOCALAPPDATA%\\Android\\Sdk。"
fi

if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
	if command -v java >/dev/null 2>&1; then
		JAVA_BIN="$(command -v java)"
		# /usr/lib/jvm/java-17-openjdk/bin/java -> JAVA_HOME two levels up when it is a real JDK layout
		maybe="$(cd "$(dirname "$JAVA_BIN")/.." && pwd)"
		if [[ -x "$maybe/bin/java" ]]; then
			JAVA_HOME="$maybe"
		fi
	fi
fi
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
	fail "未找到 JDK。Godot 4.3 的 Android Gradle 导出需要 JDK 17，并设置 JAVA_HOME 指向 JDK 根目录（内含 bin/java）。"
fi
if ! "${JAVA_HOME}/bin/java" -version 2>&1 | grep -Eq 'version "17\.'; then
	echo "WARNING: Godot 4.3 Android 导出针对 JDK 17。当前 JAVA_HOME=$JAVA_HOME" >&2
fi

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

if [[ ! -f "$PROJECT/android/build.gradle" ]]; then
	fail "工程里没有 Android Gradle 构建模板（project/android/build.gradle）。在 Godot 4.3 编辑器中打开工程，菜单「项目 → 安装 Android 构建模板」。模板与导出模板版本必须同为 4.3。不要把密钥库提交进仓库。"
fi

editor_settings_path() {
	case "$(uname -s)" in
		MINGW*|MSYS*|CYGWIN*)
			printf '%s\n' "${APPDATA}/Godot/editor_settings-4.3.tres"
			;;
		Darwin)
			printf '%s\n' "$HOME/Library/Application Support/Godot/editor_settings-4.3.tres"
			;;
		*)
			printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-4.3.tres"
			;;
	esac
}

CFG="$(editor_settings_path)"
mkdir -p "$(dirname "$CFG")"
python3 - "$CFG" "$SDK" "$JAVA_HOME" <<'PY'
import sys
path, sdk, java = sys.argv[1:]
sdk = sdk.replace("\\", "/")
java = java.replace("\\", "/")
updates = {
    "export/android/android_sdk_path": sdk,
    "export/android/java_sdk_path": java,
}
def quote(v: str) -> str:
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
if not __import__("os").path.exists(path):
    lines = ["[gd_resource type=\"EditorSettings\" format=3]", "", "[resource]"]
    for k, v in updates.items():
        lines.append(f"{k} = {quote(v)}")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    sys.exit(0)
raw = open(path, "rb").read()
if raw.startswith(b"RSCC") or b"\0" in raw[:200]:
    sys.stderr.write("editor settings 不是文本格式，请在编辑器里手动填写 Export → Android 的 SDK 与 Java 路径。\n")
    sys.exit(2)
text = raw.decode("utf-8")
if "[resource]" not in text:
    sys.stderr.write("无法识别 editor settings，请在编辑器里设置 export/android/android_sdk_path。\n")
    sys.exit(2)
lines = text.splitlines()
seen = set()
out = []
for line in lines:
    stripped = line.strip()
    replaced = False
    for key, val in updates.items():
        if stripped.startswith(key + " ") or stripped.startswith(key + "="):
            out.append(f"{key} = {quote(val)}")
            seen.add(key)
            replaced = True
            break
    if not replaced:
        out.append(line)
if len(seen) < len(updates):
    # append missing keys at the end of the resource section
    out.append("")
    for key, val in updates.items():
        if key not in seen:
            out.append(f"{key} = {quote(val)}")
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
PY

mkdir -p "$(dirname "$OUT")"
if [[ -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
	echo "未设置 GODOT_ANDROID_KEYSTORE_DEBUG_PATH。将使用编辑器已生成的 debug keystore；若导出提示未配置密钥，请先在编辑器打开一次 Android 导出，或填写 project/android/signing.local.env。"
fi
echo "导出 Android 调试 APK → $OUT"
echo "SDK=$SDK"
echo "JAVA_HOME=$JAVA_HOME"
# shellcheck disable=SC2086
"$GODOT_BIN" --headless --path "$PROJECT" --export-debug "Android" "$OUT"
echo "完成: $OUT"
