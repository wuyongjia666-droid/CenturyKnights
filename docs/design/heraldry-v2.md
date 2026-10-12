# 纹章 / 队旗深度系统 v2（Heraldry Deep）

> 角色：表现 + 存档兼容。基线：`main@26999d5c`。  
> 风格锁：2026 当代精致奇幻 SRPG（`docs/art/style-lock-v89.json`）——霜青 / 薄荷 / 霜银 / 墨蓝；**禁止**中世纪做旧、羊皮纸、鎏金 / 黄铜、暖金 `#c9a227`。  
> 实现：`CKHeraldry` + `CKHeraldryRender`；`BannerSpec` 保留为兼容门面。

---

## 1. 现状审计（v1 / v9.3 DIY）

| 层 | 现状 | 问题 |
|---|---|---|
| 数据 | `GameState.banner_spec`：field / charge / border / emblem + 五色 hex | 无金属 / 色料分野、无分区线型、无完整纹章成就、无联姻拼合、无嫡庶差异 |
| 渲染 | `BannerSpec.compose` 逐像素矩形；预烘焙 `banner_<hex>_wN.png` 飘动帧 | 锯齿重、徽记像剪贴几何、任意尺寸糊、无盾形 / 盔 / 冠 / 扶盾 / 格言 |
| 编辑器 | `naming.gd` 四行 ◀▶ 轮换 | 无分层 live 预览深度、无染色违规提示、无按国随机、触控尚可但信息密度低 |
| 国别 | `CKCourtChrome.NATION_MARK` 十国几何徽 | 未接到玩家队旗；无国别盾形 / 色板 / 偏好电荷 |
| 血胤 | 联姻有旗饰誓约；出生有 rank | （设计决定：团徽 + 族徽，不随联姻 / 出生变化，见 §3.6） |
| 露出面 | 城堡 `CompanyBanner`、`UnitArt.banner*`、开局命名 | 族谱节点、名录、战场小旗、舆图据点未统一走同一 API |

结论：v9.3 分层 DIY 是正确方向，但深度停在「换色块」。v2 要做成可远看辨认、近看有材质、随城堡爵级演进的完整纹章系统。

---

## 2. 目标体验

1. **开局**：分层编辑器（底色 → 分割 → 普通图记 → 电荷 → 成就件）实时预览盾徽 + 垂旗；染色法则警告；「按国随机」。
2. **运行时**：世界地图据点旗、战场单位旗、城堡大厅、族谱节点、名录头像角标、开局 DIY **共用** `CKHeraldry.render_*`。
3. **归属**：团徽（永久）+ 团内家族族徽；不做联姻拼合与个人差序（§3.6）。
5. **爵级**：勋士 / 男爵 / 伯爵 / 侯爵 / 王室对应盔型与冠冕层级；王室可挂扶盾者。

---

## 3. 数据模型（`heraldry_v2.json`）

### 3.1 染色（Tinctures）

- **金属 metals**：霜银 or、霜白 argent（映射风格锁银 / 白，**不用金**）。
- **色料 colours**：霜青 azure、潮墨 sable、薄荷 vert、珊瑚 gules、河蓝、岚紫等（全部霜系安全色）。
- **毛皮 furs**：霜皮 ermine、潮斑 vair（几何化点阵，非写实毛皮）。
- **染色法则**：金属不叠金属、色料不叠色料；毛皮可与任一类相邻。违规 → `tincture_ok=false` + 编辑器警告。

### 3.2 底面分割（Divisions）

`solid / per_pale / per_fess / per_bend / per_bend_sinister / quarterly / per_chevron / per_saltire / gyronny`

分区线：`straight / wavy / engrailed / embattled / invected / nebuly`

### 3.3 普通图记（Ordinaries）与次级

`none / fess / pale / bend / bend_sinister / chevron / cross / saltire / chief / bordure / orle / pile / pall / gyron`

### 3.4 电荷库（Charges）

- 通用几何：ring / spark / leaf / wave / filament / tide / bars / arc / notch / hollow / chevron_mark / mullet / crescent / annulet / lozenge / tower / bridge / lantern / flake / reed / anvil / starbridge / zephyr
- **十国专属**（各 2–3）：见 nation 表；与 `NATION_MARK.kind` 同源但更完整。

### 3.5 完整成就（Achievement）

| 件 | 档 |
|---|---|
| 盔 helm | none / closed（勋士）/ grilled（贵族）/ royal |
| 冠 crown | none / knight / baron / count / duke / royal |
| 幔 mantling | 主 / 辅两色（默认取 field + ordinary） |
| 扶盾 supporters | 仅 royal / duke+；几何化霜兽剪影 |
| 格言 motto | 短句；绘制于底饰带 |

### 3.6 团徽与族徽（设计决策 2026-10-12）

我们是**一个佣兵团**：城堡与领地固定不变，`GameState.banner_spec` 即**团徽**，开局命名页定下后**永久不变**（无改旗、无按爵级重定档、无迁城）。

| 类别 | 归属 | 生成 | 谁显示 |
|---|---|---|---|
| 团徽（旗徽） | 佣兵团 | 开局 DIY | 无家族的团员 |
| 族徽 | 团内家族 | 家族建立时一次生成（`GameState.found_family`），此后不变 | 该家族成员 |

