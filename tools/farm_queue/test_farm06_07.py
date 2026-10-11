#!/usr/bin/env python3
"""Smoke-queue checks for FARM-06 Hunyuan jobs and FARM-07 tokens/busts."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "tools" / "farm_queue"
sys.path.insert(0, str(QUEUE))
sys.path.insert(0, str(ROOT / "tools" / "farm_v87"))
import build_farm06_07 as build  # noqa: E402
import gen_qwen  # noqa: E402
import validate_farm06_07 as farm  # noqa: E402


class Farm0607Test(unittest.TestCase):
    def test_validator_passes(self) -> None:
        self.assertEqual(farm.check(), [])

    def test_committed_json_matches_builder(self) -> None:
        self.assertEqual((QUEUE / "farm06_hunyuan_smoke.json").read_text(), build.dumps(build.farm06_document()))
        self.assertEqual((QUEUE / "farm07_tokens_smoke.json").read_text(), build.dumps(build.farm07_document()))

    def test_sheet_clause_matches_qwen_generator(self) -> None:
        doc = json.loads((QUEUE / "farm06_hunyuan_smoke.json").read_text())
        human = [row for row in doc["jobs"] if row["kind"] != "mount"]
        self.assertTrue(human)
        for row in human:
            self.assertIn(gen_qwen.SHEET, row["sheet"]["positive"])
        mount = next(row for row in doc["jobs"] if row["kind"] == "mount")
        self.assertNotIn(gen_qwen.SHEET, mount["sheet"]["positive"])
        self.assertIn("no rider", mount["sheet"]["positive"])

    def test_emit_writes_qwen_jobs_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            batch = Path(tmp) / "batch"
            count = build.emit(batch, "all")
            files = sorted(p.name for p in (batch / "jobs").glob("*.json"))
            self.assertEqual(count, 16)
            self.assertEqual(len(files), 16)
            self.assertTrue(all(name.startswith("8322__") for name in files))
            self.assertFalse(any(name.startswith("8327__") for name in files))
            sample = json.loads((batch / "jobs" / "8322__hy_mount_courser.json").read_text())
            prompt = sample["prompt"]["4"]["inputs"]["prompt"]
            doc = json.loads((QUEUE / "farm06_hunyuan_smoke.json").read_text())
            mount = next(row for row in doc["jobs"] if row["id"] == "hy_mount_courser")
            self.assertEqual(prompt, mount["sheet"]["positive"])
            self.assertEqual(sample["prompt"]["7"]["inputs"]["steps"], 28)
            self.assertEqual(sample["prompt"]["7"]["inputs"]["cfg"], 1.0)
            pending = json.loads((batch / "hunyuan_pending.json").read_text())
            self.assertEqual(len(pending["jobs"]), 7)
            self.assertTrue(all(row["triangle_budget_max"] == 15000 for row in pending["jobs"]))
            self.assertTrue(all(row["hunyuan"]["port"] == 8327 for row in pending["jobs"]))

    def test_cli_dry_run(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(QUEUE / "validate_farm06_07.py")],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("FARM06-07 PASS", proc.stdout)


if __name__ == "__main__":
    unittest.main()
