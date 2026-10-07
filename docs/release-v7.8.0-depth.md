# v7.8.0-depth · 系统深度第九轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调升密。

| 交付 | 说明 |
|------|------|
| **市集/祠堂/委任/演武底图** | `market/shrine/quests/train_backdrop` + 族谱 `lineage_backdrop` |
| **角色立绘图集升密** | 6发色×5瞳色×2性别×5兵种 = 300 张重绘光影脸 |
| **巡防沙盘** | 8 帧路线行进 + 旗标拖尾 |
| **锁定教学条** | `lock_tip_step0–2` 三拍专用底板 |

## 战棋

- **设计师 per-map 战技表** `data/enemy_skill_tables.json`（by_template / default / elite）
  - 覆盖 ch0–ch6 关键图与委任匪图；未登录图回退 `_defaults` 难度档
- **交战锁定教学三拍**（ch0）：咬住 → 脱离代价 → 锁反/拆锁；首次锁定触发教学拍日志
- 敌军生成写入 `template` 供表查询

## 城堡 / 谱系

- 市集、祠堂、委任榜、演武场、族谱主题插画底

## 不做
- 无新剧情卷

## CI / 构建
- Tag：`v7.8.0-depth`

## 构建
- `CenturyKnights-windows-v7.8.0-depth.zip`
- SHA256：`5fa6b40635b35e07cacbca79f9c3a99bd98c44665715abfc5c7b508cd87a63b2`
