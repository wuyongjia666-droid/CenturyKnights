# board_parts

Hand-authored overrides for the formal board-figure kit (`tools/models/board_figures_v1.py`).

- Drop a `.glb` / `.gltf` / `.blend` whose **stem matches a generated part name**
  (e.g. `outfit_captain.glb`, `head_m.blend`). The generator replaces the scripted part.
- `farm_inbox/` is for temporary Hunyuan/Qwen whole-mesh casts only (gitignored). Those are
  **not** the formal kit — do not treat farm casts as P1 deliverables (#301 rejected; #309 temporary).

Rebuild:
```bash
blender --background --python tools/models/board_figures_v1.py -- --out project/assets/models/board
```

Formal outputs:
- `project/assets/models/board/board_figures_v1.glb`
- `project/assets/models/board/board_figures_v1.json`
- mapping: `project/data/board_figures.json`
