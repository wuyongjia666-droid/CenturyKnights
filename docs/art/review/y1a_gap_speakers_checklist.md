# Y1-A gap speakers checklist（9 人）

来源：#335 端游↔手游立绘对账 — 9 个说话人在两端都无板，不是手游裁切问题。

## 名单

| cast_key | 姓名 | 表 | 出图目标 |
|---|---|---|---|
| xinyu | 藤桥·新雨 | supporting_v92 | `portraits/speakers/xinyu.webp` (+ medium/small) |
| ahe | 渡口·阿禾 | supporting_v92 | `portraits/speakers/ahe.webp` |
| hutie | 镜湖·护帖 | supporting_v92 | `portraits/speakers/hutie.webp` |
| shouhuo | 冷窑·收火 | supporting_v92 | `portraits/speakers/shouhuo.webp` |
| zhexian | 冷湾·折弦 | antagonists_v92 | `portraits/speakers/zhexian.webp` |
| lanzhi | 碧潭·澜芷 | antagonists_v92 | `portraits/speakers/lanzhi.webp` |
| jixun | 白垣·计勋 | antagonists_v92 | `portraits/speakers/jixun.webp` |
| qianzhan | 南灯·欠盏 | antagonists_v92 | `portraits/speakers/qianzhan.webp` |
| guheng | 观象·孤衡 | antagonists_v92 | `portraits/speakers/guheng.webp` |

## 农场步骤（m173，Qwen :8322）

1. 仓库已含 `tools/farm_queue/v92_y1a_gap_speakers.json`（`make_y1a_gap_speakers.py`）。
2. 提交：`powershell -File tools\farm_queue\submit_y1a_gap_speakers_on_m173.ps1`
3. 轮询：`python tools\farm_queue\submit_v92_stills.py --poll`
4. 入库：`python tools\farm_queue\ingest_story_speakers.py --inbox <farm_root>\out`
5. 档位：`python tools\art\build_portrait_tiers.py`（speakers stem）
6. 本接线 PR **不**提交假图；出图后另开 ingest PR。

## 代码接线

- `UnitArt.speaker_plate_path` 读 supporting + **antagonists**。
- Android `exclude_filter` 已预挂 9 个 `speakers/<stem>.webp` large，只留 medium/small。
- 路由测试：`y1a_gap_speaker_route_check`（有 path、不要求纹理已存在）。