**规则**
- 两类纹章共用同一套设计体系（染色、分区、主纹、纹样、十国风格）。
- **唯一性**：族徽 vs 团徽、族徽 vs 族徽，按**核心设计**（`CKHeraldry.core_key`：分区 / 线型 / 两色 / 主纹 / 纹样 / 盾形）判定，忽略小方角与档位装饰。其他佣兵团 / AI 旗帜不在此范围。冲突时团徽优先，族徽确定性重掷（`ensure_unique_arms`，仅在开局与旧档迁移时触发）。
- **小方角（canton）**：族徽左上角固定一块小方角，取团徽底色与首纹样，一眼可读「属于本团」。
- **档位装饰**：随家族成员最高爵位实时计算 —— 平民（全员勋士）：单纹样、无镶边；贵族（男爵+）：最多 2 纹样 + 霜银细线镶边；王族（侯爵）：最多 3 纹样 + 双线镶边。装饰均沿用该家族所属国的风格。
- **联姻不合并家族**；子嗣随父系家族，父无家族则随母系。纹章不表达出生顺序或嫡庶（cadency / bastardy / impale / quarter 已移除），这些由血胤与立绘表达。
- **族谱**：页眉显示一次团徽；每张成员卡显示其本人纹章（族徽或团徽），右下叠加**爵位徽记**（勋士霜针 / 男爵素环 / 子爵珠柱环 / 伯爵五尖冠 / 侯爵叶冠 / 王室拱冠），爵位升降时通过 `CKCharacter.rank_changed` 实时更新。爵位徽记不是 cadency，只表达头衔。

**取舍理由**
- 团徽永久：玩家认同的是这面旗；改旗 / 拼合会稀释识别度，也与「一个团、一座城」的叙事冲突。
- 族徽带小方角：家族在团内有自我身份，同时保留对团的归属感，读图一眼可辨。
- 只比核心设计：小方角对所有族徽都一样，装饰随档位变化，若计入会让「看起来一样」的两面族徽通过检查。
- 档位只改装饰不改核心：升爵不会让族徽「变成另一面旗」，族人仍认得自家纹章。

**存档迁移**
- 丢弃旧 `marshalling` / `cadency` / `bastardy` 字段与 `blood_meta.heraldry`。
- 旧档无 `families`：以团长为创始人建立首个家族，并沿亲子关系把其后代归入；其余团员 `family_id=""` → 显示团徽。

### 3.8 十国风格

每国：`shield_shape`、`palette`（主 / 辅 / 墨）、`preferred_charges`、`partition_bias`、`motto_default`。

| id | 盾形 | 主调 |
|---|---|---|
| ashbanner | heater | 霜银 / 潮墨 |
| shuoying | kite | 羽蓝 / 潮墨 |
| qinghe | round | 薄荷 / 霜白 |
| lantern | banner | 霜青 / 晴霜 |
| frostcrown | heater | 霜白 / 河蓝 |
| emberold | heater | 珊瑚 / 潮墨 |
| saltmarsh | round | 潮青 / 霜银 |
| irongorge | heater | 铁霜 / 潮墨 |
| starriver | lozenge | 天光 / 潮墨 |
| southzephyr | round | 松雾 / 霜白 |

---

## 4. 渲染

- `CKHeraldryRender.compose_arms(spec, w, h, opts)` → `Image`（2× 超采样后降采样，抗锯齿）。
- `compose_banner(spec, w, h, wave)` → 带旗杆的垂旗（战场 / 城堡）。
- `compose_shield(spec, w, h)` → 纯盾（族谱 / DIY / 名录）。
- 材质：统一描边权重、顶部冷光 sheen、边缘 1px 霜线、轻微「珐琅 / 绣面」明度噪声（确定性种子 = cache_key）。
- 缓存：`UnitArt` 现有 `_cache`；key 含 schema + 爵级。

---

## 5. 编辑器 UX（命名页 + 堡内 DIY）

分层步进：底色 → 分割 / 线型 → 普通图记 → 电荷 → 成就（盔冠可选）。  
Live 预览：左盾右旗。  
染色法则条：违规红字（`ux_heraldry_tincture_warn`）。  
「按国随机」：读 `GameState` 当前据点国或默认灰烬邦。  
触控：行高 ≥ 48dp；色板网格替代长◀▶（P0 网格 + 保留◀▶）。

---

## 6. 存档兼容

1. 无 `banner_spec` → `from_crest(crest_color)`。
2. v1 spec（无 `schema` 或 `schema<2`）→ `CKHeraldry.migrate_v1`：field→division，charge→ordinary，emblem→charges[0]，补默认 achievement。
3. `crest_color` 始终 = 主金属 / 主色 `field_a` 别名。
4. 预烘焙 PNG 仅作 fallback；新渲染优先。

---

## 7. 验收

- GUT / headless：染色法则、爵级分档、族徽唯一性 / 小方角 / 档位、爵位徽记实时、旧档迁移。
- 10 张样例 PNG（十国各一，含王室 / 公爵成就）：人工目视通过后入库 `assets/art/heraldry_samples/`。
- 既有 `banner_diy_check` / `crest_palette_check` 仍 PASS。
- 风格 / i18n ratchet：新 `.gd` hex=0、CJK 字面量=0。

---

## 8. 非目标

- 不引入真实纹章版权图案；全部原创几何。
- 不改战斗数值 / 血胤公式。
- 不在本 PR 重做 3D 过场旗布 UV（若场景存在则只换纹理采样 API）。
