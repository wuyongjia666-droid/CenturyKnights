# 团长（leader）底模重做出模方案 v2

> 状态：方案稿（2026-10-15 22:00 北京时间）。混元 Hunyuan3D（m173 :8327）今晚不在线；本地 Qwen :8322 / SenseNova :8329 今晚也探测不通（`tools/farm_queue/probe_farm.sh` → HTTP 000），**今晚不出图、不出模、不回退旧方案**。
> 上一版被否的原因（必须全部根除）：脸是立绘裁下来平贴成"面具"；手举在脸前挡脸；头发是硬片；衣服只是换色，没有布料结构；底模本身精度不足。

## 0. 原则
1. 底模决定成败：所有"像不像"必须在**几何**上成立（脸型、翻领、高领、项链、袖章、发型体块），贴图只负责颜色和细节，不再用贴图掩盖几何。
2. 禁止把立绘脸裁下来直接平贴（`stamp_farm_faces.py` / `board_head_front_clean_blender.py` 这条"贴脸"路本轮不用）。
3. 每一步都有对照图，过不了验收的不发给用户、不合主线。
4. 不用 PR #301 模块化 kit，不用 `compose_captain.glb` 拼装件。

## 1. 现有资产与工具（盘点）
| 用途 | 路径 |
|---|---|
| 团长立绘（唯一真值） | `project/assets/art/portraits/leader_default.webp`，脸部 `leader_default_face_plate.webp`，半身 `leader_plate.webp` |
| 当前演出模型（被否） | `project/assets/models/units/cast_leader.glb`、`cast_leader__board.glb` + albedo |
| 当前棋盘 farm_cast | `project/assets/models/board/farm_cast/leader_m.glb`（5500 tris，h 1.85） |
| 农场探测 | `tools/farm_queue/probe_farm.sh`（Qwen :8322 默认，SN :8329 可选，不用云端 / *Api 节点） |
| 混元参数参考 | `tools/farm_queue/farm06_hunyuan_smoke.json`（端口 8327，`hunyuan3d-dit-v2_fp16`） |
| 自动绑定 | `tools/models/rig_mesh_v87.py`（地标自动绑骨 → 套用 `build_standins_v86.BONES` 标准骨架，归一 1.78m，前方 -Y） |
| retopo | `tools/models/retopo_farm_hunyuan.py`（体素重拓扑 → collapse，默认 5500 tris，h 1.85） |
| 动作库 | `project/assets/models/anim/{sword,shield,spear,bow,staff,heavy}.res`，`build_anim_libraries.gd` |
| Godot 加载 | `project/scripts/art/board_figure.gd`（优先 `units/*.glb`，`_find_skel` 找 Skeleton3D，`board_figure.gdshader`） |
| 对照输出目录 | `/workspace/board_figure_p1_review/captain_v2/` |

## 2. 输入概念图准备（Qwen 本地，SenseNova 备选）
### 2.1 产出
`/workspace/board_figure_p1_review/captain_v2/concept/`：
- `captain_front.png`（正面 0°）、`captain_34.png`（35° 四分之三）、`captain_side.png`（90° 侧面）、可选 `captain_back.png`
- 每张 1024×1536 以上，纯白或浅灰平底，无投影、无道具遮挡、全身入画（头顶到鞋底留 5% 边）。
- 另存 `captain_turnaround_sheet.png`（三视图拼板，人工检查用）。

### 2.2 风格与姿势
- 与立绘同一风格：写实当代奇幻、写实比例（约 7.5 头身）、同一张脸（以 face_plate 做参考图 / IP-Adapter / 图生图参考）。
- 中性 A-pose：双臂下垂外展约 30–40°，**手离开脸和躯干至少一个手掌宽度**，手指自然张开可见五指，双脚与肩同宽，正视前方，表情中性略坚毅。
- 平光（不要立绘的戏剧侧光），避免混元把阴影当几何。

