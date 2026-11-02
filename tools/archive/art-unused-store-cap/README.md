# art-unused-store-cap

Unused farm plates archived 2026-11-03 (Asia/Shanghai) for Android CAP≤400.

- `project/assets/art/estates/v92_estate_*.webp` — runtime never loads these; holdings use `<holding_id>.png`.
- `project/assets/art/scenes/v92_scene_*.webp` — runtime uses `v8_scene_*` via `AtlasArt.scene_plate`.

Relative paths preserved. Do not rewrite git history. Re-ingest from farm queues may recreate files under `project/assets/`; export_presets exclude globs block them from shipping packs.

Manifest: `docs/art/unused-store-cap-archive.json`.
