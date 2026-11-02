# 商店截图清单（不缴费；先拍齐再谈提审）

> 工程可执行：列出必拍帧、分辨率、禁止事项。今日**不上传** Play / Partner Center。  
> 关键词供门禁：`1080`、`横屏`、`五张`、`不付费`。  
> 捕获 / 门禁：`scripts/capture_store_shots.sh`、`tools/ci/store_shots_check.py`（`store_shots_check`）。

## 平台尺寸（今日口径）

| 平台 | 主截图 | 备注 |
|---|---|---|
| Google Play 手机 | **16:9 横屏** ≥1080p（建议 1920×1080） | 产品定位横屏手游；竖图不得作为主图 |
| Google Play 平板 | 可选 16:9 / 16:10 | 有真机再补；今日不挡门禁 |
| Microsoft Store | 1366×768 或 1920×1080 | 与 Windows 出包一致 |

## 五张必拍（对标 listing 卖点）

| # | 画面 | 对应卖点 | 怎么进 | 捕获 id |
|---|---|---|---|---|
| 1 | 主城 / 城堡枢纽 | 「百年王朝」一眼可读 | `castle_hub` 存档或新局月初始 | `01_castle_hub` |
| 2 | 战棋对阵中 | 策略对战非挂机 | 任意 mid-battle；HUD 清晰 | `02_battle` |
| 3 | 族谱 / 血脉 | 血脉传承 | atlas / genealogy 视图 | `03_genealogy` |
| 4 | 剧情对话（季#1 或季#2 可玩章） | 中篇叙事 | cs01 / cs02 对话节点 | `04_cs_dialogue` |
| 5 | 月回响 / 产业结算 | 经营节奏 | month_echo 或 estates 面板 | `05_month_echo` |

## 工程捕获（真机帧，非营销合成）

```bash
# 本机（需 godot + xvfb）：写出 5 张 1920×1080 PNG + manifest
bash scripts/capture_store_shots.sh /tmp/ck-store-shots

# 门禁（校验尺寸 / 横屏 / listing 卖点关键词 / manifest sha）
python3 tools/ci/store_shots_check.py
```

- 场景套件：`project/tests/suites/store/store_listing_shots.tscn`（真实 hub / battle / chapter_player / estates，EmptyHost-free）  
- PNG 落点：`docs/store/shots/`（**gitignore**）或 `/tmp/ck-store-shots`  
- 入库清单：`docs/store/shots-manifest.json`（文件名、WxH、sha256、listing bullet）— **不**把多 MB 二进制塞进 git  
- CI 无显示 / 无 PNG 时：校验 manifest schema；显式 `CK_STORE_SHOTS=0` 打印 `STORE SHOTS SKIP`  
- 嵌套：`store_prep_check.py` 会跑 `store_shots_check.py`

## 禁止

- 误导性合成图、未实装 UI、付费墙假图  
- 含真实可识别路人/未授权素材  
- 竖屏主图（与 `docs/design/mobile-landscape.md` 冲突）  
- 把 debug overlay / FPS 水印留在上架图里  

## 工程自检

- [x] 五张本地 PNG/WebP 齐（路径自管，**不进 git 大包**；可用 `docs/store/shots/` gitignore）— 经 `capture_store_shots.sh`  
- [x] 每张 ≥1080 短边；横屏 — `store_shots_check.py`  
- [x] 与 `listing-copy-zh.md` 五条卖点可一一对应 — 门禁关键词交叉  
- [x] **不付费**上传；今日只备齐
