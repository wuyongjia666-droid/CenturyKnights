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