### 2.3 必须出现的服装细节清单（逐项对照立绘）
1. **灰色西装翻领长外套**：中灰偏冷，戗/平翻领清晰、领边细，不是深色描边；下摆长度与立绘一致；扣位、口袋盖照立绘。
2. **黑色高领内搭**：贴颈高领，露出于翻领 V 区内；领口不能糊成一块黑斑。
3. **钥匙项链**：细链 + 钥匙吊坠，落在高领内搭前胸，正面可见。
4. **袖章：罗盘星（compass-star）徽章**：位于上臂（按立绘的左/右侧），圆形/星形，银或金属色。
5. **黑色侧分发型**：黑发、侧分、向一侧扫，发量和刘海走向照立绘；耳朵、额头露出程度照立绘。
6. 裤、靴、腰带、手套（如立绘有）逐项列在提示词里；立绘看不到的部位（背面、鞋）按同风格合理补，并在对照表标注"推断"。

### 2.4 提示词骨架（中文意译，实际用英文）
`full body character turnaround, same man as reference, realistic contemporary fantasy, neutral A-pose, arms away from body, hands visible and away from face, gray suit-lapel long coat, black high-collar inner shirt, key pendant necklace, compass-star badge on sleeve, black side-swept hair, flat even lighting, plain light gray background, front view / three-quarter view / side view`
负面：`hands near face, crossed arms, weapon, cape covering body, dramatic shadow, cartoon, chibi, cropped feet, multiple people`。

### 2.5 概念图挑选
每个视角出 8 张，选 1 张；条件：脸与立绘同一人（眉眼、鼻梁、下颌）；五项服装细节全部可见；三视图之间服装细节位置一致；手完整、无六指。三视图不一致时以正面为准重出侧面。

## 3. Hunyuan3D 出模
### 3.1 参数（基于 farm06 smoke）
- 端口 8327，ckpt `hunyuan3d-dit-v2_fp16.safetensors`；若机器上有 mv（多视图）版本，优先用**多视图输入**（front/side/back）。
- steps 50，cfg 8.0（候选另跑 cfg 5.5 / 7.0），sampler euler / scheduler normal。
- octree_resolution 512（候选另跑 384 对比），num_chunks 32000，threshold 0.6，surface net。
- 开启纹理（Paint）阶段仅作参考色，不作最终贴图。

### 3.2 候选数量
- 正面单图输入 × seed 4 个 + 多视图输入 × seed 4 个，共 **8 个候选**；每个导出 GLB + 四视角渲染（0°/35°/90°/180°）到 `captain_v2/hy_candidates/cNN/`。

### 3.3 挑选标准（打分 0–2，总分 ≥10/14 且无 0 分项才可入选）
1. 整体比例与概念图一致（头身比、肩宽、外套下摆长度）
2. 头部体块：颅型、下颌、鼻梁有形状，不是光滑蛋
3. 翻领在几何上凸起可辨
4. 高领在几何上包住脖子
5. 手：两只手分开、有手指雏形、不粘大腿
6. 头发体块：侧分方向正确，不是头盔球
7. 无破洞、无漂浮碎片、无腿部粘连
全部候选都不过 → 回到第 2 步调整概念图，不硬上。

## 4. Blender 修模（Blender 4.x，脚本化 + 手工）
### 4.1 清理与归一
- 导入 → 删碎片 → 合并 → 以 `rig_mesh_v87.py` 的 `normalise` 规则对齐：脚底 z=0、居中、前方 -Y；高度先按 1.78m（绑骨标准），最终棋盘件按 1.85m 与现有 farm_cast 一致。

### 4.2 重拓扑
- 高模保留作烘焙源。
- **演出 LOD0：约 18,000 tris**（`rig_mesh_v87.py --tris 18000`），脸部和手部布线优先：脸 ≥2,500 tris，双手各 ≥800 tris，有眼窝/嘴角环线，便于表情和绑骨变形。
- 关节（肩、肘、腕、膝）至少 3 圈环线；外套下摆与腿分离或单独一片网格。
- 用 Quad Remesher / 手工修布线；`retopo_farm_hunyuan.py` 的体素→collapse 只用于 LOD2，不用于 LOD0。

