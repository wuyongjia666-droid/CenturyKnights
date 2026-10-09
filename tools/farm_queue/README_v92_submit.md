# v9.2 静帧一次性投农场（FARM-01…05）

在 **m173** 上执行。本机不直连 `192.168.9.244`。这一枪把已经写好的静帧队列全部交给本机双机位，让 Qwen `:8322` 和 SenseNova 本地 `:8329` 同时有活。

覆盖：

| 卡 | 队列 | 内容 |
| --- | --- | --- |
| FARM-01 | `genome_bank_v92.json` | 基因桶，五年龄，≤6000 |
| FARM-02 | `v92_cities.json` | 城市图 |
| FARM-03 | `v92_smiths.json` + `v92_items.json` | 铁匠铺 + 物品图标 |
| FARM-04 | `v92_scenes.json` + `v92_expressions.json` | 场景 + 同伴表情 |
| FARM-05 | `v92_castle.json` + `v92_estates.json` | 城堡分层 + 庄园 |

FARM-06（Hunyuan）和 FARM-07（职业棋子）不在这一枪里，见 `FARM-06-07.md`。

风格锁和反套路词不在提交脚本里改写。提示词、负面词、种子、28 步、cfg 1.0、euler/simple、尺寸都从队列原样抄进 `dual_submit_stills` 的 shot。

## 1. 干跑（不必等农场）

在仓库根目录：

```bash
python3 tools/farm_queue/validate_queue_v92.py
python3 tools/farm_queue/submit_v92_stills.py --dry-run
```

通过时分别以 `QUEUE PASS` 和 `DRY-RUN PASS` 结束。干跑不探测局域网，也不调用 `dual_submit_stills.py`。CI 的 `farm-queue` 作业跑这两条，再加上 `python3 tools/farm_queue/test_submit_v92.py`。

队列和世界数据或 `docs/art/style-lock-v89.json` 不一致时，先重建再校验（会重写 `v92_*.json`，不动 `genome_bank_v92.json`）：

```bash
python3 tools/farm_queue/build_v92_queues.py
python3 tools/farm_queue/validate_queue_v92.py
```

## 2. 在 m173 上探端口

两台都要通。只通 Qwen 时默认不提交。

```powershell
Invoke-WebRequest http://192.168.9.244:8322/system_stats -TimeoutSec 5 -UseBasicParsing
Invoke-WebRequest http://192.168.9.244:8329/system_stats -TimeoutSec 5 -UseBasicParsing
```

仓库里的 `tools/farm_queue/probe_farm.sh` 是同一组 URL，给能访问该网段的环境用。

## 3. 一次性提交

```powershell
powershell -File tools\farm_queue\submit_v92_on_m173.ps1
```

等价于：两台都在线时执行

```text
dual_submit_stills.py --root <输出根> --shots-json <输出根>\shots_v92_farm.json --spread --sn-backend local --only both
```

脚本搜索顺序：

- `D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts`
- `C:\Users\m1736\.cursor\skills\aic-farm\scripts`
- 环境变量 `AIC_FARM_SCRIPTS`

`--sn-backend` 固定为 `local`。不会走 SenseNova 云、API 节点或 Flux。

## 4. 输出根

优先 `D:\AIComics\CenturyKnights_farm`，目录不存在时用 `D:\CenturyKnights_farm`。也可以设 `CK_FARM_ROOT`。

提交前会把 shots JSON 写到 `<输出根>\shots_v92_farm.json`。这个文件是 **JSON 数组**，给 `dual_submit_stills.load_shots` 直接读。每条有 `label`（加载器认这个字段），`id` 是同一个字符串。不要再包一层 `{"shots": [...]}`。

每条 shot 的 `out_path` 仍是仓库里的目标相对路径（`project/assets/art/...`）。农场落盘在输出根下，按 `label` / `filename_prefix` 取名；入库是下一步，本脚本不把 PNG 写回仓库。

## 5. 怎么看进度

脚本提交后就返回，不循环轮询。要看队列深度时再跑：

```powershell
python tools\farm_queue\submit_v92_stills.py --poll
```

或直接看 Comfy 队列：

```powershell
Invoke-WebRequest http://192.168.9.244:8322/queue -UseBasicParsing
Invoke-WebRequest http://192.168.9.244:8329/queue -UseBasicParsing
```

`--spread` 把同一份清单分到两台机器上，避免一台空转。

## 6. 只投 Qwen 的逃生口

默认：SenseNova `:8329` 不通就退出（码 3），不悄悄单边提交。Qwen `:8322` 不通则退出（码 2），没有「只投 SenseNova」。

只有确认要让 Qwen 单独吃完整批时：

```powershell
$env:CK_FARM_ALLOW_QWEN_ONLY = "1"
powershell -File tools\farm_queue\submit_v92_on_m173.ps1
```

两台都在线时，这个变量不会把 SenseNova 关掉，仍然是 `--only both`。没有命令行 `--only` 开关。

## 表情局部重绘

FARM-04 里非平静表情带 `edit=local` 和 `identity_ref`（指向该槽的平静图），种子与平静图相同，正面词里有 local redraw 子句。一次性入队会把它们和其余静帧一起提交。`dual_submit_stills.py` 若只读 `prompt` / `seed`，这些张会按同种子整张生成，而不是等平静图落地后再做图像局部重绘。
