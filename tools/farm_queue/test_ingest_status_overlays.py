#!/usr/bin/env python3
"""Unit tests for status overlay gate + ingest (synthetic plates only)."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

import ingest_status_overlays as ingest


def _rgba(w: int, h: int, paint_box=None, color=(180, 200, 220, 220)) -> Image.Image:
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    if paint_box is not None:
        x0, y0, x1, y1 = paint_box
        arr[y0:y1, x0:x1] = color
    return Image.fromarray(arr, "RGBA")


class IngestStatusTest(unittest.TestCase):
    def test_queue_has_six_expected_ids(self) -> None:
        jobs = ingest.load_jobs()
        self.assertEqual(len(jobs), 6)
        self.assertEqual(
            [j["status_id"] for j in jobs],
            ["malnourished", "wound_light", "wound_lasting", "wound_grave", "lost_finger", "limp"],
        )
        for job in jobs:
            gate = job["gate"]
            self.assertIn("min_opaque_ratio", gate)
            self.assertIn("max_opaque_ratio", gate)

    def test_gate_rejects_full_opaque_face(self) -> None:
        job = ingest.load_jobs()[0]
        style = ingest.lock_check()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "full.png"
            _rgba(768, 1024, (0, 0, 768, 1024), (40, 60, 90, 255)).save(path)
            ok, metrics = ingest.gate_plate(path, job, style)
            self.assertFalse(ok)
            self.assertIn("too_opaque", metrics["fails"])

    def test_gate_rejects_empty(self) -> None:
        job = ingest.load_jobs()[0]
        style = ingest.lock_check()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "empty.png"
            _rgba(768, 1024).save(path)
            ok, metrics = ingest.gate_plate(path, job, style)
            self.assertFalse(ok)

    def test_gate_accepts_sparse_cool_paint(self) -> None:
        job = ingest.load_jobs()[0]
        style = ingest.lock_check()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ok.png"
            # ~3% cool slate wrap
            _rgba(768, 1024, (200, 120, 520, 280), (160, 180, 200, 210)).save(path)
            ok, metrics = ingest.gate_plate(path, job, style)
            self.assertTrue(ok, metrics)
            self.assertGreater(metrics["opaque_ratio"], 0.008)
            self.assertLess(metrics["opaque_ratio"], 0.40)

    def test_find_source_by_job_id(self) -> None:
        job = ingest.load_jobs()[0]
        with tempfile.TemporaryDirectory() as tmp:
            inbox = Path(tmp)
            path = inbox / f"{job['id']}.png"
            _rgba(768, 1024, (100, 100, 200, 200)).save(path)
            self.assertEqual(ingest.find_source(inbox, job), path)

    def test_ingest_writes_webp_and_import(self) -> None:
        jobs = ingest.load_jobs()
        with tempfile.TemporaryDirectory() as tmp:
            inbox = Path(tmp) / "inbox"
            inbox.mkdir()
            for job in jobs:
                _rgba(768, 1024, (180, 140, 420, 300), (150, 175, 200, 200)).save(
                    inbox / f"{job['id']}.png"
                )
            # redirect DEST/REPORT into temp via monkeypatch
            dest = Path(tmp) / "status"
            report = Path(tmp) / "report.json"
            old_dest, old_report = ingest.DEST, ingest.REPORT
            old_project = ingest.PROJECT
            try:
                ingest.DEST = dest
                ingest.REPORT = report
                ingest.PROJECT = Path(tmp)
                code = ingest.run(inbox, dry_run=False, review_dir=Path(tmp) / "review")
                self.assertEqual(code, 0)
                for job in jobs:
                    sid = job["status_id"]
                    self.assertTrue((dest / f"{sid}.png").is_file())
                    webp = dest / f"{sid}.webp"
                    self.assertTrue(webp.is_file())
                    self.assertTrue(Path(str(webp) + ".import").is_file())
                payload = json.loads(report.read_text(encoding="utf-8"))
                self.assertEqual(len(payload["passed"]), 6)
            finally:
                ingest.DEST = old_dest
                ingest.REPORT = old_report
                ingest.PROJECT = old_project


if __name__ == "__main__":
    unittest.main()
