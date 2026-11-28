import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("cybra_hash_eco", MODULE / "eco.py")
ECO = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ECO)


class HashAutosaveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        ECO.HASH_CONFIG = root / "git_hash_config.json"
        ECO.HASH_STORE = root / "git_hash_100.json"

    def tearDown(self):
        self.tmp.cleanup()

    def sample(self, n):
        return {
            "at": f"2026-11-28T00:00:{n % 60:02d}Z",
            "layers": {"1_cascade": f"{n:064x}", "2_contracts": "a" * 64,
                       "3_health_gate": "b" * 64, "4_parliament": "c" * 64},
            "master": f"{n:064x}"
        }

    def test_autosaves_and_caps_at_100(self):
        for n in range(1, 106):
            ECO.autosave_hash_record(self.sample(n))
        state = json.loads(ECO.HASH_STORE.read_text(encoding="utf-8"))
        self.assertEqual(state["count"], 100)
        self.assertEqual(len(state["records"]), 100)
        self.assertEqual(state["records"][0]["master_hash"], f"{6:064x}")
        self.assertEqual(state["records"][-1]["master_hash"], f"{105:064x}")
        self.assertEqual(len(state["root_hash"]), 64)

    def test_atomic_store_has_no_temp_file_left(self):
        ECO.autosave_hash_record(self.sample(1))
        self.assertTrue(ECO.HASH_STORE.exists())
        self.assertFalse(ECO.HASH_STORE.with_suffix(".json.tmp").exists())


if __name__ == "__main__":
    unittest.main()
