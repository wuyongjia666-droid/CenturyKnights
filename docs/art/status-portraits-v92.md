# 状态立绘 v9.2

营养不良、负伤和类似状态要能在脸上读出来，深度对齐公开资料里「看着就知道这人挨过饿、挂过彩」的那种信息量。外观是本作自己的：霜青亚麻、石板布、珊瑚细线，不借用别的游戏的伤口图标、王冠、金边或羊皮纸。

## 做法

**不给每张脸重画一套状态。** 身份板（基因库 / 表情 / 职业胸像）保持原样；状态是对齐 768×1024 半身板的透明叠层。一个人可以同时营养不良又跛足，所以叠层可以叠，而不是互斥的整张重绘。

因此全集是 **6 张共享叠层**，不是「状态 × 年龄 × 性别 × 血脉」矩阵。年龄 / 性别 / 血脉已经写在底图上；叠层只画状态颜料。

运行时 `CKPortraitStatus.attach` 按当前状态往立绘容器上加 `TextureRect`。文件不在就不画，底图不动。队列在 `tools/farm_queue/v92_status_overlays.json`，六张，归 FARM-04，和表情差分同一条静帧提交。

| id | 游戏里从哪来 | 只画什么 |
|---|---|---|
| `malnourished` | 特质 `malnourished` | 颊窝、眼下冷灰、皮肤发干、领口布料松一圈 |
| `wound_light` | 伤势 `light`，或只有旧的 `injured` 旗标 | 眉上一小条霜色亚麻，一道浅珊瑚线 |
| `wound_lasting` | 伤势 `lasting` 且不是下面两种具名伤 | 前臂石板布裹带，一枚霜银别针 |
| `wound_grave` | 伤势 `grave` | 一条手臂用石板布吊着，那只手臂更冷更淡 |
| `lost_finger` | `lasting` / `lost_finger` | 一只手上的窄裹带，一指收在布下 |
| `limp` | `lasting` / `limp` | 一侧膝盖的石板布，站姿略不平 |

具名伤优先于通用 `wound_lasting`。没有伤势记录、只有 `injured` 时用轻伤叠层。

入库路径就是队列里的 `out_path`：`project/assets/art/portraits/status/<id>.png`（并写同名无损 WebP）。底是全透明，只有状态颜料。不要交一整张新人脸。`build_portrait_tiers.py` 会跳过 `status/`，不另做 small/medium。

## 接线

- 名册板：`UIKit.portrait_plate`
- 战棋单位卡：`unit_card.gd`
- 战斗情报：`battle_info_panel.gd`

三处都调用 `CKPortraitStatus.attach`。底图仍走 `UnitArt.portrait`。列表和棋子取 small，对话和半身取 medium，档案详情取 large。叠层按控件尺寸盖上去，不另做一套缩小的状态图。

## m173 提交（Qwen `:8322`）

在 **m173** 上跑（本机不直连 `192.168.9.244`）。默认只投 Qwen。

```powershell
# 推荐：整卡 FARM-04（场景 50 + 表情 60 + 状态 6 = 116），农场不会在 6 张后空转
powershell -File tools\farm_queue\submit_status_overlays_on_m173.ps1

# 只要六张状态叠层
powershell -File tools\farm_queue\submit_status_overlays_on_m173.ps1 -OnlyStatus

# 干跑（不探局域网）
powershell -File tools\farm_queue\submit_status_overlays_on_m173.ps1 -DryRun -OnlyStatus
```

等价 Python：

```powershell
python tools\farm_queue\submit_v92_stills.py --farms FARM-04 --kinds status_overlay --root D:\AIComics\CenturyKnights_farm
python tools\farm_queue\submit_v92_stills.py --poll
```

## 门禁与入库

```powershell
# 先干跑门禁
python tools\farm_queue\ingest_status_overlays.py --inbox D:\AIComics\CenturyKnights_farm\out --dry-run

# PASS 才写入仓库（PNG + 无损 WebP + .import）
python tools\farm_queue\ingest_status_overlays.py --inbox D:\AIComics\CenturyKnights_farm\out
```

验收：

- 尺寸 768×1024 RGBA
- `opaque_ratio`（α>0.5）落在作业 `gate.min_opaque_ratio`…`max_opaque_ratio`（默认约 0.8%–40%）
- 不透明像素上的金/羊皮纸/暖色/饱和度/冷偏置不松于风格锁
- 叠到任意半身板上，五官仍是那个人；脸和衣服以外接近全透明

报告写到 `docs/art/review/status_overlays_v92.json`。被拒的进 inbox 下 `_status_overlay_review/`。

## 本机校验（不必等农场）

```bash
python3 tools/farm_queue/validate_queue_v92.py
python3 tools/farm_queue/submit_v92_stills.py --dry-run --farms FARM-04 --kinds status_overlay
python3 tools/farm_queue/test_ingest_status_overlays.py
python3 tools/farm_queue/test_submit_v92.py
```

## 出图备注（2026-10-12）

Qwen 纯 T2I 容易把「透明叠层」画成整脸立绘。`malnourished` 用 void 底板做 I2I（`gen_qwen_image_stills.py --ref void_overlay_plate.png`）后再 flood-fill 抠底，才过 alpha 门禁。其余五条在收紧「禁止画人」提示词后的 T2I 轮次过门禁。入库路径仍是 `portraits/status/<id>.png` + 无损 WebP。
