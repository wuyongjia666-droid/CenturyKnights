#!/usr/bin/env python3
"""One-shot submit of CenturyKnights v9.2 FARM-01..05 stills.

Converts tools/farm_queue/v92_*.json and genome_bank_v92.json into the
list dual_submit_stills.load_shots accepts: a JSON array of shot objects.
Each object carries ``label`` (the name load_shots reads) and the same string
in ``id``. The file is not a ``{"shots": [...]}`` envelope.
When both farm hosts are up, runs:

  dual_submit_stills.py --root ROOT --shots-json SHOTS --spread --sn-backend local --only both

Qwen-only is not a CLI switch. It runs solely when SenseNova :8329 is down
and CK_FARM_ALLOW_QWEN_ONLY=1. SenseNova cloud / api backends are never selected.

Dry-run does not probe the LAN and does not call dual_submit:

  python3 tools/farm_queue/submit_v92_stills.py --dry-run
  python3 tools/farm_queue/validate_queue_v92.py
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_queue_v92 as gate  # noqa: E402

QWEN_DEFAULT = "http://192.168.9.244:8322"
SN_DEFAULT = "http://192.168.9.244:8329"
ESCAPE_ENV = "CK_FARM_ALLOW_QWEN_ONLY"
FARM_ORDER = ("FARM-01", "FARM-02", "FARM-03", "FARM-04", "FARM-05")
KIND_FARM = {
    "genome": "FARM-01",
    "city": "FARM-02",
    "smith": "FARM-03",
    "item": "FARM-03",
    "scene": "FARM-04",
    "expression": "FARM-04",
    "castle": "FARM-05",
    "estate": "FARM-05",
}
KIND_ORDER = {
    "FARM-01": ("genome",),
    "FARM-02": ("city",),
    "FARM-03": ("smith", "item"),
    "FARM-04": ("scene", "expression"),
    "FARM-05": ("castle", "estate"),
}
ROOT_CANDIDATES = (
    Path(r"D:\AIComics\CenturyKnights_farm"),
    Path(r"D:\CenturyKnights_farm"),
)
SCRIPT_CANDIDATES = (
    Path(r"D:\cursor-userdata\dot-cursor\skills\aic-farm\scripts\dual_submit_stills.py"),
    Path(r"C:\Users\m1736\.cursor\skills\aic-farm\scripts\dual_submit_stills.py"),
    Path("/workspace/pipe-qwen-21-landing/skills/aic-farm/scripts/dual_submit_stills.py"),
)


class Plan:
    def __init__(self, only: str, spread: bool, code: int, reason: str) -> None:
        self.only = only
        self.spread = spread
        self.code = code
        self.reason = reason


def allow_qwen_only(env: dict[str, str] | None = None) -> bool:
    source = os.environ if env is None else env
    return source.get(ESCAPE_ENV) == "1"


def decide_plan(qwen_ok: bool, sn_ok: bool, qwen_only_escape: bool) -> Plan:
    """Both hosts -> dual spread. Qwen-only only through the env escape hatch."""
    if not qwen_ok:
        return Plan("", False, 2, "Qwen :8322 unreachable — abort; queue stays on disk")
    if sn_ok:
        return Plan("both", True, 0, "both hosts up")
    if qwen_only_escape:
        return Plan("qwen", False, 0, f"{ESCAPE_ENV}=1 and SenseNova :8329 is down")
    return Plan(
        "",
        False,
        3,
        "SenseNova :8329 unreachable — set "
        f"{ESCAPE_ENV}=1 to submit Qwen only",
    )


def build_argv(python: str, dual: str, root: str, shots: str, plan: Plan) -> list[str]:
    argv = [python, dual, "--root", root, "--shots-json", shots]
    if plan.spread:
        argv.append("--spread")
    argv.extend(["--sn-backend", "local", "--only", plan.only])
    return argv


def job_to_shot(job: dict) -> dict:
    """Map one queue row onto a dual_submit_stills shot.

    dual_submit_stills.load_shots reads a list and the ``label`` field.
    ``id`` is the same string, kept so older notes still match the queue id.
    Style-lock fields are copied through unchanged so the farm does not
    invent a seed, a negative, or a sampler.
    """
    kind = str(job.get("kind", ""))
    farm = KIND_FARM.get(kind)
    if farm is None:
        raise ValueError(f"unknown kind {kind!r}")
    ident = str(job.get("id") or job.get("bucket_key") or "")
    if not ident:
        raise ValueError("job has no id or bucket_key")
    positive = str(job.get("positive", ""))
    if not positive:
        raise ValueError(f"{ident}: empty positive")
    width = int(job["width"])
    height = int(job["height"])
    shot = {
        "label": ident,
        "id": ident,
        "w": width,
        "h": height,
        "width": width,
        "height": height,
        "role": kind,
        "prompt": positive,
        "positive": positive,
        "negative": str(job["negative"]),
        "seed": int(job["seed"]),
        "steps": int(job["steps"]),
        "cfg": float(job["cfg"]),
        "sampler": str(job["sampler"]),
        "scheduler": str(job["scheduler"]),
        "out_path": str(job["out_path"]),
        "filename_prefix": ident,
        "farm": farm,
    }
    if job.get("edit"):
        shot["edit"] = str(job["edit"])
    if job.get("identity_ref"):
        shot["identity_ref"] = str(job["identity_ref"])
    return shot


def build_shots(jobs: list[dict], farms: set[str] | None = None) -> list[dict]:
    wanted = set(FARM_ORDER) if farms is None else set(farms)
    unknown = wanted - set(FARM_ORDER)
    if unknown:
        raise ValueError(f"unknown farms {sorted(unknown)}")
    grouped: dict[str, list[dict]] = {farm: [] for farm in FARM_ORDER}
    for job in jobs:
        shot = job_to_shot(job)
        if shot["farm"] in wanted:
            grouped[shot["farm"]].append(shot)
    ordered: list[dict] = []
    for farm in FARM_ORDER:
        if farm not in wanted:
            continue
        by_kind: dict[str, list[dict]] = {kind: [] for kind in KIND_ORDER[farm]}
        for shot in grouped[farm]:
            by_kind[shot["role"]].append(shot)
        for kind in KIND_ORDER[farm]:
            ordered.extend(by_kind[kind])
    labels = [shot["label"] for shot in ordered]
    if any(shot["label"] != shot["id"] for shot in ordered):
        raise ValueError("label and id diverged")
    if len(labels) != len(set(labels)):
        seen: set[str] = set()
        dupes = []
        for ident in labels:
            if ident in seen:
                dupes.append(ident)
            seen.add(ident)
        raise ValueError(f"duplicate shot label {dupes[:5]}")
    return ordered


def count_lines(shots: list[dict]) -> list[str]:
    lines = []
    for farm in FARM_ORDER:
        rows = [shot for shot in shots if shot["farm"] == farm]
        if not rows:
            continue
        kinds: dict[str, int] = {}
        for shot in rows:
            kinds[shot["role"]] = kinds.get(shot["role"], 0) + 1
        detail = " ".join(f"{kind}={kinds[kind]}" for kind in KIND_ORDER[farm] if kind in kinds)
        lines.append(f"  {farm} {detail} total={len(rows)}")
    return lines


def http_ok(url: str, timeout: float = 5.0) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            status = getattr(resp, "status", 200)
            return 200 <= status < 300
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"  FAIL {url}: {exc}")
        return False


def probe(qwen: str, sn: str) -> tuple[bool, bool]:
    qwen = qwen.rstrip("/")
    sn = sn.rstrip("/")
    print(f"[v92-farm] probe Qwen={qwen} SN={sn}")
    q_ok = http_ok(f"{qwen}/system_stats") or http_ok(f"{qwen}/v1/models")
    s_ok = http_ok(f"{sn}/system_stats")
    return q_ok, s_ok


def poll_once(base: str) -> str:
    url = base.rstrip("/") + "/queue"
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            body = resp.read().decode("utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return f"{url} FAIL {exc}"
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return f"{url} bytes={len(body)}"
    running = data.get("queue_running", [])
    pending = data.get("queue_pending", [])
    run_n = len(running) if isinstance(running, list) else "?"
    pend_n = len(pending) if isinstance(pending, list) else "?"
    return f"{url} running={run_n} pending={pend_n}"


def farm_root(explicit: str) -> Path:
    if explicit:
        return Path(explicit)
    env = os.environ.get("CK_FARM_ROOT", "")
    if env:
        return Path(env)
    for candidate in ROOT_CANDIDATES:
        if candidate.exists():
            return candidate
    return ROOT_CANDIDATES[0]


def find_dual(scripts: str) -> Path | None:
    candidates: list[Path] = []
    if scripts:
        folder = Path(scripts)
        candidates.append(folder / "dual_submit_stills.py" if folder.is_dir() else folder)
    env = os.environ.get("AIC_FARM_SCRIPTS", "")
    if env:
        folder = Path(env)
        candidates.append(folder / "dual_submit_stills.py" if folder.is_dir() else folder)
    candidates.extend(SCRIPT_CANDIDATES)
    for path in candidates:
        if path.is_file():
            return path
    return None


def parse_farms(text: str) -> set[str]:
    farms = {part.strip() for part in text.split(",") if part.strip()}
    if not farms:
        raise ValueError("empty --farms")
    unknown = farms - set(FARM_ORDER)
    if unknown:
        raise ValueError(f"unknown farms {sorted(unknown)}; expected {','.join(FARM_ORDER)}")
    return farms


def write_shots(path: Path, shots: list[dict]) -> None:
    """Write the load_shots file: a JSON list, never a {shots: ...} object."""
    if not isinstance(shots, list):
        raise TypeError("shots file must be a JSON list")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(shots, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Submit v9.2 FARM-01..05 stills via dual_submit_stills")
    parser.add_argument("--dry-run", action="store_true", help="validate and convert; do not probe or submit")
    parser.add_argument("--poll", action="store_true", help="print /queue depth on both hosts and exit")
    parser.add_argument("--root", default="", help="farm output root passed to dual_submit --root")
    parser.add_argument("--scripts", default="", help="directory that contains dual_submit_stills.py")
    parser.add_argument("--shots-out", default="", help="where to write the shots JSON (submit default: <root>/shots_v92_farm.json)")
    parser.add_argument("--farms", default=",".join(FARM_ORDER), help="comma list, default FARM-01..05")
    parser.add_argument("--qwen", default=os.environ.get("COMFYUI_QWEN", QWEN_DEFAULT))
    parser.add_argument("--sn", default=os.environ.get("COMFYUI_SN", SN_DEFAULT))
    args = parser.parse_args(argv)

    if args.poll and not args.dry_run:
        print(poll_once(args.qwen))
        print(poll_once(args.sn))
        return 0

    try:
        farms = parse_farms(args.farms)
    except ValueError as exc:
        print(f"FAIL {exc}")
        return 1

    errors = gate.check()
    if errors:
        for err in errors[:40]:
            print("FAIL", err)
        print(f"QUEUE FAIL errors={len(errors)}")
        return 1

    jobs, names = gate.collect_jobs()
    try:
        shots = build_shots(jobs, farms)
    except (ValueError, KeyError, TypeError) as exc:
        print(f"FAIL convert {exc}")
        return 1
    if not shots:
        print("FAIL no shots after farm filter")
        return 1

    print(f"[v92-farm] files={len(names)} queue_jobs={len(jobs)} shots={len(shots)} shape=list")
    for line in count_lines(shots):
        print(line)

    if args.dry_run:
        if args.shots_out:
            dest = Path(args.shots_out)
            write_shots(dest, shots)
            print(f"[v92-farm] wrote {dest}")
        plan = decide_plan(True, True, False)
        shown = build_argv(
            sys.executable,
            "dual_submit_stills.py",
            str(farm_root(args.root)),
            str(args.shots_out or "<root>/shots_v92_farm.json"),
            plan,
        )
        print("[v92-farm] would run:", " ".join(shown))
        print("DRY-RUN PASS shots=%d hosts_not_contacted=1" % len(shots))
        return 0

    q_ok, s_ok = probe(args.qwen, args.sn)
    plan = decide_plan(q_ok, s_ok, allow_qwen_only())
    print(f"[v92-farm] plan only={plan.only or '-'} spread={int(plan.spread)} {plan.reason}")
    if plan.code != 0:
        return plan.code

    root = farm_root(args.root)
    root.mkdir(parents=True, exist_ok=True)
    shots_path = Path(args.shots_out) if args.shots_out else root / "shots_v92_farm.json"
    write_shots(shots_path, shots)
    print(f"[v92-farm] wrote {shots_path} (JSON list, label==id)")

    dual = find_dual(args.scripts)
    if dual is None:
        print("[v92-farm] dual_submit_stills.py not found")
        print("  looked in AIC_FARM_SCRIPTS, --scripts, and the m173 aic-farm script dirs")
        print(f"  shots are staged at {shots_path}")
        return 4

    cmd = build_argv(sys.executable, str(dual), str(root), str(shots_path), plan)
    print("[v92-farm] exec:", " ".join(cmd))
    completed = subprocess.run(cmd)
    if completed.returncode != 0:
        print(f"[v92-farm] dual_submit exit {completed.returncode}")
        return completed.returncode
    print(f"SUBMITTED v92 stills shots={len(shots)} only={plan.only} root={root}")
    print(f"poll when needed: {sys.executable} {Path(__file__).resolve()} --poll")
    return 0


if __name__ == "__main__":
    sys.exit(main())
