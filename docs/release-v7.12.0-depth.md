# v7.12.0-depth · 系统深度第十三轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调升密。

| 交付 | 说明 |
|------|------|
| **雇佣个体脸** | 150 张 `hireface_{hair}_{eyes}_{g}_{scar}` — 发型变体/痣疤/胸章各异，先于角色板 |
| **铬件贴图** | `panel/btn/btn_accent/hub_nav_chrome` 以 `StyleBoxTexture` 接入（非仅 Flat） |
| **战棋 FX** | slash/crit/heal/lock/spark/shield/unlock 6 帧重绘加密度 |
| **雇佣棋子** | `hire_{role}_{team}_f0–3` token |
| **谱系/联姻饰带** | banner 加密度 |

## 战棋

- **终局锁定演练**：`ch6_redoubt`（托孤堡垒）`lock_drill`
- **敌 AI**：侧击 +4.8；击杀确认 +18；锁住占垒/林丘权重再升

## 城堡 / 谱系

- 枢纽铬件贴图化；谱系/联姻饰带加权

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.12.0-depth.zip`
- SHA256：`ed7d2c599a63ea2649cb8baca700b1f3b3ca20ea3042f881500395fb729408ac`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
