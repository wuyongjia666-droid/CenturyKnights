# board_parts

Hand-authored / organic overrides for the formal board-figure kit (`tools/models/board_figures_v1.py`).

## compose_* (P1 organic formal)

Built by `tools/models/build_organic_board_overrides.py` from `project/assets/models/board/farm_cast/`
(Hunyuan retopo LOD): head enlarge, face metaball enhance, FLOAT_COLOR slot paint, ≤7k tris, 0 textures.

| file | used by |
|------|---------|
| `compose_captain.glb` | captain / leader |
| `compose_hunter.glb` | hunter / archer / marksman |
| `compose_bandit_*.glb` | enemy templates weak/bandit/archer/chief |

Wire via `compose` in `project/data/board_figures.json`. Assembler skips body/head/hair/outfit when set.

## other overrides

Drop a `.glb` / `.gltf` / `.blend` whose **stem matches a generated part name**
(e.g. `head_m.glb`). The generator replaces the scripted part.

`farm_inbox/` holds raw Hunyuan GLBs (gitignored large sources). Do not treat them as the formal kit.

Rebuild:
```bash
blender --background --python tools/models/build_organic_board_overrides.py
blender --background --python tools/models/board_figures_v1.py -- --out project/assets/models/board
```
