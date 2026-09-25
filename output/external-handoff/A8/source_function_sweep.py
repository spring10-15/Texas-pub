#!/usr/bin/env python3
"""Check function-level ownership of every runtime Godot GDScript method.

This is a scope-control check for the A8 source audit. It does not claim that
the transition catalog denominator is complete or that every branch is tested.
"""
from __future__ import annotations

import collections
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RULES = ROOT / "Godot/three_d/rules"
SCRIPTS = ROOT / "Godot/three_d/scripts"
INVENTORY = ROOT / "docs/3d-production/external-handoff/A8-global-catalog-audit/current-tree-branch-inventory.csv"
REPORT = ROOT / "output/external-handoff/A8/source-function-sweep.json"

# Each exception is an exact method reviewed outside the transition inventory.
# Reasons describe why it does not own a separate player-visible state result.
EXCLUDED = {
    "Godot/three_d/rules/run.gd": {
        "_init": "constructs the initial in-memory Run object; new-run effects are owned by start",
        "transfer_quote": "read-only preview; transfer_venue owns accepted/rejected results",
        "table_blocked_reason": "read-only gate query; enter_table owns the rejected result",
        "room_requirements": "read-only dependency query used by room_blocked_reason",
        "room_blocked_reason": "read-only gate query; request_action/enter_table own the result",
        "table_definition": "returns a defensive content copy with the selected opponent roster",
        "extraction_quote": "read-only quote; extract/enforce_pressure own resulting actions",
        "slots_used": "read-only inventory capacity calculation",
        "service_reason": "read-only validation dispatcher; service_action owns the result",
        "shop_stock": "read-only deterministic stock lookup; purchase outcome belongs to service_action",
        "service_view": "read-only construction of visible service choices and text",
        "item_name": "presentation label lookup",
        "sale_value": "read-only content lookup used by sale validation and accounting",
        "valuable_total": "read-only inventory valuation",
        "reward_for_table": "read-only reward-rule selection; settle_table owns reward application",
        "table_reward_pool": "read-only reward-intel projection",
        "abandon_quote": "read-only preview; abandon owns accepted/rejected results",
        "route_offer": "read-only deterministic route lookup",
        "fixed_known": "read-only route visibility predicate",
        "emergency_known": "read-only emergency-route visibility predicate",
        "actor_name": "presentation label lookup",
        "table_name": "presentation label lookup",
        "archetype_name": "presentation label lookup",
        "offer_name": "presentation label lookup",
        "route_known": "read-only route visibility predicate",
        "item_description": "presentation description lookup",
        "rule_text": "read-only content display lookup",
        "scene_definition": "read-only current-scene content lookup",
        "reserve_fee": "read-only price calculation; service_action owns payment",
        "route_name": "presentation label lookup",
    },
    "Godot/three_d/rules/run_variants.gd": {
        "shuffled": "local seeded generation helper; generate owns the resulting stored plan",
    },
    "Godot/three_d/rules/poker.gd": {
        "_init": "initializes the deterministic RNG state; state consumption is represented by next",
        "multiply32": "pure 32-bit arithmetic helper used by the deterministic RNG",
    },
    "Godot/three_d/scripts/bar_display.gd": {
        "_init": "scene presentation helper setup",
        "build": "builds visual shelf nodes from existing content",
        "refresh": "projects Run inventory and stock into shelf visuals",
        "deliver": "animates/displays a selected product; Run.service_action owns purchase state",
        "make_item": "constructs a visual product node",
    },
    "Godot/three_d/scripts/characters.gd": {
        "_init": "scene presentation helper setup",
        "actor": "constructs a visual character node",
        "build": "builds scene character visuals from content",
        "sync": "updates visual character placement and pose",
        "refresh": "projects public table state into character visuals",
        "deliver": "selects existing character feedback text/animation",
    },
    "Godot/three_d/scripts/services_hud.gd": {
        "_ready": "constructs service UI controls",
        "refresh": "projects a read-only service view into UI controls",
    },
    "Godot/three_d/scripts/table_hud.gd": {
        "_ready": "constructs table UI controls",
        "text": "constructs a label",
        "make_button": "constructs a button",
        "card_text": "formats a card for display",
        "cards_text": "formats cards for display",
        "pregame": "projects pregame options into UI controls",
        "refresh": "projects public table state into UI controls",
        "selected_collateral": "reads current UI selection",
        "update_raise_preview": "updates a read-only action preview",
    },
    "Godot/three_d/scripts/tavern_layout.gd": {
        "sign_at": "constructs a sign visual",
        "build": "builds room decoration nodes",
    },
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def methods(path: Path) -> list[dict[str, object]]:
    found = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(", line)
        if match:
            found.append({"line": number, "name": match.group(1), "signature": line.strip()})
    return found


def main() -> int:
    branch_rows = list(csv.DictReader(INVENTORY.open(encoding="utf-8", newline="")))
    audited_lines: dict[str, set[int]] = collections.defaultdict(set)
    for row in branch_rows:
        if row["function_line"].isdigit():
            audited_lines[row["source_file"]].add(int(row["function_line"]))

    files = sorted([*RULES.glob("*.gd"), *SCRIPTS.glob("*.gd")])
    inventory = []
    errors = []
    counts = collections.Counter()
    seen_exclusions = set()
    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        exclusions = EXCLUDED.get(relative, {})
        for method in methods(path):
            key = (relative, method["name"])
            if int(method["line"]) in audited_lines.get(relative, set()):
                status = "audit_inventory"
                reason = "represented by the A8 current-tree branch inventory; branch closure remains a separate check"
            elif method["name"] in exclusions:
                status = "explicit_exclusion"
                reason = exclusions[method["name"]]
                seen_exclusions.add(key)
            else:
                status = "unclassified"
                reason = "no A8 function entry or reviewed exclusion"
                errors.append(f"{relative}:{method['line']} {method['name']}")
            counts[status] += 1
            inventory.append({"file": relative, **method, "status": status, "reason": reason})
    for relative, exclusions in EXCLUDED.items():
        for name in exclusions:
            if (relative, name) not in seen_exclusions:
                errors.append(f"stale exclusion: {relative}:{name}")

    report = {
        "scope": "all runtime GDScript functions under Godot/three_d/rules and scripts",
        "claim": "function-level ownership only; not transition-branch or global-denominator completeness",
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "branch_inventory_sha256": sha(INVENTORY),
        "source_sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in files},
        "counts": dict(counts),
        "functions": inventory,
        "errors": errors,
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SOURCE_FUNCTIONS total={len(inventory)} audit_inventory={counts['audit_inventory']} explicit_exclusion={counts['explicit_exclusion']} unclassified={counts['unclassified']} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
