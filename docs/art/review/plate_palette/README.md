# 立绘图版调色核对样张（P0）

由 `tools/art/plate_palette.py` 生成（方案 §3.3 / 附录 C）。

- 每约 100 张图版一页 `sheet_XXXX.jpg`：立绘缩略图 + 发/肤/外套/内衬/围巾/金属色块 + 发型猜测。
- `!` 标记表示 `needs_review`（发型置信度低或分区失败），请人工改 `project/data/plate_palette_overrides.json` 后重跑脚本（`--resume` 可保留未改项）。
- 运行时棋子只按 `CKPortraitBank.try_texture` 返回的 stem 查 `plate_palettes.json`，不重新匹配。
