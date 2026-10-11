# FARM-06 / FARM-07 smoke

只做一小枪，方便在 m173 上试通，再往十国扩。这次不把 GLB 写进仓库。

| 队列 | 条数 | 内容 |
| --- | --- | --- |
| `farm06_hunyuan_smoke.json` | 7 | 灰烬邦、朔影国各 2 个轮廓，哨卫和秘术士各 1 套甲，1 匹霜骑 |
| `farm07_tokens_smoke.json` | 9 | 哨卫、秘术士、游骑的 ally/enemy 棋子，外加各一张男胸像 |

7 落在 6–12。两国轮廓和「1 坐骑 + 2 套甲」两刀都在这一枪里，因为卡片要的就是轮廓、甲和坐骑。其余 8 国、以及还没有 t1 网格的职业，写在 JSON 的 `expand` 里，没有提示词。

三角面目标 **≤ 15000**。Hunyuan 的 octree 512 出的是密网格，入库前用 `rig_mesh_v87.py --tris 15000` 减面。toon 参数跟 `docs/art/style-lock-v89.json` 的 `toon_3d`：双色阶、描边 0.006m `#0A0E14`、敌方珊瑚边光 `#FF7A70`、我方霜边光 `#6ED4FF`。

## 不要和 v9.2 静帧混提交

| 批次 | 在 m173 上怎么交 | 端口 | 清单 |
| --- | --- | --- | --- |
| FARM-01…05 静帧 | `submit_v92_on_m173.ps1` | Qwen `:8322`（双机位才碰 `:8329`） | `<输出根>\shots_v92_farm.json` |
| FARM-06 转面 | `farm.ps1 submit` | Qwen `:8322` | 单独 batch，来自本队列的 sheet |
| FARM-06 网格 | `farm.ps1 submit` | Hunyuan `:8327` | `gen_hunyuan_v87.py` 写的 SaveGLB |
| FARM-07 棋子和胸像 | `farm.ps1 submit` | Qwen `:8322` | 另一个 batch，不要并进上一行的 shots |

`submit_v92_stills.py` 只读 `v92_*.json` 和 `genome_bank_v92.json`。这两个 smoke 文件不在里面。不要把提示词追加进 `shots_v92_farm.json`。

农场是 `192.168.9.244`。`farm.ps1` 绑 `192.168.20.2`，请求不走 FlClash。在 m173 上跑，本机不直连。

## 干跑（不必等农场）

在仓库根目录：

```bash
python3 tools/farm_queue/build_farm06_07.py
python3 tools/farm_queue/validate_farm06_07.py
python3 tools/farm_queue/test_farm06_07.py
```

通过时校验以 `FARM06-07 PASS` 结束。干跑不探测局域网。

## 1. Qwen 转面（网格的输入，还不是 GLB）

```powershell
python tools\farm_queue\build_farm06_07.py --emit D:\CenturyKnights_farm\farm06_sheets --only sheets
powershell -File tools\farm_v87\farm.ps1 submit D:\CenturyKnights_farm\farm06_sheets
powershell -File tools\farm_v87\farm.ps1 watch D:\CenturyKnights_farm\farm06_sheets
```

`watch` 每 60 秒拉一次，最多 6 小时。拉完把图收成下面的文件名，放进 `D:\CenturyKnights_farm\farm06_sheets\sheets\`。`gen_hunyuan_v87.py` 用文件名（不含 `hy_`）当作网格名：

| 转面文件 | Hunyuan 任务 |
| --- | --- |
| `enemy_ashbanner_line.png` | `hy_enemy_ashbanner_line` |
| `enemy_ashbanner_skirmish.png` | `hy_enemy_ashbanner_skirmish` |
| `enemy_shuoying_line.png` | `hy_enemy_shuoying_line` |
| `enemy_shuoying_skirmish.png` | `hy_enemy_shuoying_skirmish` |
| `armor_sentinel.png` | `hy_armor_sentinel` |
| `armor_mage.png` | `hy_armor_mage` |
| `mount_courser.png` | `hy_mount_courser` |

转面是左正右背、1536×1024、灰底 `#D9DEE3`。人和甲是 A-pose、空手。马没有骑手。

## 2. Hunyuan 网格（`:8327`，不是静帧）

换一个目录，避免和上面的 `:8322` 任务缠在一起。

```powershell
python tools\farm_v87\gen_hunyuan_v87.py D:\CenturyKnights_farm\farm06_sheets\sheets D:\CenturyKnights_farm\farm06_hy
powershell -File tools\farm_v87\farm.ps1 submit D:\CenturyKnights_farm\farm06_hy
powershell -File tools\farm_v87\farm.ps1 watch D:\CenturyKnights_farm\farm06_hy
```

`gen_hunyuan_v87.py` 取转面左半，抠成白底正方图，再交 GeneRanch 的 peak 图（res 8192、50 步、cfg 8、octree 512、surface net 0.6）。作业文件名是 `8327__hy_<name>.json`。

减面后再考虑入库。人形：

```text
blender -b -P tools/models/rig_mesh_v87.py -- in.glb out.glb --sheet turnaround.png --tris 15000 --weapon none --part body
```

共享动作名：`idle` `advance` `attack` `skill` `hit` `dodge` `crit` `death`。`rig_mesh_v87.py` 会把人形高度收到 1.78m。坐骑只保证三角面 ≤ 15000，不要把这个人身高当成马的最终尺寸。

入库路径写在队列的 `glb_path`：`project/assets/models/units/` 和 `project/assets/models/mounts/mount_courser.glb`。本 PR 不提交这些 GLB。

## 3. FARM-07 棋子和胸像（仍是 Qwen 静帧）

```powershell
python tools\farm_queue\build_farm06_07.py --emit D:\CenturyKnights_farm\farm07_tokens --only tokens
powershell -File tools\farm_v87\farm.ps1 submit D:\CenturyKnights_farm\farm07_tokens
powershell -File tools\farm_v87\farm.ps1 watch D:\CenturyKnights_farm\farm07_tokens
```

棋子按 `out_path` 放进 `project/assets/art/tokens/v8_job_<职业>_<ally|enemy>.png`，胸像放进 `project/assets/art/portraits/v8_bust_m_<职业>.png`。

然后跑可读性后处理：

```bash
python3 tools/fx/token_readability_v85.py
```

脚本只认 `v8_job_*_*.png`。它把原图备份到 `tokens/_src_v82/`，再把暗色人形抠到平静的墨色到阵营色径向场上，描一圈阵营边光，放大 1.22。`light_inf` 和 `apprentice` 才走亮色分支；这次三个新职业走默认暗色分支，所以提示词要求居中的暗色人形，不要亮色水晶旋涡。胸像不进这个脚本。胸像机位是风格锁的 `bust_hero`：四分之三侧、面向画面左侧、胸像以上、平视，512×640。

这一步会重写目录里全部旧棋子。备份已在时，旧图从备份重做。

## 扩到全量

复制一条 smoke 作业，改 id、描述和路径。改完跑 `build_farm06_07.py` 不用手改提示词前缀：前缀、负面词和 toon 都从 `style-lock-v89.json` 抄。现在的校验要求恰好 2 国、每国 line/skirmish、2 套甲、1 匹坐骑。扩成十国时要一起改 `validate_farm06_07.py` 里的 smoke 上限。
