# v7.6.0-depth · 系统深度第七轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 概念板级手调升密。

| 交付 | 说明 |
|------|------|
| **概念板城堡底图** | `castle/hub/menu/battle_backdrop` — 光柱、雾、石墙、旗饰、火把 |
| **禀性插画 vignette** | 剑/眼/盾/书/花/月/星等 64px 图腾（非纯宝石） |
| **花名册 / 酒馆** | 禀性 TextureRect 芯片条 |
| **主菜单 + 战棋 chrome** | 使用插画底图 |
| **巡防沙盘** | `patrol_vignette` + 属地光标 |

## 战棋

- 敌军 `grant_battle_enemy_skills`：一阶 + 启发式二阶（精锐/头目再摸三阶）
- AI 增益池扩至 iron_wall / ember_seal / mark_death 等
- 锁定 UX 与进攻技逻辑沿用并吃到更高阶技能

## 属地

- **单属地「巡此路线」** + 全堡巡防
- 成功弹出 **巡防沙盘 vignette**
- 按属地 `patrol_boost` / `patrol_cd` 抗劫

## 谱系

- 左侧 **永久权重** 图标条（团长/联姻/子嗣/血胤月泽）

## 不做
- 无新剧情卷

## CI / 构建
- Tag：`v7.6.0-depth`

## 构建
- `CenturyKnights-windows-v7.6.0-depth.zip`
- SHA256：`b32f354e27cc358642d9f349c9ab26ec48d4629c7eb296937c352c8baf0db1c2`
