# 立绘锐度 v9.2

q78 的出货 WebP 把脸压软了，Godot 导入再按同样的 `lossy_quality` 压一遍。这一轮从母版重编码，不缩分辨率，也不靠把城图、场景或界面背景压糊来省体积。

## 母版

母版 PNG 还在压缩提交 `8be73223` 的父版本里（`8be73223^` 的 `project/assets/art`，6200 张 PNG）。`tools/art/restore_shipping_quality.py` 读这些 PNG，写成 WebP quality 92、method 6，像素尺寸与母版相同。纸娃娃是无损 WebP（导入 `compress/mode=0`），这一轮不动。没有母版的文件不从现有 WebP 再压一次，只把导入质量抬到 0.92，避免引擎再抹一层。

以后农场交 PNG。`tools/art/compress_shipping_webp.py` 的照片质量锁在 `PHOTO_QUALITY = 0.92`，`shipping_size` 原样返回宽高。不要再把 1920 的背景裁到 1280，也不要回到 0.74 / 0.76 / 0.78。

## 体积

省字节不靠把脸压软，也不把基因库拆成外置包。基因立绘库 `project/assets/art/portraits/genome/bank/` 以 q92 原尺寸留在仓库里，并且打进 Windows 和 Android 的基础导出。安装包是一份离线完整的包，不读 `user://packs/gene-bank`，也不读可执行文件旁边的 `packs/gene-bank`。

同一张脸另有两档，在导出前用 Lanczos 从这张 q92 板生成，再按质量 92 编码。运行时按界面去取，缺档就退回更大的一档，不在运行时把软图缩小。

| 档 | 相对母版 | 768×1024 的像素 | 用在哪 |
|---|---|---|---|
| small | 1/2 | 384×512 | 名册、列表、战棋棋子 |
| medium | 2/3 | 512×682 | 对话、半身 |
| large | 1 | 768×1024（现有文件） | 档案详情 |

已经小于 640px 长边的雇佣脸不再缩。再缩一档会比现在更糊。状态叠层仍是对齐半身板的透明图，界面把它铺在当前这档立绘上。

`tools/art/build_portrait_tiers.py` 写 `名字.small.webp` 和 `名字.medium.webp`，并带上 `lossy_quality=0.92` 的导入。体积数字在 `tools/ci/portrait_tiers_report.json` 和导出报告里。

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

基础导出含基因库和 small / medium 档。按源文件计，约 663,942,234 字节（基因库大档仍是 q92 原尺寸，small 约 62 MB，medium 约 108 MB）。预算写在 `tools/ci/ratchet.json` 的 `export_budget_bytes`，由 `tools/ci/export_size_report.py` 按两个预设的排除规则计源文件字节。

## m173

这一轮不需要重画脸。若以后某张板在 m173 上重出，把 PNG 交进农场入库，再跑现在的压缩脚本。它不会降质量，也不会缩小母版。新的大板入库后跑 `tools/art/build_portrait_tiers.py`，补上 small 和 medium。不要把 q92 母版再压回 q78，也不要把它排除出基础包。
