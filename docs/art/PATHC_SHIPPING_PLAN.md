# Path C → 棋盘航运方案 v2（2026-10-16，Opus 收紧版，**以本节为准**）

> 用户已拍板；团长试点已签收。「不减面」= **母版不减面**：1.5M Path C 是唯一视觉母版，永不修改/降面，存 sha256；
> 航运档是从母版**重建**的烘焙件，不是在母版上减面。验收看棋盘镜头实机截图 vs 母版，不看线框面数。

## A. 事实（实测）
- 400MiB 硬顶：估算整包 ~720.4MB（头像库 ~397.9MB + 其余 ~322.5MB）→ **已超硬顶约 301MB**；现行门禁比的是派生预算（~730.8MB），需另开项处理。
- 棋盘为正交俯视、缩放 0.65–2.4×，**无棋子特写镜头**；FE 式演出用 `units/*.glb`，不读棋盘件 → **近景档暂不做**。

## B. 管线（`tools/models/bake_pathc_ship.py`）
1. 细体素重拓扑（体素 = 身高/400 ≈ 4.6mm）→ 干净无 UV 新网格（~30–76 万三角）。
2. 在新网格上 Decimate 到目标（不碰母版 UV，不违反禁 COLLAPSE 初衷）。
3. Smart UV → selected-to-active 烘 512 albedo（extrusion 0.02 / ray 0.05 / margin 8）。
4. 去光：只烘颜色（EMIT 烘去光 albedo）；metallic>0.85 的金属件提亮到可感知银色（否则烘出来发黑）。
5. 单材质 GLB，贴图 JPEG q88；meshopt 不用（Godot 导入器不支持）。身高 1.85、脚底 0。

## B2. 烘焙 v2（2026-10-17，修批量瑕疵）
- 根因：v1 批量用「金属提亮」在 sRGB 编码的 8bit 金属图上做阈值，噪点金属值→白斑/彩斑（头发、盔甲）；512 直烘 + 碎 UV 岛 + margin 8 让脸糊、边缘渗色。团长母版几乎无金属、外形简单，所以 v1 正好没踩到。
- v2：1024 烘再降 512；margin 16；头部 UV 岛 2.2× 纹素优先 + 旋转打包；albedo 用 DIFFUSE 颜色；金属区（浮点金属图，k=2 模糊）混入「均匀白天光」COMBINED 烘焙，强度按与母版渲染误差逐件选 0/0.5/1。
- 运行时：航运件走 `shaders/board_figure_ship.gdshader`（保留自身 albedo，敌方红色 rim）；职业武器取自套件，按 `pathc_ship.hands` 挂到手位。

## B3. 烘焙 v3（2026-10-17，脏斑根因）
- 根因（比 v2 更深）：棋盘距离下 Godot 默认 mipmap + 碎 UV 岛几乎无 padding（猎人黑底仅 0.7%）→ 岛间渗色发脏；复杂衣褶母版自带烘死光影，降到 512 后变成 mottling。团长外套颜色更均匀，所以看起来干净。
- v3：更细体素(h/480)、UV island_margin 0.016 + pack 0.018（黑底垫到 ~4–9%）、1024 烘 margin 24 再降 512 + 空像素 dilation；航运贴图 **关掉 mipmap**（import + shader `filter_linear`）。
- 武器：弃用套件方块件，改 `pathc_weapons/{sword,spear,axe,bow}.glb` 写实网格（钢/木/皮多材质），按 hands 挂手，棋盘可读加粗。

