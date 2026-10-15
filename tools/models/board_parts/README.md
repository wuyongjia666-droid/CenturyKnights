# board_parts

- `farm_inbox/` — drop raw Hunyuan/Qwen farm GLBs here (local only; large files gitignored).
- Processed board-ready casts live in `project/assets/models/board/farm_cast/` (≤7k tris, 1.85m).
- Do **not** merge PR #301 (rejected modular Blender body). Farm cast overrides are whole-mesh.

Retopo:
```bash
blender -b -P tools/models/retopo_farm_hunyuan.py -- \
  tools/models/board_parts/farm_inbox/hy_leader_m.glb \
  project/assets/models/board/farm_cast/leader_m.glb 5500
```