### 4.3 脸（与立绘对齐的核心）
- 在正交前视图导入 `leader_default_face_plate.webp` 作参考图，35° 视图导入立绘本身。
- 用雕刻（Grab/Clay/Smooth）逐项调：眉骨高度、眼距、眼形、鼻长与鼻翼宽、人中、嘴宽、下颌角、颧骨；以几何轮廓对齐立绘线稿，不靠贴图。
- 眼睛做独立眼球 + 眼睑几何；眉毛、睫毛进贴图。
- 投影：仅在**正面 ±30°锥体内**用立绘做颜色投影，且必须经过肤色/光照去烘（去掉立绘的固有阴影），并与 Hunyuan 纹理/手绘肤色在边缘羽化融合 → 侧面不拉伸、无"面具边"。

### 4.4 手
- 用标准手部模块（五指、三节指骨、指甲）替换混元粘连手，接腕部后焊接；A-pose 自然半握。
- 绑骨后验证：任何默认动作（idle/advance/attack/skill/hit/dodge/crit/death）里手不进入脸前遮挡区（头部包围盒正前方），否则调整动作重定向偏移或手臂权重。

### 4.5 服装褶皱与结构
- 翻领：单独建模的领片（有厚度 ~5mm、细边），中灰；领边颜色与外套同色系，**不允许深色描边**。
- 高领：独立管状几何，黑色但带布料高光与褶，避免死黑块（albedo 不低于 sRGB 0.08）。
- 外套：肘内侧、腰带下、背部雕刻主褶皱（大中小三级），烘到法线；下摆单独一层，绑到大腿骨带衰减权重。
- 项链：细链用曲线转网格（低段数），钥匙用实体几何（约 200 tris），挂在胸骨位置，绑 chest 骨。
- 袖章：实体圆片 + 罗盘星浮雕（法线烘），位置对齐立绘。

### 4.6 头发
- 不用硬面片。先做**发块体积几何**（侧分主发块 + 刘海块 + 鬓角），雕出发束沟槽；再在表面加少量 alpha 发片仅做轮廓柔化（≤20 片，双面，alpha-hash）。
- 发际线与额头几何对齐立绘；从 35° 看侧分方向与立绘一致。

### 4.7 UV 与贴图
- UV：头 + 脸单独一块（占 0–1 空间约 30%），手 10%，外套 35%，其余 25%；纹素密度脸部 ≥2× 其他部位。
- 烘焙：高模→低模 法线、AO、曲率；albedo 来自（a）手绘基础色 按立绘取色（灰外套、黑高领、黑发、肤色、金属件），（b）脸部正面投影（4.3），（c）Hunyuan 纹理仅作参考。
- 贴图：演出 2048²（albedo + normal + ORM），棋盘 1024²/512²。
- 色值以立绘为准取样：每个区域在立绘上取 5 个点平均，记录到 `captain_v2/palette.json`，与成品渲染对比 ΔE。

### 4.8 绑骨与动作
- 用 `rig_mesh_v87.py` 的地标自动绑骨，骨架名与 `build_standins_v86.BONES` 一致（hips/spine/chest/neck/head + L/R 四肢），保证 `project/assets/models/anim/*.res` 与 `build_anim_libraries.gd` 的动作库直接复用。
- 手工修权重：肩、腋下、翻领（跟 chest，不跟上臂）、外套下摆、手指。
- 在 Godot 中逐个播放 8 个动作截图检查：无穿模、无翻领撕裂、手不挡脸。

