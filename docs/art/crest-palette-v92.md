# 霜纹章色板 v9.2

默认纹章 `#c9a227` 是暖金，过不了风格锁的 gold 门（色相 32–58°、饱和度 > 0.42）。旗帜组改由下面 7 个霜色生成。`tools/art/recolor_banners_v92.py` 只改金色布料像素的色相，把饱和度压到 0.34 以下，再按 `style_check_v87.py` 的 icon 门禁检查。

| 十六进制 | 名字 | 用途 |
| --- | --- | --- |
| `#6ED4FF` | 主霜 | 新局建议默认色，也是缺图时的回退旗帜 |
| `#9BE4FF` | 霜雾 | 浅一档 |
| `#3AADDF` | 深霜 | 压暗 |
| `#5EE0B5` | 薄荷 | 友方点缀 |
| `#C9D3DE` | 霜银 | 旧 `#c9a227` 的迁移目标 |
| `#2E6F8F` | 潮蓝 | 深色队 |
| `#D7F4FF` | 冰白 | 最浅 |

## 迁移

旧色到新色用 CIE76 Lab 距离。`#c9a227` 的 Lab 大约是 L 68、a 3、b 64，七色里最近的是霜银 `#C9D3DE`。

`UnitArt.migrate_crest_hex("c9a227")` 返回 `c9d3de`，所以旧存档和仍传入 `#c9a227` 的测试会去加载 `banner_c9d3de_wN.png`。文件名里不再出现 `c9a227`。

## 交接

这两处默认值还是 `#c9a227`，本卡不改：

- `project/autoload/game_state.gd` 约第 496 行和第 3178 行（core）。新局默认请改成 `#6ED4FF`。读档时若仍是 `#c9a227`，可写成 `#C9D3DE`，与上面的映射一致。
- `project/scripts/story/naming.gd` 的 `_colors`（narrative）。请去掉 `#c9a227`，改用本表 7 色。

`campaign_sim.gd` 和各测试仍显式传入 `#c9a227`。那是模拟入参，不是旗帜文件名。改它会动种子 91 的百年数字，所以留给对应的流。
