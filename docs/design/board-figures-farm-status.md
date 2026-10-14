# Board figures farm status (2026-10-14)

## Blocker

GeneRanch farm host `192.168.9.244` (Qwen :8322 / SenseNova :8329 / Hunyuan3D) is reached only via **m173** (`ea57a68e-3181-4765-a112-852a6cab095d`). At authoring time ListMachines reported m173 **disconnected**, so Qwen concept → Hunyuan3D rough GLB jobs could not be submitted.

## What shipped instead

Blender 4.2 on the agent box authored modular formal parts:

- `project/assets/models/board/board_figures_v1.glb` + `board_figures_v1.json`
- Proportions locked to pawn-redesign-opus §3.2 (5.45 heads, vertex-colour palette slots, 18-bone schema)
- Assembled estimates ~1.8k–2.1k tris/unit (under 7k cap; headroom for Hunyuan polish detail)

## Resume farm polish

1. Reconnect m173.
2. Drop Qwen orthographic turnarounds under `tools/models/board_parts/farm_inbox/`.
3. Submit Hunyuan jobs with existing `farm_out/ck_farm.ps1` / GeneRanch ports.
4. Retopo/bake in Blender; place same-named `.blend` overrides in `tools/models/board_parts/` and re-run `tools/models/board_figures_v1.py`.
5. Re-export GLB; CI `board_figure_check` + gate must stay green.

ETA once m173 is online: concept batch ~2–4h wall, Hunyuan+retopo polish ~1 day for t1 kit (leader/hunter/bandit), full P4 coverage ~3–5 days.