## 5. LOD 与棋盘尺寸
| LOD | 用途 | 目标 | 贴图 |
|---|---|---|---|
| LOD0 | 演出/特写 | ~18k tris | 2048² |
| LOD1 | 战斗近景 | ~8k tris | 1024² |
| LOD2 | 棋盘件 | ≤5,500 tris（与 farm_cast 一致，h 1.85） | 512²，脸部单独加亮 |
- LOD2 用法线把 LOD0 细节烘下；保留翻领、高领、发型轮廓几何（这三处是棋盘距离辨认的关键），可简化手指为三指连并。
- 棋盘尺寸下（屏上头部约 12–20 px）脸不可能有五官细节，靠**发型轮廓 + 灰外套/黑高领分区 + 肤色明度**辨认；`board_figure.gdshader` 的高度色带在团长上关闭，改用贴图。
- 输出：`project/assets/models/units/cast_leader_v2.glb`（LOD0/1）、`project/assets/models/board/farm_cast/leader_m_v2.glb`（LOD2）；旧文件保留到验收通过再替换。

## 6. 验收（对照立绘，诚实判定）
每轮出一张对照拼板 `captain_v2/check/round_NN.png`：左立绘、中模型同角度渲染（正面 0° 和 35°，与立绘同焦距/同光方向）、右叠加（50% 透明叠图）。

**通过条件（全部满足才算过，任何一条不过就是不过）**
1. 脸：不看标注的第三人（另起一个审查子任务，只给两张图）能判断"是同一个人"；眉眼间距、鼻长、下颌轮廓在叠图中偏差 ≤ 头宽 5%。
2. 无面具边：35° 和 60° 渲染中脸部与头部之间无可见色块边界或拉伸。
3. 手：两只手五指可数，任何视角/默认动作中不挡脸。
4. 服装五项（翻领、黑高领、钥匙项链、袖章罗盘星、黑侧分发）在 0° 渲染中逐项可见，在 35° 中至少 4 项可见；翻领是凸起几何而非贴图。
5. 头发：轮廓非球形/头盔形，侧分方向正确，35° 可见发束分组。
6. 配色：灰外套、黑高领、肤色、黑发四区与 palette.json 的 ΔE ≤ 8。
7. 棋盘：在实际棋盘截图（游戏内相机、默认缩放）中，团长与猎手/山贼并排时一眼可辨为"穿灰大衣、黑高领的黑发男人"；无锯齿（开启 MSAA/AA 后边缘无台阶）、无黑斑。
8. 8 个动作截图无穿模、无撕裂。

**判定纪律**：我（代理）在发给用户之前必须亲自逐张看图，按上表逐条写"过/不过+原因"；任何一条不过就写不过，不发"像"的结论；报告里附图路径，不转述脚本自评。

## 7. 风险与应对
| 风险 | 应对 |
|---|---|
| 概念图换脸、不是立绘里那个人 | 以 face_plate 做强参考；每视角 8 选 1；仍不像就先只做正面单视图出模，侧面靠雕刻 |
| 混元把平光误判、四肢粘连 | A-pose + 手离身；多视图输入；粘连手直接替换手模块 |
| 混元多视图版本不在机器上 | 退为单图 × 4 seeds，侧面在 Blender 里按侧视概念图雕刻 |
| 雕脸耗时、主观 | 叠图量化偏差（≤5% 头宽）；限定 2 轮，2 轮不过向用户汇报卡点 |
| 绑骨后翻领/下摆撕裂 | 翻领权重锁 chest；下摆单独网格+衰减权重 |
| 棋盘 12–20px 无法体现脸 | 如实告知；靠轮廓与配色辨认，必要时棋盘相机略拉近或头部 1.1× 夸张（需用户同意） |
| 动作里手挡脸 | 动作重定向加偏移；或团长专用 idle |
| 农场机器（m173）明天仍不在线 | 只汇报，不回退旧"贴脸"方案 |

## 8. 时间线（混元上线后）
1. 概念图 3 视角（~1–2 小时含挑选）
2. 混元 8 候选 + 挑选（~1 小时）
3. Blender 清理/重拓扑/脸/手/衣/发（~4–6 小时）
4. UV/烘焙/贴图（~2 小时）
5. 绑骨 + Godot 动作检查（~1–2 小时）
6. LOD + 棋盘验收 + 对照拼板（~1 小时）
先只做团长；团长过验收、用户点头后，再按同一流程做猎手和山贼。
