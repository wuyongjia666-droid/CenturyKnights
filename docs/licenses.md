# 第三方许可

百年骑士的系统、文本、界面与代码为项目原创。本页只登记仓库里实际打包的第三方字体。对战棋类型的致敬停留在规则层，不包含其他作品的名称、角色、图像或音频。

字体文件在 `project/assets/fonts/`。短声明也写在 `project/assets/fonts/LICENSE-OFL.txt`。

## Noto Sans CJK SC

| 文件 | 全名 |
| --- | --- |
| `NotoSansSC-Regular-ck.otf` | Noto Sans CJK SC |
| `NotoSansSC-Bold-ck.otf` | Noto Sans CJK SC Bold |

- 版权：© 2014-2021 Adobe（http://www.adobe.com/）
- 许可：SIL Open Font License 1.1
- 说明：仓库中的文件是按本项目用字（含 GB2312）切出的子集，不是完整 CJK 字库。子集由 `tools/fonts/subset_fonts_v86.py` 生成。

## JetBrains Mono

| 文件 | 全名 |
| --- | --- |
| `JetBrainsMono-Variable.ttf` | JetBrains Mono |

- 版权：© 2020 The JetBrains Mono Project Authors（https://github.com/JetBrains/JetBrainsMono）
- 许可：SIL Open Font License 1.1
- 用途：数字与等宽读数。界面中文仍走 Noto Sans CJK SC。

## SIL Open Font License 1.1

上述三份字体软件均以 SIL OFL 1.1 授权，按「原样」提供，不含任何明示或暗示的担保。许可原文与问答：https://scripts.sil.org/OFL

游戏内制作人员页（`scenes/ui/credits.tscn`）列出同一批文件。主菜单入口由核心流 CORE-06 接到主菜单，本页不改 `main_menu.gd`。

## 曲库（程序化原创）

全部曲目由仓库内 `tools/audio/compose_v92.py` 以固定种子 `9202601` 程序化合成。没有第三方采样、录音或曲库。编码为双声道 44.1 kHz Ogg Vorbis（libvorbis quality 1）。重跑该脚本必须得到逐字节相同的文件。Ogg 页序列号在合成后被改写为曲目种子，以去掉 ffmpeg 的随机序列号。

曲目文件在 `project/assets/music/`。逐文件 sha256 以 `project/assets/music/LICENSES.md` 为准，下表是用途摘要。

| 文件 | 用途 |
| --- | --- |
| `mus_title.ogg` | 主菜单 / 标题 |
| `mus_castle_spring.ogg` | 城堡·春生 |
| `mus_castle_summer.ogg` | 城堡·夏澄 |
| `mus_castle_autumn.ogg` | 城堡·秋落 |
| `mus_castle_winter.ogg` | 城堡·冬静 |
| `mus_atlas.ogg` | 舆图 |
| `mus_atlas_ashbanner.ogg` | 舆图·灰烬邦 |
| `mus_atlas_shuoying.ogg` | 舆图·朔影国 |
| `mus_atlas_qinghe.ogg` | 舆图·清河国 |
| `mus_atlas_lantern.ogg` | 舆图·灯市联 |
| `mus_atlas_frostcrown.ogg` | 舆图·霜冕廷 |
| `mus_atlas_emberold.ogg` | 舆图·余烬旧邦 |
| `mus_atlas_saltmarsh.ogg` | 舆图·盐泽盟 |
| `mus_atlas_irongorge.ogg` | 舆图·铁峡领 |
| `mus_atlas_starriver.ogg` | 舆图·星津邦 |
| `mus_atlas_southzephyr.ogg` | 舆图·南泽邦 |
| `mus_battle_era1.ogg` | 纪元一·灯起，玩家回合 |
| `mus_battle_era2.ogg` | 纪元二·霜盟，玩家回合 |
| `mus_battle_era3.ogg` | 纪元三·裂桥，玩家回合 |
| `mus_battle_era4.ogg` | 纪元四·冕战，玩家回合 |
| `mus_battle_era5.ogg` | 纪元五·百年，玩家回合 |
| `mus_battle_enemy.ogg` | 敌方回合 |
| `mus_battle_boss.ogg` | 首领 |
| `mus_tension.ogg` | 紧张段落 |
| `mus_tension_layer.ogg` | 叠在战斗曲下的紧张层 |
| `mus_victory.ogg` | 胜利 |
| `mus_defeat.ogg` | 失败 |
| `mus_marriage.ogg` | 联姻 |
| `mus_funeral.ogg` | 葬礼 / 先祖 |
| `mus_birth.ogg` | 初啼 |
| `mus_inheritance.ogg` | 继承 |
| `mus_city_ashbanner.ogg` | 城市·灰烬邦 |
| `mus_city_shuoying.ogg` | 城市·朔影国 |
| `mus_city_qinghe.ogg` | 城市·清河国 |
| `mus_city_lantern.ogg` | 城市·灯市联 |
| `mus_city_frostcrown.ogg` | 城市·霜冕廷 |
| `mus_city_emberold.ogg` | 城市·余烬旧邦 |
| `mus_city_saltmarsh.ogg` | 城市·盐泽盟 |
| `mus_city_irongorge.ogg` | 城市·铁峡领 |
| `mus_city_starriver.ogg` | 城市·星津邦 |
| `mus_city_southzephyr.ogg` | 城市·南泽邦 |

界面里的曲名文案在 `project/data/locale/audio.csv`，由 `locale.gd` 登记后经 `Locale.t` 读取。

## 音效（程序化原创）

`project/assets/sfx/` 里由 `tools/audio/sfx_v92.py` 生成的文件（`hit_*`、`step_*`、`ui_hover`、`ui_back`、`ui_deny`、`ui_open`、`ui_close`、`amb_*.ogg`）是本仓库的原创合成，种子 `9202601`，没有第三方采样或曲目。清单和校验在 `project/assets/sfx/catalog_v92.json`。

其余 `*.wav` 是更早的程序化短音效，同样不包含外部采样。其中三段 `music_*.wav` 只作为 OGG 曲库缺失时的回退。

`project/assets/sfx/barks/` 里的 16 段呼喊由 `tools/audio/barks_v92.py` 合成（气声、喝声，按性别和年龄段），同样没有外部采样。清单在 `project/assets/sfx/barks/catalog_barks.json`。

来源说明仍留在 `project/assets/sfx/LICENSES.md` 与 `project/assets/music/LICENSES.md`（属音频流）。本页是汇总。
