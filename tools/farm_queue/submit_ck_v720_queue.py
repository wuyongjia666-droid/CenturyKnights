#!/usr/bin/env python3
"""Submit CenturyKnights v7.20 farm stills when m173 LAN is up.
Prefer Qwen :8322; dual_submit to SenseNova local :8329.
Never SN cloud API / Qwen *Api nodes / Flux.
Uses aic-farm dual_submit_stills when available; else posts Comfy /prompt stubs.
"""
from __future__ import annotations
import json, os, sys, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = Path(__file__).with_name("shots_v720.json")
QWEN = os.environ.get("COMFYUI_QWEN", "http://192.168.9.244:8322")
SN = os.environ.get("COMFYUI_SN", "http://192.168.9.244:8329")
AIC_DUAL = Path("/workspace/pipe-qwen-21-landing/skills/aic-farm/scripts/dual_submit_stills.py")

def http_ok(url: str, timeout: float = 4.0) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return 200 <= r.status < 300
    except Exception as e:
        print(f"  FAIL {url}: {e}")
        return False

def main() -> int:
    data = json.loads(SHOTS.read_text(encoding="utf-8"))
    print(f"[ck-farm] round={data['round']} shots={len(data['shots'])}")
    print(f"[ck-farm] probe Qwen={QWEN} SN={SN}")
    q_ok = http_ok(f"{QWEN}/system_stats") or http_ok(f"{QWEN}/v1/models")
    s_ok = http_ok(f"{SN}/system_stats")
    if not q_ok:
        print("[ck-farm] Qwen :8322 unreachable — abort submit; keep queue on disk")
        print(f"  queue file: {SHOTS}")
        return 2
    if not s_ok:
        print("[ck-farm] SenseNova :8329 unreachable — dual_submit incomplete; prefer wait or retry")
        # Prefer dual; do not silently single-side unless forced
        if os.environ.get("CK_FARM_ALLOW_QWEN_ONLY") != "1":
            print("  set CK_FARM_ALLOW_QWEN_ONLY=1 to force Qwen-only (not default)")
            return 3
    # Prefer aic-farm dual_submit if present
    if AIC_DUAL.exists() and q_ok and s_ok:
        print(f"[ck-farm] dual_submit via {AIC_DUAL}")
        print("  NOTE: dual_submit expects BOOK root layout; staging shots JSON for human/m173 run")
        out = ROOT / "tools/farm_queue/READY_TO_SUBMIT.json"
        out.write_text(json.dumps({"qwen": QWEN, "sn": SN, "shots": data["shots"], "mode": "dual_local"}, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  wrote {out} — run on m173 under aic-farm when operator ready")
        return 0
    # Minimal Comfy queue ticket for operator
    ticket = ROOT / "tools/farm_queue/READY_TO_SUBMIT.json"
    ticket.write_text(json.dumps({
        "status": "queued_local",
        "qwen": QWEN,
        "sn_local": SN,
        "prefer": "qwen",
        "dual": True,
        "shots": data["shots"],
        "dest_hint": "project/assets/art/farm_inbox/",
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[ck-farm] ticket ready: {ticket}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
