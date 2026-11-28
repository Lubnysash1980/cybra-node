import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("cybra_menu_tester", HERE / "tester.py")
tester = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tester)


class MainMenuParserTests(unittest.TestCase):
    def test_only_main_dispatch_is_counted(self):
        source = """def action_one():
    case "$SUB" in
        1) echo nested ;;
    esac
while true; do
    case "$CHOICE" in
        1) action_one ;;
        402) bash \"$HOME/CYBRA/modules/module_402_menu_doctor/main.sh\" ;;
        0|q|Q|exit|quit) exit 0 ;;
    esac
done
"""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "cybra_menu.sh"
            path.write_text(source, encoding="utf-8")
            original = tester.TUI
            tester.TUI = path
            try:
                parsed = tester.parse_cases()
            finally:
                tester.TUI = original
        self.assertEqual(set(parsed), {"1", "402"})
        self.assertEqual(parsed["1"], "action_one")
        self.assertIn("module_402_menu_doctor", parsed["402"])

    def test_duplicate_main_dispatch_is_marked(self):
        source = """case "$CHOICE" in
    87) action_cleanup ;;
    87) action_restore ;;
    0|q|Q|exit|quit) exit 0 ;;
esac
"""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "cybra_menu.sh"
            path.write_text(source, encoding="utf-8")
            original = tester.TUI
            tester.TUI = path
            try:
                parsed = tester.parse_cases()
            finally:
                tester.TUI = original
        self.assertTrue(parsed["87"].startswith("DUP:"))


if __name__ == "__main__":
    unittest.main()
