# 端游截图门禁（desktop-gate）v1

手游门禁的桌面版：鼠标输入、不走 `CK_FORCE_MOBILE` 重排，按 PC 分辨率截主要页面并做排版检查。

## 本地命令

```bash
# 全量（约 1–2 分钟）
bash scripts/desktop_gate.sh /tmp/ck_desktop

# 只跑若干页
DESKTOP_ONLY=title,castle,battle bash scripts/desktop_gate.sh /tmp/ck_desktop

# 写入/下调基线（问题数只许下降）
DESKTOP_GATE_ARGS=--write-baseline bash scripts/desktop_gate.sh /tmp/ck_desktop
```

输出：PNG、`layout.json`、`gate_fails.txt`、拼图 `sheets/desktop_sheet_<分辨率>.png`。

## CI

接入 `scripts/capture_screens.sh`（与 `mobile_gate.sh` 同级）。`shots` job 本来就会跑该脚本，因此**不必改** `.github/workflows/ci.yml` 也会执行桌面门禁。

> 权限说明：本机 OAuth token 没有 `workflow` scope，无法直接改 `.github/workflows/ci.yml`。拼图目录 `/tmp/ck_shots/desktop_sheets/` 若要上传为 artifact，需有人用带 `workflow` 权限的账号把 artifact `path` 补上 `desktop_sheets/**`（可与已有 `mobile_sheets` 一并加）。门禁本身的通过/失败已由 `capture_screens.sh` 的退出码决定。

## 检查项

控件出屏、文字重叠（按墨迹盒）、文字截断、按钮错位、字号 &lt; 12、点击区域过小、占位美术。基线：`tools/ci/desktop_baseline.json`，只能下调。

## 覆盖页面

标题、建团、城堡主页、全景、四个附属建筑、工事、花名册、酒馆、联姻、族谱、舆图（含侧栏）、城镇及各页签、设置、对话、战斗、读档。分辨率：1280×720、1920×1080、2560×1440。
