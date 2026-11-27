#!/usr/bin/env python3
"""Unit tests for the read-only CYBRA Evolution Dashboard."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[1] / "server.py"
SPEC = importlib.util.spec_from_file_location("cybra_evolution_server", MODULE_PATH)
server = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(server)


class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "project"
        self.root.mkdir()
        (self.root / "app.py").write_text("print('base')\n")
        self.data = self.root / "state" / "evolution_dashboard"
        self.patches = [
            patch.object(server, "ROOT", self.root),
            patch.object(server, "DATA", self.data),
            patch.object(server, "BASELINE", self.data / "baseline.json"),
            patch.object(server, "HISTORY", self.data / "history.jsonl"),
            patch.object(server.subprocess, "run", side_effect=FileNotFoundError("pm2 not installed")),
        ]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.tmp.cleanup()

    def test_first_collection_creates_baseline(self):
        state = server.collect()
        self.assertTrue(server.BASELINE.exists())
        self.assertEqual(state["evolution_pct"], 0.0)
        self.assertEqual(state["restart_mode"], "MANUAL_ONLY")
        self.assertIsNone(state["health_pct"])

    def test_growth_over_three_percent_creates_snapshot_once(self):
        server.collect()  # capture baseline
        (self.root / "feature.py").write_text("x" * 500)
        state = server.collect()
        self.assertGreaterEqual(state["evolution_pct"], 3.0)
        self.assertTrue(state["threshold_reached"])
        snapshots = list(self.data.glob("evolution_snapshot_*.json"))
        self.assertEqual(len(snapshots), 1)
        payload = json.loads(snapshots[0].read_text())
        self.assertGreaterEqual(payload["evolution_pct"], 3.0)
        server.collect()
        self.assertEqual(len(list(self.data.glob("evolution_snapshot_*.json"))), 1)

    def test_shrinking_code_is_reported_without_restart(self):
        server.collect()
        (self.root / "app.py").write_text("")
        state = server.collect()
        self.assertLess(state["evolution_pct"], 0)
        self.assertEqual(state["restart_mode"], "MANUAL_ONLY")
        self.assertFalse(state["threshold_reached"])

    def test_dashboard_health_label_is_complete(self):
        self.assertIn('id="health">НЕ ВИМІРЮЄТЬСЯ</div>', server.PAGE)
        self.assertIn("MANUAL_ONLY", server.PAGE)

    def test_scanner_ignores_dashboard_state(self):
        (self.data).mkdir(parents=True, exist_ok=True)
        (self.data / "ignored.json").write_text('{"noise": true}')
        files, _ = server.scan()
        self.assertNotIn("state/evolution_dashboard/ignored.json", [x["path"] for x in files])


if __name__ == "__main__":
    unittest.main(verbosity=2)
