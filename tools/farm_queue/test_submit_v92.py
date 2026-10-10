#!/usr/bin/env python3
"""Converter and host-plan checks for the v9.2 stills submit path."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import submit_v92_stills as submit  # noqa: E402
import validate_queue_v92 as gate  # noqa: E402


class SubmitV92Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.jobs, cls.names = gate.collect_jobs()
        cls.shots = submit.build_shots(cls.jobs)

    def test_queue_files_present(self) -> None:
        self.assertIn("genome_bank_v92.json", self.names)
        self.assertGreaterEqual(len(self.names), 8)

    def test_city_shot_copies_lock_fields(self) -> None:
        city = next(job for job in self.jobs if job["kind"] == "city")
        shot = submit.job_to_shot(city)
        self.assertEqual(shot["label"], city["id"])
        self.assertEqual(shot["id"], city["id"])
        self.assertEqual(shot["prompt"], city["positive"])
        self.assertEqual(shot["positive"], city["positive"])
        self.assertEqual(shot["negative"], city["negative"])
        self.assertEqual(shot["seed"], int(city["seed"]))
        self.assertEqual(shot["steps"], 28)
        self.assertEqual(shot["cfg"], 1.0)
        self.assertEqual(shot["sampler"], "euler")
        self.assertEqual(shot["scheduler"], "simple")
        self.assertEqual(shot["w"], 1280)
        self.assertEqual(shot["h"], 720)
        self.assertEqual(shot["width"], 1280)
        self.assertEqual(shot["height"], 720)
        self.assertEqual(shot["role"], "city")
        self.assertEqual(shot["farm"], "FARM-02")
        self.assertEqual(shot["out_path"], city["out_path"])
        self.assertEqual(shot["filename_prefix"], city["id"])

    def test_genome_uses_bucket_key(self) -> None:
        bucket = next(job for job in self.jobs if job["kind"] == "genome")
        shot = submit.job_to_shot(bucket)
        self.assertEqual(shot["label"], bucket["bucket_key"])
        self.assertEqual(shot["id"], bucket["bucket_key"])
        self.assertEqual(shot["prompt"], bucket["positive"])
        self.assertEqual(shot["farm"], "FARM-01")
        self.assertEqual((shot["w"], shot["h"]), (768, 1024))

    def test_expression_local_keeps_identity_ref(self) -> None:
        local = next(
            job for job in self.jobs if job["kind"] == "expression" and job.get("edit") == "local"
        )
        shot = submit.job_to_shot(local)
        self.assertEqual(shot["edit"], "local")
        self.assertEqual(shot["identity_ref"], local["identity_ref"])
        self.assertIn("local redraw", shot["prompt"])
        self.assertEqual(shot["farm"], "FARM-04")

    def test_full_batch_is_unique_and_ordered(self) -> None:
        self.assertEqual(len(self.shots), len(self.jobs))
        labels = [shot["label"] for shot in self.shots]
        self.assertEqual(labels, [shot["id"] for shot in self.shots])
        self.assertEqual(len(labels), len(set(labels)))
        self.assertEqual(len(self.shots), 2067)
        farms = [shot["farm"] for shot in self.shots]
        self.assertEqual(farms, sorted(farms, key=submit.FARM_ORDER.index))
        farm03 = [shot["role"] for shot in self.shots if shot["farm"] == "FARM-03"]
        self.assertEqual(farm03[0], "smith")
        last_smith = max(i for i, role in enumerate(farm03) if role == "smith")
        self.assertLess(last_smith, farm03.index("item"))

    def test_farm_filter(self) -> None:
        cities = submit.build_shots(self.jobs, {"FARM-02"})
        self.assertTrue(cities)
        self.assertTrue(all(shot["farm"] == "FARM-02" for shot in cities))
        self.assertTrue(all(shot["role"] == "city" for shot in cities))

    def test_written_file_is_label_list(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "shots_v92_farm.json"
            submit.write_shots(path, self.shots)
            text = path.read_text(encoding="utf-8")
            payload = json.loads(text)
        self.assertIsInstance(payload, list)
        self.assertEqual(len(payload), 2067)
        self.assertTrue(text.lstrip().startswith("["))
        self.assertEqual(payload[0]["label"], payload[0]["id"])
        self.assertTrue(all(row["label"] == row["id"] and row["label"] for row in payload))

    def test_default_is_qwen_even_when_sensenova_is_up(self) -> None:
        plan = submit.decide_plan(True, True, False)
        self.assertEqual(plan.only, "qwen")
        self.assertFalse(plan.spread)
        argv = submit.build_argv("python", "dual_submit_stills.py", r"D:\AIComics\CenturyKnights_farm", "shots.json", plan)
        self.assertEqual(
            argv,
            [
                "python",
                "dual_submit_stills.py",
                "--root",
                r"D:\AIComics\CenturyKnights_farm",
                "--shots-json",
                "shots.json",
                "--sn-backend",
                "local",
                "--only",
                "qwen",
            ],
        )

    def test_sn_down_still_submits_qwen(self) -> None:
        plan = submit.decide_plan(True, False, False)
        self.assertEqual(plan.code, 0)
        self.assertEqual(plan.only, "qwen")

    def test_dual_is_opt_in(self) -> None:
        self.assertFalse(submit.want_dual(False, {}))
        self.assertFalse(submit.want_dual(False, {"CK_FARM_ALLOW_QWEN_ONLY": "1"}))
        self.assertFalse(submit.want_dual(False, {"CK_FARM_DUAL": "0"}))
        self.assertTrue(submit.want_dual(False, {"CK_FARM_DUAL": "1"}))
        self.assertTrue(submit.want_dual(True, {}))
        plan = submit.decide_plan(True, True, True)
        self.assertEqual(plan.only, "both")
        self.assertTrue(plan.spread)
        argv = submit.build_argv("python", "dual.py", "root", "shots.json", plan)
        self.assertIn("--spread", argv)
        self.assertEqual(argv[argv.index("--sn-backend") + 1], "local")
        self.assertEqual(argv[argv.index("--only") + 1], "both")
        blocked = submit.decide_plan(True, False, True)
        self.assertEqual(blocked.code, 3)
        self.assertEqual(blocked.only, "")

    def test_qwen_down_always_aborts(self) -> None:
        self.assertEqual(submit.decide_plan(False, True, True).code, 2)
        self.assertEqual(submit.decide_plan(False, False, False).code, 2)

    def test_main_default_skips_sensenova_even_if_up(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            shots = str(Path(tmp) / "shots.json")
            root = Path(tmp) / "root"
            with mock.patch.object(submit, "host_status", return_value=(True, True)) as status, \
                 mock.patch.object(submit, "find_dual", return_value=Path("dual_submit_stills.py")), \
                 mock.patch.object(submit, "farm_root", return_value=root), \
                 mock.patch.object(submit.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run, \
                 mock.patch.dict(os.environ, {"CK_FARM_ALLOW_QWEN_ONLY": "1"}, clear=False):
                os.environ.pop("CK_FARM_DUAL", None)
                code = submit.main(["--farms", "FARM-02", "--shots-out", shots])
            self.assertEqual(code, 0)
            self.assertFalse(status.call_args.args[2])
            argv = run.call_args.args[0]
            self.assertNotIn("--spread", argv)
            self.assertEqual(argv[argv.index("--sn-backend") + 1], "local")
            self.assertEqual(argv[argv.index("--only") + 1], "qwen")
            payload = json.loads(Path(shots).read_text(encoding="utf-8"))
            self.assertIsInstance(payload, list)
            self.assertEqual(len(payload), 35)
            self.assertEqual(payload[0]["label"], payload[0]["id"])
            self.assertEqual(payload[0]["prompt"], payload[0]["positive"])
            self.assertEqual(payload[0]["role"], "city")

    def test_main_dual_flag_spreads_when_both_up(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            shots = str(Path(tmp) / "shots.json")
            root = Path(tmp) / "root"
            with mock.patch.object(submit, "host_status", return_value=(True, True)) as status, \
                 mock.patch.object(submit, "find_dual", return_value=Path("dual_submit_stills.py")), \
                 mock.patch.object(submit, "farm_root", return_value=root), \
                 mock.patch.object(submit.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
                code = submit.main(["--farms", "FARM-02", "--shots-out", shots, "--dual"])
            self.assertEqual(code, 0)
            self.assertTrue(status.call_args.args[2])
            argv = run.call_args.args[0]
            self.assertIn("--spread", argv)
            self.assertEqual(argv[argv.index("--only") + 1], "both")

    def test_main_dual_env_spreads(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            shots = str(Path(tmp) / "shots.json")
            root = Path(tmp) / "root"
            with mock.patch.object(submit, "host_status", return_value=(True, True)), \
                 mock.patch.object(submit, "find_dual", return_value=Path("dual_submit_stills.py")), \
                 mock.patch.object(submit, "farm_root", return_value=root), \
                 mock.patch.object(submit.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run, \
                 mock.patch.dict(os.environ, {"CK_FARM_DUAL": "1"}):
                code = submit.main(["--farms", "FARM-02", "--shots-out", shots])
            self.assertEqual(code, 0)
            argv = run.call_args.args[0]
            self.assertEqual(argv[argv.index("--only") + 1], "both")
            self.assertIn("--spread", argv)

    def test_main_dual_aborts_when_sn_down(self) -> None:
        with mock.patch.object(submit, "host_status", return_value=(True, False)), \
             mock.patch.object(submit.subprocess, "run") as run, \
             mock.patch.dict(os.environ, {"CK_FARM_DUAL": "1"}):
            code = submit.main(["--farms", "FARM-02", "--dual"])
        self.assertEqual(code, 3)
        run.assert_not_called()

    def test_main_missing_script_stages_shots(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            shots = str(Path(tmp) / "shots.json")
            root = Path(tmp) / "root"
            env = os.environ.copy()
            env.pop("CK_FARM_DUAL", None)
            with mock.patch.object(submit, "host_status", return_value=(True, False)), \
                 mock.patch.object(submit, "find_dual", return_value=None), \
                 mock.patch.object(submit, "farm_root", return_value=root), \
                 mock.patch.object(submit.subprocess, "run") as run, \
                 mock.patch.dict(os.environ, env, clear=True):
                code = submit.main(["--farms", "FARM-02", "--shots-out", shots])
            self.assertEqual(code, 4)
            run.assert_not_called()
            self.assertTrue(Path(shots).is_file())


if __name__ == "__main__":
    unittest.main()
