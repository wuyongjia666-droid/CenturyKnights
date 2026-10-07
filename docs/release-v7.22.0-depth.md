# v7.22.0-depth · 系统深度第二十三轮（仍停加卷 · 无农场出图）

## 美术 / UI / 动画（置顶 · skills + Active Theory）

| 交付 | 说明 |
|------|------|
| **页面动效** | `UIFX.page_enter` / `wire_button` / `wire_tree` / `nav` 微交互；大厅导航错落+按压；酒馆/花名册/演武/工坊/祠堂/出征/委任/族谱/沙漏/联姻/属地入场 |
| **战棋手感** | Trauma 二次曲线震动（非乱抖）；slash 叠 `hit_spark`；飘字叠 `dmg_pop` |
| **interim 升密** | hit_spark / dmg_pop 帧；hub_nav_hover；transition_rule；横幅金尘 |
| **农场** | **仍 BLOCKED**（31.x↔9.x）。`farm_inbox` + `ingest_farm_inbox.py` 就绪，通网后落盘即替换 |

## 城堡 / 贸易中长环
- 商队 **雇护运（12 银）** → 遇劫大降
- 戍卫属地在安静期每 3 月微加银

## 不做
- 无新剧情卷 · **不重探农场**

## 下载
- `CenturyKnights-windows-v7.22.0-depth.zip`
- SHA256：`08880ae322c4526fd26846685aa969b2e22670a8ed2f1255387151a9f5ef5257`

## CI
- `./scripts/run_ci.sh` → **ALL PASS**
