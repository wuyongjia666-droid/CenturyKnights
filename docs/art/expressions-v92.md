# 对话表情差分 v9.2

农场仍暂停。这一卡只定规范、出图清单和缺图回退，不出图。正式图归 FARM-04。

## 风格

正向提示词以 `docs/art/style-lock-v89.json` 的 `qwen.prefix` 开头，负面词用整段 `qwen.negative`。画面是 2026 当代奇幻：磨砂玻璃、小块薄荷、小块珊瑚，冷白主光，霜青轮廓光。正向词里不写中世纪、羊皮纸、金色。采样固定 steps 28、cfg 1.0、euler / simple，768×1024。

## 五种表情

| 键 | 中文 | 只改五官的子句 |
|---|---|---|
| `neutral` | 平静 | 嘴放松，眼睛睁开 |
| `joy` | 喜 | 只在眼睛和嘴上的一点笑 |
| `anger` | 怒 | 下颌咬住，眉压低 |
| `sorrow` | 悲 | 眼睛低下 |
| `surprise` | 惊 | 眼睛睁大，唇微张 |

播放器读台词的 `expression`（或 `emotion`）。中文「喜 / 怒 / 悲 / 惊」和英文键等价。空值当作平静。

## 身份

每个人一个种子，五张图共用。种子由槽位 `v92_expr_cNN` 算出，不随表情变。

`neutral` 是整张生成（`edit: full`）。另外四张是对这张平静图的局部重绘（`edit: local`）：只动眼睛和嘴，头发、衣服、姿势不动。`identity_ref` 指向该槽的平静图路径。农场恢复后先出平静图，再按同一种子做局部重绘。FARM-04 验收的身份重叠不低于 0.85。

## 命名

`project/assets/art/portraits/expressions/v92_expr_<槽位>_<表情>.png`

槽位按 `project/data/cast/companions_v92.json` 的数组顺序，从 `c01` 到 `c12`。不要改 id。

| 槽位 | 姓名 | id |
|---|---|---|
| c01 | 苇原·灯影 | weiyuan_dengying |
| c02 | 白垣·折杆 | baiyuan_zhegan |
| c03 | 影针·小弦 | yingzhen_xiaoxian |
| c04 | 渔火·平梢 | yuhuo_pingshao |
| c05 | 裂谷·砧声 | liegu_zhensheng |
| c06 | 古樟·沉斑 | guzhang_chenban |
| c07 | 霜阙·晚霜 | shuangque_wanshuang |
| c08 | 芦浦·汐回 | lupu_xihui |
| c09 | 深镐·平眉 | shengao_pingmei |
| c10 | 雾港·余光 | wugang_yuguang |
| c11 | 东虹·桥外 | donghong_qiaowai |
| c12 | 西虹·测距 | xihong_ceju |

清单在 `tools/farm_queue/v92_expressions.json`，共 60 条，给 FARM-04 用。`validate_queue_v92.py` 核对人数、五种表情、同一种子、局部重绘引用和风格锁。

## 缺图回退

`UnitArt.dialogue_portrait` 先找上面的路径。文件不在时，回到这个说话者的基础立绘（`UnitArt.portrait`）。说话者还没进名册时，章节播放器用团长的基础立绘顶上。旁白和没有槽位的说话者仍用原来的旗帜或团长立绘。

## 交接

- FARM-04：按这份清单出图，先平静、再局部重绘。不要把原图放进 `farm_inbox`。入库路径就是清单里的 `out_path`。
- NAR：台词可以写 `expression`。不写也能播，缺图不会空出头像框。
