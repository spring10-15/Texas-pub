#!/usr/bin/env python3
"""A5 收尾自检：按内容锚点重推 source_line，并核对 evidence_path 存在、CSV 可解析、16 条既有 ID 不重复。

用法（仓库根）：
    python3 docs/3d-production/external-handoff/A5-persistence-audit/repro/verify_outcomes.py
"""
import csv
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
CSV = ROOT / "docs/3d-production/external-handoff/A5-persistence-audit/outcomes.csv"
REQUIRED = ["family", "source_entry", "source_line", "precondition", "action", "result",
            "postcondition", "existing_catalog_id", "existing_test", "evidence_status",
            "evidence_path", "notes"]
FAMILIES = {"capture", "write", "read", "restore", "invalid_data", "legacy_migration", "rng_replay"}
CATALOG_IDS = [
    "persistence_io.read_missing", "persistence_io.write_new", "persistence_io.read_valid",
    "persistence_io.write_replace", "persistence_io.read_corrupt", "persistence_io.read_truncated",
    "persistence_io.read_version", "persistence_restore.invalid_props", "persistence_restore.invalid_transform",
    "persistence_restore.outside_room", "persistence_restore.valid", "persistence_restore.legacy_props",
    "persistence_restore.seated", "persistence_restore.replace_live_table", "persistence_restore.paused_seated",
    "persistence_table.rng_replay",
]

problems = []


def main() -> int:
    with CSV.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        headers = reader.fieldnames or []
        rows = list(reader)
    for col in REQUIRED:
        if col not in headers:
            problems.append(f"缺少必需列：{col}")
    widths = {len(r) for r in rows}
    if widths and widths != {len(headers)}:
        problems.append(f"列数不一致：{widths} vs header {len(headers)}")

    families_seen = {}
    catalog_seen = {}
    for i, r in enumerate(rows, start=2):
        family = r.get("family", "")
        families_seen[family] = families_seen.get(family, 0) + 1
        if family not in FAMILIES:
            problems.append(f"行 {i}: 未知 family {family!r}")
        # evidence_path（可含 ';' 多路径）
        for raw in str(r.get("evidence_path", "")).split(";"):
            rel = raw.strip()
            if not rel:
                continue
            if not (ROOT / rel).exists():
                problems.append(f"行 {i}: evidence_path 不存在：{rel}")
        # source_file + source_line 内容锚点重推
        src = r.get("source_file", "")
        anchor = r.get("source_anchor", "")
        line = str(r.get("source_line", ""))
        if src and src != "(none)":
            path = ROOT / src
            if not path.exists():
                problems.append(f"行 {i}: source_file 不存在：{src}")
            elif anchor:
                text = path.read_text(encoding="utf-8").splitlines()
                if not line.isdigit():
                    problems.append(f"行 {i}: source_line 非数字：{line}")
                else:
                    n = int(line)
                    if not (1 <= n <= len(text)):
                        problems.append(f"行 {i}: source_line {n} 越界（{src} 共 {len(text)} 行）")
                    elif anchor not in text[n - 1]:
                        problems.append(f"行 {i}: 锚点在第 {n} 行未命中：{anchor[:60]!r}")
        cid = str(r.get("existing_catalog_id", "")).strip()
        if cid:
            catalog_seen[cid] = catalog_seen.get(cid, 0) + 1

    for fid in FAMILIES:
        if fid not in families_seen:
            problems.append(f"七组缺失：{fid}")
    for cid in CATALOG_IDS:
        n = catalog_seen.get(cid, 0)
        if n != 1:
            problems.append(f"既有 ID 应恰好出现一次：{cid} 出现 {n} 次")
    for cid in catalog_seen:
        if cid not in CATALOG_IDS:
            problems.append(f"未知既有 ID（可能重复计数或拼写错）：{cid}")

    print(f"rows={len(rows)} families={families_seen}")
    print(f"catalog_ids_mapped={len(catalog_seen)}/{len(CATALOG_IDS)}")
    if problems:
        print("FAIL:")
        for p in problems:
            print("  -", p)
        return 1
    print("OK: 所有 evidence_path 存在、source_line 按内容锚点命中、七组齐全、既有 ID 不重复")
    return 0


if __name__ == "__main__":
    sys.exit(main())
