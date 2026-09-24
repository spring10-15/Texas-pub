#!/usr/bin/env python3
"""A4 交付自检：CSV 可解析、八组齐全、列数一致、evidence_path 存在、source_line 内容锚点匹配。

用法（仓库根目录执行）：
  python3 docs/3d-production/external-handoff/A4-world-audit/repro/verify_outcomes.py
"""
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
CSV_PATH = ROOT / "docs/3d-production/external-handoff/A4-world-audit/outcomes.csv"

REQUIRED_FIELDS = [
    "family", "source_entry", "source_line", "precondition", "action", "result",
    "postcondition", "existing_catalog_id", "existing_test", "evidence_status",
    "evidence_path", "notes",
]
FAMILIES = ["room_entry", "seat", "leave_seat", "pause", "resume",
            "physical_raycast", "prop_interactions", "modal_guards"]
ALLOWED_STATUS = {
    "已登记且有后继状态证据", "有测试但未登记", "未找到测试", "有A4探针后继状态证据",
    "不可到达", "证据不足", "unverified", "源码未实现",
}
# evidence_path 里允许带 `:12` 或 `:12-34` 行号后缀
LINE_RE = re.compile(r"^(?P<file>[^:]+\.gd|.*):(?P<line>\d+)$")
EP_LINE_SUFFIX = re.compile(r":\d+(?:-\d+)?$")


def split_entries(value: str):
    for raw in value.split(";"):
        raw = raw.strip()
        if raw:
            yield raw


def main() -> int:
    problems = []
    if not CSV_PATH.exists():
        print("FAIL: outcomes.csv 不存在")
        return 2

    with CSV_PATH.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    # 1) 列数/字段一致
    fieldnames = list(csv.DictReader(CSV_PATH.open(newline="", encoding="utf-8")).fieldnames)
    missing_fields = [f for f in REQUIRED_FIELDS if f not in fieldnames]
    if missing_fields:
        problems.append(f"缺少必需字段: {missing_fields}")
    for i, row in enumerate(rows, start=2):
        if None in row or any(v is None for v in row.values()):
            problems.append(f"第 {i} 行列数与表头不一致")
        if "" in row or any(str(v) == "" for v in row.values()):
            empty = [k for k, v in row.items() if str(v) == ""]
            problems.append(f"第 {i} 行有空字段: {empty}")

    # 2) 八组齐全
    seen = {}
    for row in rows:
        seen[row["family"]] = seen.get(row["family"], 0) + 1
    for fam in FAMILIES:
        if fam not in seen:
            problems.append(f"缺少分组: {fam}")
    extra = [f for f in seen if f not in FAMILIES]
    if extra:
        problems.append(f"出现未在八组内的 family: {extra}")

    # 3) evidence_status 取值
    for i, row in enumerate(rows, start=2):
        if row["evidence_status"] not in ALLOWED_STATUS:
            problems.append(f"第 {i} 行 evidence_status 非法: {row['evidence_status']}")

    # 4) source_line 内容锚点匹配（重新推导，不只看数字）
    for i, row in enumerate(rows, start=2):
        sl = row["source_line"].strip()
        m = LINE_RE.match(sl)
        if not m:
            problems.append(f"第 {i} 行 source_line 格式异常: {sl}")
            continue
        path = ROOT / m.group("file")
        if not path.exists():
            problems.append(f"第 {i} 行 source_line 文件不存在: {m.group('file')}")
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        n = int(m.group("line"))
        if n < 1 or n > len(lines):
            problems.append(f"第 {i} 行 source_line 越界: {sl} (文件共 {len(lines)} 行)")
            continue
        anchor = row["source_anchor"]
        if anchor not in lines[n - 1]:
            problems.append(
                f"第 {i} 行内容锚点不匹配: {sl} 实际=<<{lines[n-1].strip()}>> 期望含=<<{anchor}>>")

    # 5) evidence_path 存在性
    for i, row in enumerate(rows, start=2):
        for entry in split_entries(row["evidence_path"]):
            p = ROOT / EP_LINE_SUFFIX.sub("", entry)
            if not p.exists():
                problems.append(f"第 {i} 行 evidence_path 不存在: {entry}")

    print(f"总行数(不含表头): {len(rows)}")
    print("各 family 行数: " + ", ".join(f"{f}={seen.get(f, 0)}" for f in FAMILIES))
    print("evidence_status 分布: " + ", ".join(
        f"{s}={sum(1 for r in rows if r['evidence_status'] == s)}" for s in sorted(ALLOWED_STATUS)))

    if problems:
        print(f"\nFAIL: {len(problems)} 个问题")
        for p in problems:
            print("  - " + p)
        return 1
    print("\nPASS: CSV 可解析、八组齐全、字段一致、锚点与路径全部校验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
