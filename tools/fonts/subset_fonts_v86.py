#!/usr/bin/env python3
"""v8.6: subset Noto Sans CJK SC (Regular/Bold, OFL) to every char the game uses + GB2312 + ASCII.
Output: project/assets/fonts/NotoSansSC-{Regular,Bold}-ck.otf ; JetBrains Mono (OFL) copied for numerics."""
import pathlib, shutil, subprocess, sys
from fontTools.ttLib import TTCollection
from fontTools import subset
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "project/assets/fonts"; OUT.mkdir(parents=True, exist_ok=True)
chars = set(chr(c) for c in range(0x20, 0x7f))
for ext in ("*.json", "*.gd", "*.tscn", "*.txt", "*.csv", "*.md"):
    for p in (ROOT / "project").rglob(ext):
        if ".godot" in p.parts: continue
        try: chars |= set(p.read_text(encoding="utf-8"))
        except Exception: pass
# GB2312 level 1+2
for hi in range(0xB0, 0xF8):
    for lo in range(0xA1, 0xFF):
        try: chars.add(bytes([hi, lo]).decode("gb2312"))
        except Exception: pass
chars |= set("·—…“”‘’《》「」『』【】、，。！？：；（）～￥％＋－×÷＝＜＞★☆●○◆◇■□▲△▼▽→←↑↓")
text = "".join(sorted(c for c in chars if c.isprintable()))
print("chars", len(text))
for w in ("Regular", "Bold"):
    col = TTCollection(f"/usr/share/fonts/opentype/noto/NotoSansCJK-{w}.ttc")
    f = col.fonts[2]  # SC
    opts = subset.Options(); opts.layout_features = ["*"]; opts.name_IDs = ["*"]; opts.notdef_outline = True
    s = subset.Subsetter(opts); s.populate(text=text); s.subset(f)
    dst = OUT / f"NotoSansSC-{w}-ck.otf"; f.save(dst); print(dst, dst.stat().st_size)
jb = pathlib.Path("/usr/share/fonts/truetype/sand-box/google/JetBrains Mono/JetBrainsMono-VariableFont_wght.ttf")
if jb.exists(): shutil.copy2(jb, OUT / "JetBrainsMono-Variable.ttf")
(OUT / "LICENSE-OFL.txt").write_text("Noto Sans CJK SC and JetBrains Mono are licensed under the SIL Open Font License 1.1.\n")