## C. 分档 / 门禁（`tools/ci/pathc_ship_gate.py`，已接 run_ci.sh）
| 项 | 门槛 |
|---|---|
| 关键角色棋盘档 | ≤15k 三角，≤1.0MB（团长/猎人男女/山贼头目） |
| 共用身 + 职业壳 | ≤12k，≤0.6MB |
| 杂兵 | ≤6k（待做） |
| 近景档 | ≤35k，仅有特写镜头时才做（当前无） |
| 贴图 | 1 材质、1 张 albedo ≤512、JPG/WebP |
| 目录总量 | pathc_ship ≤12MB |
| 硬拦截 | project/assets 任一文件 >5MB 或 GLB >100k 三角；LOOK 源进导出树；docs/art/review 的 GLB 被 git 跟踪 |
| 追溯 | 每件 manifest（母版 sha256、三角、贴图、烘焙参数）`docs/art/review/board_figure_pathc_ship/manifests/` |
| 同屏 | 手机 ≤250–300k 三角（12 件 × ~12k 安全） |
| 视觉 | 棋盘镜头对照截图，用户签收后才替换 farm_cast |

## D. 母版存放
- LOOK 母版不进 git：`docs/art/review/PATHC_MASTERS_MANIFEST.json` 记路径 + sha256；字节在外部存储（box `/workspace/pathc_masters_store/`）。
- 旧 #310 历史含 ~1GB 大文件 → 已由无大文件的 squash 分支 `feat/board-figure-p0-clean` 取代。

## E. 运行时接线（#299 共用身 + 职业壳）
`UnitModel.board_load_path`：`board_figures.json pathc_ship.stem_map`（cast_leader / cast_dengying→hunter_m / enemy_bandit_chief→bandit_chief / outfit_*）→ 通用角色按职业 `pathc_outfit_<g>` 取壳（hunter / light_inf / captain→leader_coat）→ 同名 → units `__board` → units。航运件用自身烘焙贴图，不再走调色/脸贴/发型模块。底模 base_body_m/f 已出航运件，作共用身来源，运行时暂不作兜底（避免无职业服的素体上棋盘）。

## F. 顺序
1. ✅ 团长试点（已签收）。
2. ✅ 其余 11 件批量航运档（本 PR）。
3. P2 姿态：若需混元重生姿态，必须先于下一轮批量烘焙。
4. P3 手机分档 = 本节分档落地；同屏预算实测。
5. P4 共用脸 / 杂兵 ≤6k，最后。

---

## 附：v1 原方案（历史，数字以上节为准）

# Path C → 棋盘航运方案（2026-10-16）

> 目标：棋盘上看到 Path C 精致贴色，而不把 ~80MB / 1.5M 面的原模打进 Android/Windows 包。  
> 不减面 LOOK 仍保留；**运行时另做航运 LOD**。禁止 soft COLLAPSE 开壳；禁止农场灰粘土。  
> **本任务不合并 #310。**

## 0. 现状数字（#310 工作树实测）

| 项 | 数 |
|---|---|
| 硬顶 `CAP` | **400 MiB**（`export_size_report.py`） |
| 导出目标 | 250 MiB |
| `export_base_budget_bytes`（#310） | 322.5 MB |
| 当前 NONBANK 实测 | **322.0 MB** → 余量仅 **~0.47 MiB** |
| `farm_cast/`（运行时） | **2.9 MB** / 8 件，各 ≤5.5k 面、无贴图 |
| `board_figures_v1.glb` | **4.8 MB**（Opus 套件） |
| Path C LOOK（11 件） | **~932 MB**，各 ~73–87 MB / ~1.5M 面（在 `docs/art/review/...`，不进 `project/` 导出扫描） |
| 登记 | `project/data/board_figure_pathc.json`（LOOK only） |

结论：原模进包不可能；必须 **新拓扑 + 烘贴**，并 **上调 `export_base_budget_bytes`**（替换 `farm_cast` 后净增约 8–12 MB）。

---

## 1. 主方案（唯一主推）：**Voxel 重拓扑 + Path C 烘贴 → `pathc_ship`**

**一句话**：1.5M Path C 永远只做 LOOK/烘贴源；棋盘用「新网格」接 Path C 的 albedo（可选 normal），外形跟 Path C，体积跟得住包。

