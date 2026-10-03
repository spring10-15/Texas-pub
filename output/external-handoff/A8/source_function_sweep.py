#!/usr/bin/env python3
"""Check method ownership and lexical control-site attribution in runtime GDScript.

This is a scope-control check for the A8 source audit. It does not claim that
the transition catalog denominator is complete or that every branch outcome is tested.
"""
from __future__ import annotations

import collections
import csv
import hashlib
import json
import re
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
        "evaluate_five_score": "pure five-card rank/tiebreak calculation; evaluate_five and evaluate_best_hand own returned presentation copies, with no authoritative state mutation",
        "score_seven": "pure seven-card rank/tiebreak calculation for AI equity; no input or authoritative state mutation",
        "straight_high": "pure descending-rank straight lookup used by seven-card scoring",
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
        "handoff_socket": "finds or creates a visual bone attachment for the purchased product; no authoritative Run/table state mutation",
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
        "opponent_line": "projects an opponent's public last action into a content-defined display line",
        "pregame": "projects pregame options into UI controls",
        "refresh": "projects public table state into UI controls",
        "selected_collateral": "reads current UI selection",
        "update_raise_preview": "updates a read-only action preview",
    },
    "Godot/three_d/scripts/world.gd": {
        "trace_choice_opportunity": "records the options visible at a fixed-seed decision point; telemetry only, no authoritative game-state mutation",
        "trace_opportunity_id": "reads the active telemetry correlation id; does not mutate authoritative game state",
        "close_playtest_opportunity": "closes a telemetry-only decision window; does not mutate authoritative game state",
        "legal_service_actions": "filters a read-only service view for telemetry; service_action owns game-state results",
        "trace_table_opportunity": "records currently legal poker choices; telemetry only, no authoritative game-state mutation",
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


def source_line_refs(rows: list[dict[str, str]]) -> dict[str, set[int]]:
    found: dict[str, set[int]] = collections.defaultdict(set)
    for row in rows:
        source = row.get("source_file", "")
        for reference in row.get("source_line", "").split(";"):
            match = re.search(r":(\d+)(?:-(\d+))?$", reference.strip())
            if not match:
                continue
            start = int(match.group(1))
            end = int(match.group(2) or start)
            found[source].update(range(start, end + 1))
    return found


def validate_function_refs(rows: list[dict[str, str]]) -> list[str]:
    """Reject stale numeric anchors even when they point at another function."""
    errors = []
    sources = {}
    for row in rows:
        if not row["function_line"].isdigit():
            continue
        source = row["source_file"]
        if source not in sources:
            sources[source] = (ROOT / source).read_text(encoding="utf-8").splitlines()
        number = int(row["function_line"])
        lines = sources[source]
        line = lines[number - 1] if 1 <= number <= len(lines) else ""
        match = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(", line)
        entry = row["entry"].split("（", 1)[0].split("(", 1)[0].strip().split(".")[-1]
        if not match or match.group(1) != entry:
            errors.append(f"stale function anchor: {source}:{number} expected {entry}")
    return errors


def main() -> int:
    branch_rows = list(csv.DictReader(INVENTORY.open(encoding="utf-8", newline="")))
    audited_lines: dict[str, set[int]] = collections.defaultdict(set)
    for row in branch_rows:
        if row["function_line"].isdigit():
            audited_lines[row["source_file"]].add(int(row["function_line"]))

    files = sorted([*RULES.glob("*.gd"), *SCRIPTS.glob("*.gd")])
    inventory = []
    branch_sites = []
    errors = validate_function_refs(branch_rows)
    counts = collections.Counter()
    branch_counts = collections.Counter()
    seen_exclusions = set()
    source_refs = source_line_refs(branch_rows)
    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        exclusions = EXCLUDED.get(relative, {})
        file_methods = methods(path)
        for method in file_methods:
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

        current_method = "(top level)"
        telemetry_choice_projection = False
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            method_match = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(", line)
            if method_match:
                current_method = method_match.group(1)
                telemetry_choice_projection = False
            if relative == "Godot/three_d/scripts/world.gd" and current_method == "show_run_panel":
                if line.strip() == "if not preview_only:":
                    telemetry_choice_projection = True
                elif telemetry_choice_projection and line.strip() == "Input.mouse_mode = Input.MOUSE_MODE_VISIBLE":
                    telemetry_choice_projection = False
            branch_match = re.match(r"\s*(if|elif|match)\b", line)
            if not branch_match:
                continue
            branch_kind = branch_match.group(1)
            if number in source_refs.get(relative, set()):
                status = "branch_inventory_ref"
                reason = "source line is represented in the A8 current-tree branch inventory"
            elif current_method in exclusions:
                status = "explicit_method_exclusion"
                reason = exclusions[current_method]
            elif relative == "Godot/three_d/scripts/world.gd" and current_method in {
                "trace_playtest", "trace_choice_opportunity", "trace_table_opportunity"
            }:
                status = "telemetry_file_io"
                reason = "records fixed-seed telemetry or checks whether an event should be written; not authoritative game state"
            elif telemetry_choice_projection:
                status = "telemetry_choice_projection"
                reason = "projects eligible run-panel choices into the fixed-seed opportunity record; it does not execute the selected action"
            elif relative == "Godot/three_d/scripts/world.gd" and current_method == "request_action" and branch_kind == "match":
                status = "action_dispatch"
                reason = "routes action ids to downstream world/run transitions; the dispatch itself is not a separate result"
            else:
                status = "unclassified_branch_site"
                reason = "conditional site is neither referenced by the branch inventory nor covered by a reviewed method classification"
                errors.append(f"{relative}:{number} {current_method} {branch_kind}")
            branch_counts[status] += 1
            branch_sites.append({
                "file": relative,
                "line": number,
                "method": current_method,
                "kind": branch_kind,
                "status": status,
                "reason": reason,
            })
    for relative, exclusions in EXCLUDED.items():
        for name in exclusions:
            if (relative, name) not in seen_exclusions:
                errors.append(f"stale exclusion: {relative}:{name}")

    report = {
        "scope": "all runtime GDScript functions under Godot/three_d/rules and scripts",
        "claim": "function-level ownership only; not transition-branch or global-denominator completeness",
        "branch_inventory_sha256": sha(INVENTORY),
        "source_sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in files},
        "counts": dict(counts),
        "functions": inventory,
        "control_flow_site_scope": "line-start if/elif/match sites only; site ownership is not branch-outcome enumeration or a transition denominator",
        "control_flow_site_counts": dict(branch_counts),
        "control_flow_sites": branch_sites,
        "errors": errors,
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SOURCE_FUNCTIONS total={len(inventory)} audit_inventory={counts['audit_inventory']} explicit_exclusion={counts['explicit_exclusion']} unclassified={counts['unclassified']} errors={len(errors)}")
    print(f"SOURCE_BRANCH_SITES total={len(branch_sites)} inventory_ref={branch_counts['branch_inventory_ref']} explicit_method_exclusion={branch_counts['explicit_method_exclusion']} telemetry_io={branch_counts['telemetry_file_io']} dispatch={branch_counts['action_dispatch']} unclassified={branch_counts['unclassified_branch_site']}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
