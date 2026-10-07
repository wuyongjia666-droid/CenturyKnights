# v7.7.0-depth · 系统深度第八轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调升密。

| 交付 | 说明 |
|------|------|
| **兵种板绘/棋子** | leader/tank/ranger/mage/skirm 肖像与四帧棋子加盔甲/武器/描边 |
| **部署/工事/锻造底图** | `deploy/works/forge_backdrop` 主题色氛围 |
| **战棋信息卡禀性芯片** | 选中单位旁 TextureRect 禀性条 |
| **巡防沙盘动画** | `patrol_vignette_f0–3` 路线行进四帧 |
| 锁定 FX | lock 帧加厚 |

## 战棋

- **敌军战技难度曲线**（非随机池）：`battle_difficulty_from_map` → diff0–4
  - 教学仅一阶；前中精锐二阶；中期全员二阶；后期/头目递进三阶
  - 同职同难度稳定选取（hash 盐微扰）
- 开战日志显示「敌军战技档」

## 城堡 / 属地

- 巡防沙盘播行进动画
- 部署/工事/锻造插画底

## 不做
- 无新剧情卷

## CI / 构建
- Tag：`v7.7.0-depth`

## 构建
- `CenturyKnights-windows-v7.7.0-depth.zip`
- SHA256：`7e76c9090fe8a8fcc4dddfd261f37ba1ae9f3b0334897b3dcc3dea7a52ebefdf`
