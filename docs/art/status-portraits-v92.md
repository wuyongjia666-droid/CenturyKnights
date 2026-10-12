# 状态立绘 v9.2

营养不良、负伤和类似状态要能在脸上读出来，深度对齐公开资料里「看着就知道这人挨过饿、挂过彩」的那种信息量。外观是本作自己的：霜青亚麻、石板布、珊瑚细线，不借用别的游戏的伤口图标、王冠、金边或羊皮纸。

农场这一侧现在打不开。这一卡只定做法、队列和缺图行为，不放占位图。

## 做法

不给每张脸重画一套状态。身份板保持原样，状态是对齐 768×1024 半身板的透明叠层。一个人可以同时营养不良又跛足，所以叠层可以叠，而不是互斥的整张重绘。

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

入库路径就是队列里的 `out_path`：`project/assets/art/portraits/status/<id>.png`。底是全透明，只有状态颜料。不要交一整张新人脸。

## 接线

- 名册板：`UIKit.portrait_plate`
- 战棋单位卡：`unit_card.gd`
- 战斗情报：`battle_info_panel.gd`

三处都调用 `CKPortraitStatus.attach`。底图仍走 `UnitArt.portrait`。列表和棋子取 small，对话和半身取 medium，档案详情取 large。叠层按控件尺寸盖上去，不另做一套缩小的状态图。

## m173

农场恢复后，在 m173 上走现有静帧提交（`tools/farm_queue/submit_v92_on_m173.ps1`）。这六条已经在 `v92_*.json` 里，校验脚本会一起看。先出叠层，不要改身份板的种子。验收看 alpha：脸和衣服以外的像素应接近全透明，叠到任意半身板上五官还是那个人。
