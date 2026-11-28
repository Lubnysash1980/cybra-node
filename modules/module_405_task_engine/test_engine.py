import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("cybra_task_engine", HERE / "engine.py")
engine = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(engine)


class TaskEngineApprovalTests(unittest.TestCase):
    def test_cycle_never_applies_live_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            tasks = root / "tasks"
            sandbox = root / "sandbox"
            tasks.mkdir()
            sandbox.mkdir()
            staged = sandbox / "menu.sh"
            staged.write_text("#!/bin/sh\necho safe\n", encoding="utf-8")
            issue = {"type": "menu_item", "target": "402", "severity": "normal", "detail": "test"}
            patches = [
                patch.object(engine, "TASKS", tasks),
                patch.object(engine, "SANDBOX", sandbox),
                patch.object(engine, "STATS", root / "stats.json"),
                patch.object(engine, "detect", return_value=[issue]),
                patch.object(engine, "sandbox_copy", return_value=(staged, "ok")),
                patch.object(engine, "test_in_sandbox", return_value=(True, [("syntax", True, "ok")])),
                patch.object(engine, "_log_task"),
                patch.object(engine, "apply_task", side_effect=AssertionError("live apply must not run")),
            ]
            for item in patches:
                item.start()
            try:
                result = engine.cycle(limit=1, verbose=False)
            finally:
                for item in reversed(patches):
                    item.stop()
            self.assertEqual(result["results"]["applied"], 0)
            self.assertEqual(result["results"]["skipped"], 1)
            task_files = list(tasks.glob("*.json"))
            self.assertEqual(len(task_files), 1)
            task = json.loads(task_files[0].read_text(encoding="utf-8"))
            self.assertEqual(task["status"], "awaiting_approval")


if __name__ == "__main__":
    unittest.main()
