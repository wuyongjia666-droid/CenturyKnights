# v7.18.0-depth · 系统深度第十九轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调升密。

| 交付 | 说明 |
|------|------|
| **清包** | 删除全部 `%02d` hireuniq 重复（仅保留 `%03d`） |
| **512 槽** | hireuniq_000–511；FNV 映射 id+名+等位，王朝碰撞再降 |
| **ZoC 脉冲** | hatch 对比加强；悬停/选中格边线加粗+透明度脉冲 |

## 战棋

- ZoC 电报：hover 脉冲 + overlay 即时重绘
- 敌 AI：控带压残血额外 +1.5

## 城堡 / 谱系

- 演武场 / 市集加 `hub_banner_strip`

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.18.0-depth.zip`
- SHA256：`f6c47766fd6456229367c37202f140d1619d160f3141791ee82feaa2217d5429`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
