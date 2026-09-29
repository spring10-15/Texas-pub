"""Keep the Phase 2 content matrix aligned with the current Godot definitions."""
import csv
import json
import unittest
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTENT = ROOT / "Godot/three_d/rules/content.json"
MATRIX = ROOT / "docs/3d-production/external-handoff/B-content-assets/content-matrix.csv"


class ContentMatrixTest(unittest.TestCase):
    def test_every_configured_entry_has_one_defined_row(self):
        content = json.loads(CONTENT.read_text(encoding="utf-8"))
        with MATRIX.open(encoding="utf-8-sig", newline="") as source:
            rows = list(csv.DictReader(source))

        expected = Counter()
        for category, key in (
            ("酒馆", "scenes"),
            ("牌桌", "tables"),
            ("对手", "opponents"),
        ):
            expected.update((category, item_id) for item_id in content[key])
        expected.update(
            ("物品-可用" if item["kind"] == "usable" else "物品-贵重", item_id)
            for item_id, item in content["items"].items()
        )
        for routes in content["routes"].values():
            expected.update(("路线-固定", route["id"]) for route in routes["fixedRoutes"])
            expected.update(("路线-特殊", route["id"]) for route in routes["specialRoutes"].values())
        expected.update(("通用撤离", route) for route in ("general", "fixed", "dropbag-cash", "dropbag-valuables"))
        expected[("酒保", "bartender")] = 1

        actual = Counter((row["类别"], row["ID"]) for row in rows)
        self.assertEqual(actual, expected)
        for row in rows:
            for field in ("规则定义位置", "执行入口", "获得或解锁条件", "效果或收益", "限制", "测试证据", "实现状态", "验证状态"):
                with self.subTest(category=row["类别"], item=row["ID"], field=field):
                    self.assertNotIn(row[field].strip(), ("", "-"))


if __name__ == "__main__":
    unittest.main()
