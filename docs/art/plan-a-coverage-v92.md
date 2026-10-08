# Plan A 发货覆盖（v9.2）

负责人已定：正式美术是**每个角色一张完整的 Qwen 基因种子立绘**，不是纸娃娃拼脸，也不是运行时把五官图层贴上去。每个人要有五个年龄段：婴儿、少年、青年、中年、老年。下面三种方案都在这个前提下比较。不能把纸娃娃拼脸退回来当正式方案。

## 三种方案

### A. 分桶库 + 最近邻（采用）

把「血胤线 × 性别 × 年龄阶段 × 发色 × 瞳色 × 面型簇 × 显征集合」收成桶键。每一桶是一张完整半身像：风格锁前缀、血胤子句、该年龄段的体态和衣着，都写进同一条正面提示词，由农场一次出完。运行时出生的子嗣按 `identity_overlap` 找到最近的桶，直接显示那张完整图。

桶数上限 6,000。解析顺序是：`unit_id` 专属图（当前年龄段，否则最近已渲染的年龄段，否则旧文件）→ 最近桶 → 现有回退链（具名立绘、hireuniq、胸像、程序脸）。桶目录里没有 PNG 时，第二步不命中，回退链与改动前一致。

### B. 只覆盖预制角色（不采用）

预制角色可以各有一张完整立绘和五个年龄段，符合「不是拼脸」。玩家存档里当场出生的子嗣在发行版里没有离线农场图，`CKGenomePortrait.texture()` 只能掉进旧回退。招牌功能发不出货，所以不采用。

### C. 分桶库 + 运行时贴花（不采用）

底图可以是完整立绘，但伤疤、冠饰、显征若在运行时再贴一层，正式画面又回到纸娃娃。负责人已排除这条路。伤疤不进桶；要画上某人的伤疤，走 `unit_id` 专属图，而不是运行时贴层。

## 桶里有什么

队列文件：`tools/farm_queue/genome_bank_v92.json`。

成品路径（农场写入，本卡不放 PNG）：`project/assets/art/portraits/genome/bank/<bucket_key>.png`。

每一项都带：

- `positive`：`style-lock-v89.json` 的 `qwen.prefix` 开头，再加友军/敌军点缀、半身构图、基因组描述、血胤子句
- `negative`：风格锁的 `qwen.negative`
- `seed`：身份种子加该年龄段的固定偏移（与 `CKGenomePortrait.seed_for` 相同）
- `steps` 28、`cfg` 1.0、`sampler` euler、`scheduler` simple
- 尺寸 768×1024

覆盖样本是 `CKCampaignSim` 的 20 个种子 `1101`–`1120`，每年 100 年，收集全部 `parent_ids` 非空的出生者。同一种身份（基因组身份令牌 + 主血胤 + 青年显征）只保留一条五阶段系列。提示词在生成时清掉伤疤，避免把后天伤痕烤进基因桶。

最近邻先找同一年龄段、同一身份令牌的桶，并优先同一血胤；没有全同身份时，在该年龄段里取 `identity_overlap` 最高的桶，并列时取桶键字典序较小者。重叠 ≥ 0.80 算命中。

`KINSHIP PASS mean=0.839 silver_skip=0.156` 依赖的可遗传令牌没有改。正面文案里的 “no birthmark” 改成 “unmarked skin”，避免反套路词 `birthmark` 进入正面提示词；令牌仍是 `mark:none`。

## 验收怎么读

`project/tests/suites/art/portrait_bank_check.tscn` 在新进程里按种子顺序重跑这 20 局，对照已提交的队列：

- 出生者桶命中率 ≥ 95%
- 命中桶的 `identity_overlap` 均值 ≥ 0.80
- 桶数 ≤ 6000，每条都有前缀、负面词和种子，每个身份系列都有五个年龄段
- 正面提示词过 `anti_trope.forbid_in_positive` 的词边界扫描（紧挨着的 `no ` 否定不算命中）
- 桶目录为空时，`UnitArt.portrait_kind` 不会变成 `genome`
- 同时有 `unit_id` 图和桶图时，`unit_id` 图优先

重生成队列（会覆盖 JSON）：

```
godot --headless --path project --scene res://tests/suites/art/portrait_bank_check.tscn -- --write
```

INF-01 合并前，`scripts/run_ci.sh` 还不会自动发现 `tests/suites/`。这张检查要单独跑。合并后会自动接入。

## 交给农场

FARM-01 只渲染本队列。被风格门禁拒绝的图不要写进 `portraits/genome/bank/`。原始出图不要放回 `farm_inbox/`。
