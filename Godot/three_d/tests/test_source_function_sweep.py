"""Audit anchors must identify the intended function, not merely a valid line."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location(
    "source_function_sweep", ROOT / "output/external-handoff/A8/source_function_sweep.py"
)
sweep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sweep)


class FunctionAnchorTest(unittest.TestCase):
    def test_function_identity_and_bounds(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "sample.gd").write_text(
                "func first():\n\tpass\nstatic func second():\n\tpass\n", encoding="utf-8"
            )
            def row(entry, line):
                return {"source_file": "sample.gd", "entry": entry, "function_line": str(line)}
            with patch.object(sweep, "ROOT", root):
                self.assertEqual(sweep.validate_function_refs([row("first", 1), row("Type.second（包装）", 3)]), [])
                for entry, line in [("first", 3), ("first", 2), ("first", 0), ("first", 99)]:
                    with self.subTest(entry=entry, line=line):
                        self.assertEqual(len(sweep.validate_function_refs([row(entry, line)])), 1)


if __name__ == "__main__":
    unittest.main()
