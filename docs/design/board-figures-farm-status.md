# Board figures farm status (2026-10-15)

## Current

- m173 (`ea57a68e-3181-4765-a112-852a6cab095d`) is **connected as a relay**, but GeneRanch Comfy ports on `192.168.9.244` are **down**:
  - ping 192.168.9.244 OK (~1ms)
  - TCP **CLOSED**: 8322 (Qwen), 8326/8327/8328 (H3/Hunyuan), 8329 (SenseNova)
  - only **8330** open (aic-audio / cut), not usable for stills or Hunyuan3D
- SSH to 192.168.9.244:22 is open; m173’s `id_rsa` is **not** authorized (`Permission denied`). Cannot remote-start Comfy from here.
- Do **not** merge PR #301 (user rejected that Blender body).

## Batch prepared (ready to submit when :8322 is up)

Local (box): `/workspace/farm_board_fig_t1/` (+ `farm_board_fig_t1.tgz`)

Intended on m173: `D:\AIComics\CenturyKnights_farm\board_fig_t1\`

Generator: `tools/farm_v87/gen_board_figures_qwen.py` (Opus v2 立绘同源写实棋子 prompts, 5.45 heads / empty-hand A-pose sheets).

| Job | Side | Ref |
|---|---|---|
| bf_leader_m / bf_leader_f | ally | FARM-04 opening leader plates |
| bf_hunter_m / bf_hunter_f | ally | v8 hunter busts |
| bf_bandit / bf_bandit_archer / bf_bandit_chief / bf_bandit_weak | enemy | bandit bust / text |
| bf_base_body_m/f | — | bald mannequin |
| bf_outfit_{leader_coat,hunter,light_inf}_t1_{m,f} | ally | bald + outfit |

**16 Qwen jobs** → then `gen_hunyuan_v87.py out hy_batch` on :8327 → Blender retopo into `tools/models/board_parts/` → `board_figures_v1.py` (overrides only; not #301 mesh as-is).

### Submit (on m173, once :8322 answers `/system_stats`)

```powershell
cd D:\AIComics\CenturyKnights_farm\board_fig_t1
powershell -File farm.ps1 submit .
powershell -File farm.ps1 watch .
# after sheets land:
python gen_hunyuan_v87.py out hy_batch
powershell -File farm.ps1 submit hy_batch
powershell -File farm.ps1 watch hy_batch
```

Or: `powershell -File submit_when_ready.ps1` (polls :8322 every 60s up to 12h).

## ETA (clock starts when :8322 is up)

| Stage | Wall |
|---|---|
| Qwen concept sheets (16) | ~2–4 h |
| Hunyuan rough GLB + Blender retopo for t1 (leader/hunter/bandit) | ~1 day |
| Full P4 class coverage | ~3–5 days |

## Human board

Yes — after Qwen sheets: visual gate (style lock, A-pose, feet/head not cropped, identity vs portrait). After Hunyuan: pick best GLB per kit before retopo. User reviews t1 kit A/B in-game before P4 spread.
