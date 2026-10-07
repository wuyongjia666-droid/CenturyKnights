# v7.5.0-depth · 系统深度第六轮（仍停加卷）

## 美术（本轮置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调 PIL 升密。

| 交付 | 说明 |
|------|------|
| **插画城堡底图** | `castle_backdrop.png` / `hub_backdrop.png` — 城堡枢纽、属地、族谱、联姻不再纯色面板 |
| **禀性 TextureRect 图标** | 12+ 禀性 `trait_*.png`，族谱详情左侧图标条（悬停中文名） |
| 地块加光 | plain/forest/hill/water/bridge/fort 顶光与边缘再密 |
| UX 图 | 巡防图标、交战锁定提示条 |
| UIKit | `make_screen_bg(..., illustrated)` + `trait_icon_rect()` |

## 战棋

- 敌军也授予 job 一阶战技并重置次数
- **敌方 AI 自动放技**：残血拆锁/抽身、林垒占地利、近战增益、友军治疗；进攻时约 55% 蓄力破旗斩等
- 开场 **交战锁定 UX 提示条**（可关 / 8 秒淡出）
- 进攻技判定对敌方同样生效

## 属地

- **主动「巡防四野」**：银+粮，2 月抗劫强化 + 安静月进度；冷却 2 月
- 面板显示巡防中 / 冷却 / 安静月数

## 谱系 / 城堡

- 族谱禀性图标可视化；城堡插画底
- 永久影响文案保留 + 血胤月泽

## 不做
- 无新剧情卷

## CI / 构建
- `./scripts/run_ci.sh` 全绿 → Tag `v7.5.0-depth`

## 构建
- `CenturyKnights-windows-v7.5.0-depth.zip`
- SHA256：`efa008b06e301dde8f118423e82ea674feab4d0d63d3ccc34755ee15042bcff9`
