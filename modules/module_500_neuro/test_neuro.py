import importlib.util
import unittest
from unittest.mock import patch
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("cybra_neuro", HERE / "neuro.py")
neuro = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(neuro)

class NeuroSafetyTests(unittest.TestCase):
    def test_reject_parent_traversal(self):
        with self.assertRaises(neuro.NeuroError):
            neuro.safe_source_path("modules/module_500_neuro/../../config/.env")
    def test_reject_non_module_path(self):
        with self.assertRaises(neuro.NeuroError):
            neuro.safe_source_path("config/settings.json")
    def test_reject_absolute_path(self):
        with self.assertRaises(neuro.NeuroError):
            neuro.safe_source_path("/tmp/payload.py")
    def test_isolated_apply_is_blocked(self):
        if neuro.ROOT.resolve() == (Path.home() / "CYBRA").resolve():
            self.skipTest("running in primary CYBRA root")
        with self.assertRaises(neuro.NeuroError):
            neuro.apply("not-a-real-patch", "watchdog")

    def test_menu_planner_requires_api_key(self):
        with patch.dict(neuro.os.environ, {}, clear=True):
            with self.assertRaisesRegex(neuro.NeuroError, "OPENAI_API_KEY"):
                neuro.plan_items("додати нові модулі")

    def test_sha_is_deterministic(self):
        self.assertEqual(neuro.sha256_bytes(b"CYBRA"), neuro.sha256_bytes(b"CYBRA"))
        self.assertNotEqual(neuro.sha256_bytes(b"CYBRA"), neuro.sha256_bytes(b"cybra"))

if __name__ == "__main__":
    unittest.main()
