#!/usr/bin/env python3
"""Conservatively summarize decision opportunities in a fixed-seed JSONL trace."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ACCEPTED_EVENTS = {
    "table_started",
    "table_action",
    "service_action",
    "run_started",
    "venue_transferred",
    "run_extracted",
    "run_abandoned",
    "bankroll_reset",
}


def expected_option(record: dict[str, Any]) -> Any:
    event = record.get("event")
    choice = record.get("choice", "")
    details = record.get("details", {})
    if event == "table_started":
        return {"start_table": details.get("collateral", "")}
    if event == "table_action":
        return choice
    if event == "service_action":
        return {
            "kind": choice,
            "id": details.get("item", ""),
            "target": details.get("target", ""),
        }
    mapping = {
        "run_started": "start_run",
        "venue_transferred": "transfer_to",
        "run_extracted": "extract",
    }
    if event in mapping:
        return {mapping[event]: choice}
    if event == "run_abandoned":
        return "abandon"
    if event == "bankroll_reset":
        return "reset_demo"
    return None


def option_matches(expected: Any, offered: Any) -> bool:
    if isinstance(expected, dict):
        return isinstance(offered, dict) and all(offered.get(key) == value for key, value in expected.items())
    return offered == expected


def analyze_records(records: list[dict[str, Any]]) -> dict[str, Any]:
    opportunities: dict[str, dict[str, Any]] = {}
    duplicate_ids: list[str] = []
    malformed: list[int] = []
    for line_no, record in enumerate(records, 1):
        if record.get("event") != "decision_opportunity":
            continue
        opportunity_id = str(record.get("choice", ""))
        options = record.get("details", {}).get("options")
        if not opportunity_id or not isinstance(options, list):
            malformed.append(line_no)
            continue
        if opportunity_id in opportunities:
            duplicate_ids.append(opportunity_id)
            continue
        opportunities[opportunity_id] = record

    attempts: dict[str, int] = {}
    effective: list[dict[str, Any]] = []
    unmatched: list[dict[str, Any]] = []
    unclassifiable: list[dict[str, Any]] = []
    for line_no, record in enumerate(records, 1):
        event = record.get("event")
        details = record.get("details", {})
        if event not in ACCEPTED_EVENTS | {"decision_attempt_rejected"}:
            continue
        opportunity_id = str(details.get("opportunity_id", ""))
        opportunity = opportunities.get(opportunity_id)
        if opportunity is None:
            unclassifiable.append({"line": line_no, "event": event, "reason": "missing or unknown opportunity_id"})
            continue
        attempts[opportunity_id] = attempts.get(opportunity_id, 0) + 1
        if event == "decision_attempt_rejected":
            continue
        options = opportunity["details"]["options"]
        expected = expected_option(record)
        if not isinstance(expected, (dict, str)) or not any(option_matches(expected, item) for item in options):
            unmatched.append({"line": line_no, "event": event, "opportunity_id": opportunity_id, "choice": record.get("choice", "")})
            continue
        if len(options) < 2:
            continue
        effective.append({"line": line_no, "event": event, "opportunity_id": opportunity_id, "choice": record.get("choice", "")})

    return {
        "trace_records": len(records),
        "decision_opportunities": len(opportunities),
        "multi_option_opportunities": sum(len(item["details"]["options"]) >= 2 for item in opportunities.values()),
        "attempts_with_known_opportunity": sum(attempts.values()),
        "effective_decisions": len(effective),
        "opportunities_without_attempt": sorted(set(opportunities) - set(attempts)),
        "duplicate_opportunity_ids": sorted(set(duplicate_ids)),
        "malformed_opportunity_lines": malformed,
        "unmatched_choices": unmatched,
        "unclassifiable_actions": unclassifiable,
        "effective_decision_rows": effective,
        "coverage_note": "Counts include only recorded opportunities linked to accepted, state-changing actions with at least two offered options. This trace does not establish that every in-game opportunity was opened or observed.",
    }


def read_trace(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"line {line_no} is not a JSON object")
        records.append(value)
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="fixed-seed JSONL trace")
    parser.add_argument("--output", type=Path, help="optional JSON report path")
    args = parser.parse_args()
    report = analyze_records(read_trace(args.trace))
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 1 if report["duplicate_opportunity_ids"] or report["malformed_opportunity_lines"] or report["unmatched_choices"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
