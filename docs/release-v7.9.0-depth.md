# v7.9.0-depth · 系统深度第十轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调升密。

| 交付 | 说明 |
|------|------|
| **敌宅 / 嗣争 / 继承 / 沙漏 / 授旗底图** | `rival` / `heir` / `inheritance` / `hourglass` / `rite_backdrop` 各带独特角饰与色带 |
| **具名角色板绘** | `leader` / `tank` / `ranger` / `mage` / `skirm_plate` 手调光影与胸章标识 |
| **巡防连续感** | 12 帧 `patrol_vignette_f0–11` + 0.12s 缓动切换 |

## 战棋

- **全图战技表**：`enemy_skill_tables.json` v2 — 400 地图条目 + 68 模板 `_by_template` + `diff_0..4` 默认；`grant_battle_enemy_skills` 支持 Array/dict by_template 与全局回退
- **强制锁定练习**（ch0 教学图）：未触发交战锁定不可结束回合；横幅指引；触发后「练习完成」并可结束回合

## 城堡 / 谱系

- 敌宅交涉、嗣位之争、继承、沙漏、授旗礼接入主题插画底（`UIKit.make_themed_bg`）

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.9.0-depth.zip`
- SHA256：`ff4317da63f7f7c9fc68ef158fbcf063a5a35aab081db95043d19ba224987366`

## CI
- `./scripts/run_ci.sh` → smoke + layout + tactics_e2e + full_chain_e2e **ALL PASS**
