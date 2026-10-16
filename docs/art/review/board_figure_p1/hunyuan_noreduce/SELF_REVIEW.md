# SELF_REVIEW — cast_leader board normalize-only / 不减面 (2026-10-16)

## Verdict
**PASS for shatter bar** (vs prior 38k / ~140k soft-COLLAPSE fails).  
User chose: **不减面** — original Hunyuan full-body, normalize only. No COLLAPSE/DECIMATE/remesh.

Executor visually Read `figure_front.png`, `figure_35deg.png`, `face_closeup.png`, `compare_face_src_vs_board.png`.

## Numbers
| Item | Value |
|---|---|
| Source | `captain_farm_front_fullbody.glb` |
| Import tris | **1499054** |
| Export tris | **1499054** (unchanged) |
| GLB size | ~75MB (`78235108` bytes) |
| Height | 1.85m, feet z=0, face −Y (180° yaw applied) |
| Asset | `project/assets/models/units/cast_leader__board.glb` |
| Script | `tools/models/normalize_hunyuan_fullbody_board.py` |

## Checklist vs success bar
| Bar | Result | Notes |
|---|---|---|
| Triangle count ≈ source (~1.5M) | **PASS** | 1499054 → 1499054 |
| Coherent full figure | **PASS** | Front + 35°: upright, grounded, silhouette readable, no shard coat |
| Face readable vs Hunyuan `face_src` | **PASS (parity)** | Closeup matches source fidelity; compare shows noreduce ≥ `board_ready_v2` face_src sharpness. Residual **hairline/forehead dark seam** appears on **both** sides of compare → source Hunyuan seam, not reduce damage |
| Coat solid (not shattered) | **PASS** | Smooth continuous coat/collar; no fragment shards like 38k/140k |

## Honest caveats
- This is **full 1.5M tris / ~75MB** — heavy for runtime; board LOD later still needs a **non-shatter** path (real retopo/bake), not soft COLLAPSE.
- Do **not** soft-COLLAPSE this mesh again expecting quality to “barely drop.”
- Hair–scalp dark seam is in the Hunyuan source; normalize-only cannot invent closed hair cards.

## Reviews in this folder
- `figure_front.png`, `figure_35deg.png`, `face_closeup.png`
- `face_src.png` (same camera on full-tris = identical to closeup here)
- `compare_face_src_vs_board.png` (LEFT = `board_ready_v2/face_src.png`, RIGHT = this closeup)
- `cast_leader__board.glb`, `META.txt`
