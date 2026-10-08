# 程序化音效许可

本目录里由 `tools/audio/sfx_v92.py` 生成的文件（`hit_*`、`step_*`、`ui_hover`、`ui_back`、`ui_deny`、`ui_open`、`ui_close`、`amb_*.ogg`）是本仓库的原创合成，种子 `9202601`，没有第三方采样或曲目。清单和校验在 `catalog_v92.json`。

其余 `*.wav` 是更早的程序化短音效，同样不包含外部采样。其中三段 `music_*.wav` 只作为 OGG 曲库缺失时的回退。

汇总进 `docs/licenses.md` 时请 UX 流带上这一段。曲库说明见 `project/assets/music/LICENSES.md`。

`barks/` 里的 16 段呼喊由 `tools/audio/barks_v92.py` 合成（气声、喝声，按性别和年龄段），同样没有外部采样。清单在 `barks/catalog_barks.json`。
