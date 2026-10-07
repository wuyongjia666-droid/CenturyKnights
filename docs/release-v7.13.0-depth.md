# v7.13.0-depth · 系统深度第十四轮（仍停加卷）

## 美术（置顶 · 一等公民）

m173/Qwen `:8322` 仍不可达 → 手调升密。

| 交付 | 说明 |
|------|------|
| **眉型入键** | `hireface_{hair}_{eyes}_{g}_{scar}_{brow}` 共 600 张 |
| **id 去双胞胎** | `hireuniq_00–63` + `_fingerprint_portrait`（色偏/痣点按 id） |
| **敌军棋子** | `hire_*_enemy` / bandit 等升至 72²，对齐友军雇佣密度 |
| **谱系枢纽** | 敌宅/嗣争加 `hub_banner_strip` |

## 战棋

- **锁定脱离**：锁定 leave_cost=3；控带内 leave_cost=2
- **锁定时长**：交战刷新至 3 回合
- **敌 AI**：续咬锁定邻格；侧击/击杀权重保持高压；进攻蓄力 0.80

## 城堡 / 谱系

- 敌宅交涉、嗣位之争饰带加权

## 不做
- 无新剧情卷

## 下载
- `CenturyKnights-windows-v7.13.0-depth.zip`
- SHA256：`4efaf2031e335c6e2fb8d10d4cf099ff9678c184c12ab050909b23ce2bd77de1`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