这不是 soft COLLAPSE 减面：Voxel Remesh 生成**干净新拓扑**，再 selected-to-active 从高模烘贴。旧 `remesh_bake_hunyuan_board.py`（Path B）方向对，但曾对高模先 soft COLLAPSE 且结果「未干净」——航运脚本要改掉这两点。

### 1.1 分档预算（每单位 / 整包）

| 档 | 角色 | 目标面数 | 贴图 | 单件 GLB 目标 | 件数 |
|---|---|---|---|---|---|
| **A 关键** | 团长、男猎人、女猎人、山贼头目 | **22–35k** | 512² albedo（可选 512 normal，或打包进 ORM） | **0.9–1.5 MB** | 4 |
| **B 共用** | `body_m`/`body_f` 航运壳 + 三职业×男女（猎人服/团长外套/轻步兵）整模替换件 | **12–22k** | 512² albedo | **0.6–1.1 MB** | 先做 8 槽对齐 `farm_cast`，再扩职业 |
| **C 杂兵** | 其余敌人/路人 | 复用 B 身+壳，或暂留现 `farm_cast` 5.5k | 同 B 或顶点色过渡 | — | 渐进 |

**棋盘场景三角（16 人满编，偏保守）**

- 全 A/B 中档 ~25k × 16 ≈ **400k** 面（高于 Opus 原稿 96k，远低于 1.5M×16）
- 低端机：沿用已有 `board_standin_baker` 2D 替身（开局烘一次）

**包体增量（相对现状）**

| | |
|---|---|
| 替换 `farm_cast` 2.9 MB → `pathc_ship` ~**10–12 MB**（8–12 件） | |
| 净增 | **~8–10 MB** |
| 动作 | `ratchet.json` 的 `export_base_budget_bytes` **+10 MB**（与 Opus P1「上调预算」同一做法） |
| 不进包 | 全部 `*__board.glb` Path C LOOK（继续 `docs/art/review/`） |

说明：Opus #299 原定「4–6k、0 贴图」被用户精致款标准覆盖；**保贴色/认人优先于原 0-texture 硬指标**。门禁改为：航运件 ≤35k、1 材质、≤2 张 512 贴图；关键件过目对照 Path C 正面/脸。

### 1.2 管线步骤

1. **源**：`docs/art/review/board_figure_hunyuan_cloud/pathc_native/*__board.glb` + 团长 `board_figure_p1/hunyuan_noreduce/cast_leader__board.glb`（normalize-only LOOK，不改）。
2. **脚本**（新建/重写，基于 Path B，禁止对 Path C 开壳 COLLAPSE）：
   - 建议：`tools/models/pathc_ship_bake.py`
   - 高模：Path C **原三角**作 bake source（内存紧时仅对**副本**做 voxel 到 ~200–300k 当 cage 源，仍禁止把碎裂 COLLAPSE 当交付）。
   - 低模：Voxel Remesh → 目标面数（A/B 表）→ shade smooth → smart UV（island margin ≥0.004）。
   - Bake：Cycles DIFFUSE color-only → 512 albedo；可选 NORMAL tangent。
   - 导出：单网格 GLB，内嵌 WebP/PNG albedo；高度 1.85、脚 z=0、面朝 −Y（与现 `farm_cast` / normalize 一致）。
3. **落盘**：`project/assets/models/board/pathc_ship/{stem}.glb`（进导出）；LOOK 不动。
4. **接线**：`CKBoardFigure` / `board_figures.json`：**优先 `pathc_ship` stem**，缺则 `farm_cast`，再 Opus kit。更新 `board_figure_pathc.json` 增加 `"ship_root"` / `"ship_glb"` 字段，不删 LOOK。
5. **着色**：航运件带自身 albedo 时，关掉「整模 coat 填色」；阵营布料可用二次 tint 或保留 Path C 色（敌方珊瑚规则另议，先保认人）。
6. **过目**：每件 Blender 正面 / 35° / 脸 vs Path C LOOK；过关再进 `pathc_ship`。
7. **CI**：`export_size_report` 过；新增 `pathc_ship_gate`（面数、贴图尺寸、单件 ≤1.6 MB）。

