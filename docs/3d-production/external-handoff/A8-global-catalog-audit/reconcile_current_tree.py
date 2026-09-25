#!/usr/bin/env python3
"""Build a current-tree overlay while preserving the frozen A8 audit files."""
from __future__ import annotations

import csv
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
AUDIT = ROOT / "docs/3d-production/external-handoff/A8-global-catalog-audit"
CATALOG = ROOT / "docs/3d-production/phase-1/coverage/transitions.json"
LATEST_REPORT = "output/3d/regression/" + sorted((ROOT / "output/3d/regression").glob("*/report.json"))[-1].parent.name + "/report.json"


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    catalog_ids = {row["id"] for row in catalog["transitions"]}
    branch_fields, branches = read_csv(AUDIT / "branch-inventory.csv")
    _, old_gaps = read_csv(AUDIT / "unmapped-reachable.csv")

    partial_bankroll = 0
    entry_heat_cap = 0
    settlement_heat_relief = 0
    player_raise_pattern = 0
    world_search_evidence = 0
    world_product_evidence = 0
    reclassified_nonplayer = 0
    presentation_only = 0
    reclassified_weak = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/run.gd"
                and row["source_line"] == "Godot/three_d/rules/run.gd:61-62"
                and "bankroll 取 min" in row["branch_or_guard"]):
            row.update({
                "catalog_id": "start.partial_bankroll",
                "test": "Godot/three_d/tests/lifecycle_coverage_test.gd::start.partial_bankroll",
                "evidence_report": f"output/3d/lifecycle-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "当前目录已登记 start.partial_bankroll；vault=120 的正式测试验证 vault=0、cash/bankroll=120、财富守恒、Run active 及 revision 增加。",
            })
            partial_bankroll += 1
        if row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:175" and "entryHeatBonus" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "entry.heat_cap",
                "test": "Godot/three_d/tests/entry_coverage_test.gd::entry.heat_cap",
                "evidence_report": f"output/3d/entry-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "rooftop-club 入场加成为 1；从风声 5 通过公开 enter_table 成功入座后验证风声封顶 6、现金支付、vault 不变、revision 前进且实际桌型正确。",
            })
            entry_heat_cap += 1
        if row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:205" and "winHeatRelief" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "settlement.heat_relief",
                "test": "Godot/three_d/tests/settlement_coverage_test.gd::settlement.heat_relief",
                "evidence_report": f"output/3d/settlement-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "盈利结算余烬桌时，测试验证 cash 回收、桌面清理、完成标记与 revision 前进，并精确断言 heat 按 winHeatRelief 从 2 降至 1。",
            })
            settlement_heat_relief += 1
        if row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:119-120" and "playerPattern.raiseCount" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "poker.player_raise_pattern",
                "test": "Godot/three_d/tests/poker_action_coverage_test.gd::poker.player_raise_pattern",
                "evidence_report": f"output/3d/poker_action-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "入口测试分别执行玩家 raise、玩家 all-in 与对手 raise；玩家两种侵略动作将 playerPattern.raiseCount 加一，而对手动作保持为零，验证画像只统计玩家行为。",
            })
            player_raise_pattern += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:482-484" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.services_open",
                "test": "Godot/three_d/tests/world_coverage_test.gd::world.services_open",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "复用 world.services_open 语义 ID；通过真实 Tavern/SearchSite 锚点射线调 request_action，断言搜索模式面板打开、站点 ID 正确、玩家控制禁用且 Run 快照不变。",
            })
            world_search_evidence += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:485-487" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.services_open",
                "test": "Godot/three_d/tests/world_coverage_test.gd::world.services_open",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "复用 world.services_open 语义 ID；通过真实货架 shop 锚点射线调 request_action，断言单品模式面板打开、商品 ID 正确、玩家控制禁用且 Run 快照不变。",
            })
            world_product_evidence += 1
        if row["player_reachable"] == "no" and row["disposition"] == "reachable_unmapped":
            row["disposition"] = "unreachable_or_not_transition"
            row["notes"] += " 当前树归因：损坏/篡改存档恢复拒绝或底层写盘失败，不计入正常玩家可达缺口；保留为系统防御分支记录。"
            reclassified_nonplayer += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:106-107" and row["catalog_id"] == "-":
            row.update({
                "outcome": "not_a_transition",
                "disposition": "unreachable_or_not_transition",
                "notes": "playtest_seed 只决定是否显示 save_notice；此分支不改变权威 Run、World 或存档状态，不计为状态转移。",
            })
            presentation_only += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:511-512" and row["catalog_id"] == "world.services_open":
            row["disposition"] = "catalogued_weak"
            row["notes"] += " 当前树归因：已有 world.services_open ID；吧台实体锚点的射线/输入到打开面板仍缺独立集成后置断言，列为弱证据，不计未登记 ID。"
            reclassified_weak += 1
        if "20260925-103506" in row["evidence_report"] or "20260925-105659" in row["evidence_report"]:
            row["evidence_report"] = row["evidence_report"].replace("20260925-103506/report.json", LATEST_REPORT).replace("20260925-105659/report.json", LATEST_REPORT)

    if partial_bankroll != 1 or entry_heat_cap != 1 or settlement_heat_relief != 1 or player_raise_pattern != 1 or world_search_evidence != 1 or world_product_evidence != 1 or reclassified_nonplayer != 6 or presentation_only != 1 or reclassified_weak != 1:
        raise SystemExit(f"Unexpected reconciliation counts: partial={partial_bankroll}, heat_cap={entry_heat_cap}, settlement_relief={settlement_heat_relief}, player_pattern={player_raise_pattern}, search_evidence={world_search_evidence}, product_evidence={world_product_evidence}, nonplayer={reclassified_nonplayer}, presentation={presentation_only}, weak={reclassified_weak}")

    current_gaps = [
        row.copy() for row in old_gaps
        if row["player_reachable"] == "yes"
        and row["catalog_id"] == "-"
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:61-62")
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:175")
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:205")
        and not (row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:119-120")
        and not (row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] in {"Godot/three_d/scripts/world.gd:482-484", "Godot/three_d/scripts/world.gd:485-487"})
    ]
    weak_evidence = [row.copy() for row in branches if row["disposition"] == "catalogued_weak"]
    for row in current_gaps:
        if "20260925-103506" in row["evidence_report"] or "20260925-105659" in row["evidence_report"]:
            row["evidence_report"] = row["evidence_report"].replace("20260925-103506/report.json", LATEST_REPORT).replace("20260925-105659/report.json", LATEST_REPORT)

    mapped_ids: set[str] = set()
    for row in branches:
        for transition_id in row["catalog_id"].split(";"):
            if transition_id and transition_id != "-":
                if transition_id not in catalog_ids:
                    raise SystemExit(f"Unknown catalog ID in overlay: {transition_id}")
                mapped_ids.add(transition_id)
    missing_ids = catalog_ids - mapped_ids
    if missing_ids:
        raise SystemExit(f"Current catalog IDs lack a branch mapping: {sorted(missing_ids)}")

    for row in branches:
        source = ROOT / row["source_file"]
        if not source.is_file():
            raise SystemExit(f"Missing source file: {row['source_file']}")
        for path in row["test"].split(";"):
            path = path.split("::", 1)[0].strip()
            if path and path != "-" and not (ROOT / path).is_file():
                raise SystemExit(f"Missing test file: {path}")
        for path in row["evidence_report"].split(";"):
            path = path.strip()
            if path and path != "-" and not (ROOT / path).is_file():
                raise SystemExit(f"Missing evidence report: {path}")
    if len(current_gaps) != 27 or any(row["player_reachable"] != "yes" or row["catalog_id"] != "-" for row in current_gaps):
        raise SystemExit("Current player-path gap set is inconsistent")

    write_csv(AUDIT / "current-tree-branch-inventory.csv", branch_fields, branches)
    write_csv(AUDIT / "current-tree-player-path-gaps.csv", branch_fields, current_gaps)
    write_csv(AUDIT / "current-tree-weak-evidence.csv", branch_fields, weak_evidence)
    counts = Counter(row["disposition"] for row in branches)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report = ROOT / LATEST_REPORT
    lifecycle_report = ROOT / "output/3d/lifecycle-coverage.json"
    text = f"""# A8 当前树对账记录

- 当前 HEAD：`{head}`
- 当前目录：{len(catalog_ids)} 个唯一 ID，SHA-256 `{sha256(CATALOG)}`
- 采用的全量回归：`{LATEST_REPORT}`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`{sha256(report)}`
- lifecycle 覆盖报告 SHA-256：`{sha256(lifecycle_report)}`
- 当前分支清单 SHA-256：`{sha256(AUDIT / 'current-tree-branch-inventory.csv')}`
- 当前玩家路径缺口清单 SHA-256：`{sha256(AUDIT / 'current-tree-player-path-gaps.csv')}`
- 当前弱证据清单 SHA-256：`{sha256(AUDIT / 'current-tree-weak-evidence.csv')}`
- 对账脚本 SHA-256：`{sha256(AUDIT / 'reconcile_current_tree.py')}`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：{len(mapped_ids)}/{len(catalog_ids)}。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief` 与 `poker.player_raise_pattern` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 {len(current_gaps)} 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{dict(counts)}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
"""
    (AUDIT / "current-tree-reconciliation.md").write_text(text, encoding="utf-8")
    print(f"CURRENT_TREE ids={len(catalog_ids)}/{len(mapped_ids)} rows={len(branches)} gaps={len(current_gaps)} weak={len(weak_evidence)} disposition={dict(counts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
