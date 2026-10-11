# 立绘锐度 v9.2

q78 的出货 WebP 把脸压软了，Godot 导入再按同样的 `lossy_quality` 压一遍。这一轮从母版重编码，不缩分辨率，也不靠把城图、场景或界面背景压糊来省体积。

## 母版

母版 PNG 还在压缩提交 `8be73223` 的父版本里（`8be73223^` 的 `project/assets/art`，6200 张 PNG）。`tools/art/restore_shipping_quality.py` 读这些 PNG，写成 WebP quality 92、method 6，像素尺寸与母版相同。纸娃娃是无损 WebP（导入 `compress/mode=0`），这一轮不动。没有母版的文件不从现有 WebP 再压一次，只把导入质量抬到 0.92，避免引擎再抹一层。

以后农场交 PNG。`tools/art/compress_shipping_webp.py` 的照片质量锁在 `PHOTO_QUALITY = 0.92`，`shipping_size` 原样返回宽高。不要再把 1920 的背景裁到 1280，也不要回到 0.74 / 0.76 / 0.78。

## 体积

省字节只走按需包。基因立绘库 `project/assets/art/portraits/genome/bank/` 仍以 q92 留在仓库里，两个导出预设用 `*portraits/genome/bank/*` 把它排除在基础包之外。安装包放在：

- `user://packs/gene-bank/assets/art/...`（与 `res://` 后的相对路径相同）
- 或可执行文件旁边的 `packs/gene-bank/assets/art/...`

`CKArtPacks` 在 `res://` 找不到文件时走这两处。编辑器和带仓库的运行仍直接读 `res://`。基础包没有基因库时，`CKPortraitBank` 保持原有的空库回退。

雇佣脸、具名半身、城图、场景、城堡、领地、战斗背景都留在基础包里，并且是 q92 原尺寸。

## 前后

`tools/ci/webp_sharpness_report.json`。有损照片 3681 张全部从母版重编码，0 张缺母版，139 张纸娃娃保持无损未改。这 3681 张从 145.1 MB 增到 334.1 MB。RMSE 是相对母版的均方根误差，越低越接近原图。

| 样本 | 重编码前 | q92 之后 | RMSE 前 → 后 |
|---|---|---|---|
| 基因库 `elder_0133cd4f080bf504` | 768×1024，58 KB | 768×1024，142 KB | 3.35 → 2.17 |
| `hireuniq_376` | 220×270，4.4 KB | 220×270，12.5 KB | 3.08 → 1.82 |
| `hireface_wheat_pine_m_cheek_thick` | 160×192，4.0 KB | 160×192，5.7 KB | 3.83 → 2.88 |
| 城图 `v87_city_eo_archive` | 1280×720，202 KB | 1280×720，378 KB | 5.67 → 3.76 |
| 场景 `v8_scene_ch0_pass` | 1280×720，83 KB | 1280×720，261 KB | 4.36 → 2.73 |
| 城堡 `v92_castle_academy_t1` | 1280×720，188 KB | 1280×720，294 KB | 4.65 → 2.84 |
| 领地 `v92_estate_ashbanner_g1` | 1280×720，249 KB | 1280×720，411 KB | 5.23 → 3.22 |
| 战斗地貌 `v8_battle_biome_archive` | 1280×726，166 KB | 1920×1088，584 KB | 6.43 → 2.94 |
| 界面背景 `battle_backdrop` | 1280×726，82 KB | 1920×1088，445 KB | 6.89 → 3.11 |

Godot 导入从 `lossy_quality` 0.74–0.78 改为 0.92，并且 `compress/high_quality=true`。加载器用 `Image.load_from_file` 读这份 q92 文件；导入质量不再把同一张图再压软一档。

基础导出（基因库除外）255,989,322 字节，预算 300,000,000，通过。被排除的基因库约 223 MB，是 q92 原尺寸，不是缩过的副本。

## m173

这一轮不需要重画脸。若以后某张板在 m173 上重出，把 PNG 交进农场入库，再跑现在的压缩脚本。它不会降质量，也不会缩小。基因库若要进玩家机器，打 `gene-bank` 包，不要把 q92 文件再压回 q78 塞进基础包。