### 1.3 LOOK-only vs 进包

| 保留 LOOK-only（全三角 ~1.5M） | 进导出包（航运 LOD） |
|---|---|
| 全部 Path C `*__board.glb` | `pathc_ship/*` 中面烘贴件 |
| 审图 PNG、网页截图 | 运行时 `CKBoardFigure` 加载 |
| `board_figure_pathc.json` 的 `glb` 字段 | 同 JSON 的 `ship_glb` / 目录约定 |

**团长「不减面」裁定**：LOOK 对照永不减面；**包内航运 LOD 是另一份资产**，过目时并排 Path C，不宣称「减面不掉质量」。

### 1.4 首张可玩棋盘截图 ETA

| 步 | 时间（单人连续干） |
|---|---|
| 修/写 `pathc_ship_bake.py` + 团长试烘 1 件 | **2–4 h** |
| 过目调 voxel/UV/cage（1–2 轮） | **2–4 h** |
| 关键 3 件（团长/猎人/头目）批量 + 接线替换 `farm_cast` | **3–5 h** |
| Godot 开局战截图（桌面） | **1 h** |
| **合计到第一张「棋盘上像 Path C」截图** | **约 1 个工作日（8–12 h）** |
| 扩满 8–12 槽 + 预算 ratchet + 门禁 | 再 **1 日** |

不烧混元币（烘贴本机 Blender）；不合并 #310（可在 #310 分支或后续 PR 做航运目录）。

### 1.5 风险

| 风险 | 缓解 |
|---|---|
| Voxel 糊脸/丢衣褶 | A 档 512 贴图 + 面数 ≥22k；脸部过目门禁；失败则加大局部密度或单独 head 岛 |
| 旧 Path B「未干净」 | 禁止对交付高模 soft COLLAPSE；加大 bake margin；修 UV 重叠 |
| 包体 / NONBANK 余量 ~0 | 必须 +10 MB base budget；单件硬顶 1.6 MB |
| 手机 400k 面卡 | 默认 standin；桌面/高档机走 3D；P3 再分档 |
| 与 Opus「0 贴图」门禁冲突 | 改门禁文案与 check：航运允许 512 albedo |
| 职业壳本是全身 Path C，不是可拆壳 | v1 **整模替换槽**（同 farm_cast）；模块化组装留 v2（中模身+壳布尔/妆贴） |
| 用户以为「进棋盘=1.5M」 | 交付时并排 LOOK vs ship，写明两套 |

---

## 2. 备选（Fallback）：**farm_cast 5.5k 笼上烘 Path C 色**

若主方案脸糊/工期爆：

- 低模直接用现有 `farm_cast`（已 ≤5.5k、已接线）
- 仅 cage-bake / 最近点采样 Path C albedo → 512 贴图或顶点色
- **包增量 ~1–2 MB**，ETA **半天到首截图**
- **代价**：剪影仍是旧 farm 形，不是 Path C 外形；只解决「灰粘土/认色」，达不到精致款形体——仅作过渡，不作为终态。

---

## 3. 决策摘要

| | |
|---|---|
| **做** | 主方案：Voxel 重拓扑 + Path C 烘贴 → `pathc_ship`；LOOK 全三角不动 |
| **先做** | 团长 → 猎人 → 头目 → 接线 → 开局战截图 |
| **预算** | 净增 ~8–10 MB；`export_base_budget_bytes` +10 MB |
| **不做** | 原 1.5M 进 `project/assets`；soft COLLAPSE；每人再上云端；本任务合 #310 |
| **备选** | farm_cast 笼烘色（快、形不够） |

