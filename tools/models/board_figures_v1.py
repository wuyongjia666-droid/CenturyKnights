#!/usr/bin/env python3
"""P1 skeleton: Blender 4.2 board-figure generator (pawn-redesign-opus §5 / 附录 A).

P0 delivered style-lock, plate_palettes, try_texture stem, and gate baseline.
This module is the entry for P1 formal assets — do NOT treat farm_cast whole meshes
as the final kit (#301 rejected; #309 farm colouring is temporary).

Planned outputs (not built in P0):
  - body m/f (+ heavy), head blocks, 8 hair LODs, t1 outfits/weapons, bandit set
  - vertex colour slots (R=palette, G=AO, B=flags), 4–6k tris/figure, 0 textures
  - export assets/models/board/board_figures_v1.glb + board_figures_v1.json
  - data/board_figures.json job→part map

Run (P1): blender --background --python tools/models/board_figures_v1.py
"""
from __future__ import annotations

import sys


def main() -> int:
    print(
        "board_figures_v1: P0 placeholder — implement Blender generator in P1 "
        "(docs/design/pawn-redesign-opus.md §5). Refusing to emit farm_cast stand-ins."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
