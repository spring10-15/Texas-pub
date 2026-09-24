#!/usr/bin/env python3
"""Build A6 opponent-choice matrices from the read-only difficulty probe report."""
import csv
import hashlib
import itertools
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
REPORT = ROOT / "output/3d/difficulty-probe.json"
CONTENT = ROOT / "Godot/three_d/rules/content.json"
OPPONENT_CODE = ROOT / "Godot/three_d/rules/opponent.gd"
OUT = Path(__file__).resolve().parents[1]
ACTIONS = ("fold", "check", "call", "raise", "all-in")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot_id(index: int, row: dict) -> str:
    return "/".join(str(value) for value in (
        index, row["venue"], row["table"], row["seed"], row["actor"],
        row["hand"], row["street"], row["playerRaises"],
    ))


def slices(rows: list[dict]) -> dict[str, list[dict]]:
    result = {"all": rows}
    result["player_raises>=2"] = [r for r in rows if r["playerRaises"] >= 2]
    result["player_raises>=3"] = [r for r in rows if r["playerRaises"] >= 3]
    for field, prefix in (("table", "table"), ("street", "street")):
        for value in sorted({r[field] for r in rows}):
            result[f"{prefix}={value}"] = [r for r in rows if r[field] == value]
    for value in sorted({sum(bool(v) for v in r["legal"].values()) for r in rows}):
        result[f"legal_actions={value}"] = [
            r for r in rows if sum(bool(v) for v in r["legal"].values()) == value
        ]
    return result


def legal_choice(row: dict, action: str) -> bool:
    key = "allIn" if action == "all-in" else action
    return bool(row["legal"].get(key, False))


def main() -> None:
    data = json.loads(REPORT.read_text())
    content = json.loads(CONTENT.read_text())
    profile_ids = sorted(content["opponents"])
    rows = data["repeatedRaiseContexts"]
    if len(data["results"]) != 448 or data["failures"]:
        raise SystemExit("Refusing stale/failed probe: expected 448 results and no failures")
    if len(profile_ids) != 8 or not rows:
        raise SystemExit("Expected eight current profiles and repeated-raise contexts")
    for row in rows:
        if set(row["choices"]) != set(profile_ids):
            raise SystemExit("Snapshot profile IDs do not match content.json")
        for opponent, action in row["choices"].items():
            if action not in ACTIONS or not legal_choice(row, action):
                raise SystemExit(f"Illegal counterfactual choice: {opponent}={action}")

    indexed = list(enumerate(rows, 1))
    groups = slices(rows)
    pair_fields = ["opponent_a", "opponent_b", "slice", "snapshots", "different",
                   "denominator", "difference_rate", "example_snapshot_ids"]
    with (OUT / "pairwise-matrix.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=pair_fields)
        writer.writeheader()
        for group, group_rows in groups.items():
            group_ids = {id(row) for row in group_rows}
            selected = [(i, row) for i, row in indexed if id(row) in group_ids]
            for left, right in itertools.combinations(profile_ids, 2):
                comparable = [(i, r) for i, r in selected
                              if left in r["choices"] and right in r["choices"]]
                different = [(i, r) for i, r in comparable
                             if r["choices"][left] != r["choices"][right]]
                writer.writerow({
                    "opponent_a": left, "opponent_b": right, "slice": group,
                    "snapshots": len(group_rows), "different": len(different),
                    "denominator": len(comparable),
                    "difference_rate": (f"{len(different)/len(comparable):.6f}" if comparable else ""),
                    "example_snapshot_ids": ";".join(
                        snapshot_id(i, r) for i, r in different[:3]),
                })

    action_fields = ["opponent", "slice", "samples", *ACTIONS,
                     *(f"{action}_rate" for action in ACTIONS)]
    with (OUT / "action-distribution.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=action_fields)
        writer.writeheader()
        for group, group_rows in groups.items():
            for opponent in profile_ids:
                counts = Counter(r["choices"][opponent] for r in group_rows)
                total = len(group_rows)
                row = {"opponent": opponent, "slice": group, "samples": total}
                row.update({action: counts[action] for action in ACTIONS})
                row.update({f"{action}_rate": f"{counts[action]/total:.6f}" if total else ""
                            for action in ACTIONS})
                writer.writerow(row)

    summary = {
        "probe_results": len(data["results"]), "repeated_raise_contexts": len(rows),
        "profile_ids": profile_ids, "pair_rows": 28 * len(groups),
        "action_rows": len(profile_ids) * len(groups),
        "probe_sha256": digest(REPORT), "content_sha256": digest(CONTENT),
        "opponent_code_sha256": digest(OPPONENT_CODE),
        "source_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "slices": {name: len(group) for name, group in groups.items()},
    }
    (OUT / "analysis-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
