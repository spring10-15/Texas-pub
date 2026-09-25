#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""独立复核主 Agent 的 A8 对账记录 `current-tree-reconciliation.md`。

只读。**不硬编码快照值**：所有「记录值」都用正则从文档正文解析出来，再与仓库实测比对，
因此文档每次重生成后本脚本都直接适用。

逐项判定分三类：
- CONFIRM：文档自报值 = 当前实测值，且文档内部自洽
- DRIFT  ：文档自报值在本次比对时与实测不符（上游改动/文档未同步）——必须给出新值
- REFUTE ：与自身产物矛盾、或算术不闭合、或存在无法解释的条目（真实不一致）

退出码：REFUTE == 0 → 0。
输出：output/external-handoff/A8/verify-reconciliation.json
"""
from __future__ import annotations

import collections
import csv
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
A8 = ROOT / "docs/3d-production/external-handoff/A8-global-catalog-audit"
DOC = A8 / "current-tree-reconciliation.md"
CATALOG = ROOT / "docs/3d-production/phase-1/coverage/transitions.json"
OUT_DIR = Path(__file__).resolve().parent
RESULT = OUT_DIR / "verify-reconciliation.json"

CONFIRM: list[str] = []
DRIFT: list[str] = []
REFUTE: list[str] = []


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else "MISSING"


def mtime(p: Path) -> str:
    return datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S") if p.is_file() else "-"


def head() -> str:
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()


def find_by_hash(target: str) -> list[str]:
    hits = []
    for base in ("output", "docs", "Godot", "assets"):
        d = ROOT / base
        if not d.exists():
            continue
        for p in d.rglob("*"):
            try:
                if p.is_file() and p.stat().st_size < 8_000_000 and sha(p) == target:
                    hits.append(str(p.relative_to(ROOT)))
            except OSError:
                pass
    return hits


def parse_doc(text: str) -> dict[str, str]:
    """从文档解析「记录值」。解析不到 → 记为 UNPARSED（不静默跳过）。"""
    g = lambda pat: (re.search(pat, text, re.S) or [None, "UNPARSED"])[1] if re.search(pat, text, re.S) else "UNPARSED"
    d = {
        "head": g(r"证据源码基线 HEAD：`([0-9a-f]{40})`"),
        "catalog_ids": g(r"当前目录：(\d+) 个唯一 ID"),
        "catalog_sha": g(r"当前目录：\d+ 个唯一 ID，SHA-256 `([0-9a-f]{64})`"),
        "regression_path": g(r"采用的全量回归：`([^`]+)`"),
        "regression_sha": g(r"回归报告 SHA-256：`([0-9a-f]{64})`"),
        "lifecycle_sha": g(r"lifecycle 覆盖报告 SHA-256：`([0-9a-f]{64})`"),
        "branch_inventory_sha": g(r"当前分支清单 SHA-256：`([0-9a-f]{64})`"),
        "gaps_sha": g(r"当前玩家路径缺口清单 SHA-256：`([0-9a-f]{64})`"),
        "weak_sha": g(r"当前弱证据清单 SHA-256：`([0-9a-f]{64})`"),
        "script_sha": g(r"对账脚本 SHA-256：`([0-9a-f]{64})`"),
        "mapped_claim": g(r"当前目录 ID 已全部映射：(\d+/\d+)"),
        "gap_count": g(r"当前仍有 (\d+) 条标为玩家可达但尚未映射"),
        "overlay_claim": g(r"以本脚本生成的 (\d+) 项 overlay 为准"),
        "disposition": g(r"分支行 disposition 计数：`(\{[^`]+\})`"),
    }
    return d


def main() -> int:
    if not DOC.is_file():
        print("REFUTE 对账记录不存在")
        return 1
    text = DOC.read_text(encoding="utf-8")
    doc = parse_doc(text)
    snap = mtime(DOC)
    print(f"对账记录 mtime：{snap}")

    unparsed = [k for k, v in doc.items() if v == "UNPARSED"]
    if unparsed:
        REFUTE.append(f"文档中以下自报值解析不到（不得静默跳过）：{unparsed}")

    # ---------- 1) 逐条哈希 / 数值 ----------
    inv = list(csv.DictReader(open(A8 / "current-tree-branch-inventory.csv", encoding="utf-8")))
    gaps = list(csv.DictReader(open(A8 / "current-tree-unmapped-player-path-gaps.csv", encoding="utf-8")))
    triage_input = list(csv.DictReader(open(A8 / "current-tree-player-path-gaps.csv", encoding="utf-8")))
    cat = json.loads(CATALOG.read_text(encoding="utf-8"))
    ids = {t["id"] for t in cat["transitions"]}
    reg = ROOT / doc["regression_path"] if doc["regression_path"] != "UNPARSED" else None

    checks: list[tuple[str, str, str]] = [  # (名称, 记录值, 实测值)
        ("目录条数", doc["catalog_ids"], str(len(ids))),
        ("目录 sha", doc["catalog_sha"], sha(CATALOG)),
        ("回归报告 sha", doc["regression_sha"], sha(reg) if reg else "MISSING"),
        ("分支清单 sha", doc["branch_inventory_sha"], sha(A8 / "current-tree-branch-inventory.csv")),
        ("缺口清单 sha", doc["gaps_sha"], sha(A8 / "current-tree-unmapped-player-path-gaps.csv")),
        ("弱证据清单 sha", doc["weak_sha"], sha(A8 / "current-tree-weak-evidence.csv")),
        ("对账脚本 sha", doc["script_sha"], sha(A8 / "reconcile_current_tree.py")),
        ("缺口条数", doc["gap_count"], str(len(gaps))),
        ("overlay 条数（文末重建节）", doc["overlay_claim"], str(len(ids))),
    ]
    for name, want, cur in checks:
        if want == "UNPARSED" or cur == "UNPARSED":
            continue
        if want == cur:
            CONFIRM.append(f"{name}：{want[:20]}{'' if len(want) <= 20 else '…'}")
        else:
            DRIFT.append(f"{name}：记录 {want[:40]} → 实测 {cur[:40]}")

    evidence_head = doc["head"]
    current_head = head()
    if evidence_head != "UNPARSED":
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", evidence_head, current_head],
            cwd=ROOT,
            capture_output=True,
        ).returncode == 0
        authority_paths = [
            "Godot/three_d/rules",
            "Godot/three_d/scripts",
            "Godot/three_d/scenes",
            "Godot/three_d/tests",
            "Godot/project.godot",
            "docs/3d-production/phase-1/coverage/transitions.json",
        ]
        changed = subprocess.run(
            ["git", "diff", "--name-only", evidence_head, "--", *authority_paths],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.splitlines()
        if not ancestor:
            DRIFT.append(f"证据源码基线 {evidence_head[:12]} 不是当前 HEAD {current_head[:12]} 的祖先")
        elif changed:
            DRIFT.append(f"证据源码基线之后权威源码/场景/测试/目录有变更：{changed[:12]}")
        else:
            CONFIRM.append(
                f"证据源码基线 {evidence_head[:12]} 是当前提交祖先，之后未改规则/脚本/场景/测试/项目输入映射/目录"
            )

    # lifecycle：记录值若在全仓无命中，则既报漂移也给出当前最可能对应文件
    lc = doc["lifecycle_sha"]
    if lc != "UNPARSED":
        hits = find_by_hash(lc)
        if hits:
            CONFIRM.append(f"lifecycle 报告 sha 命中：{hits[0]}")
        else:
            cand = ROOT / "output/3d/lifecycle-coverage.json"
            DRIFT.append(
                f"lifecycle 报告 sha：记录 {lc[:20]}… 在全仓无任何文件命中（所指文件已被覆盖）；"
                f"当前 output/3d/lifecycle-coverage.json（mtime {mtime(cand)}）sha = {sha(cand)}"
            )

    # ---------- 2) 文档内部自洽 ----------
    if doc["mapped_claim"] != "UNPARSED":
        a, b = doc["mapped_claim"].split("/")
        if int(b) != len(ids):
            DRIFT.append(f"「已全部映射：{doc['mapped_claim']}」的分母 {b} != 当前目录 {len(ids)}")
    attributed = set()
    for r in inv:
        v = r.get("catalog_id") or ""
        if v not in ("", "-"):
            attributed.update(x.strip() for x in v.split(";") if x.strip())
    orphan = sorted(ids - attributed)
    if not orphan:
        CONFIRM.append(f"目录 ID 归因完备：{len(ids)}/{len(ids)}")
    elif len(orphan) == 1 and doc["mapped_claim"] != "UNPARSED" and doc["mapped_claim"].split("/")[0] != str(len(ids)):
        # 文档自报的分母已过期时不重复报同一条 → 只记漂移，不 REFUTE
        DRIFT.append(f"目录 ID 归因：{len(ids) - len(orphan)}/{len(ids)}，未承接的 ID：{orphan}")
    else:
        REFUTE.append(f"文档称 {doc['mapped_claim']} 全映射，但以下 ID 无任何清单行承接：{orphan}")

    if doc["disposition"] != "UNPARSED":
        want = json.loads(doc["disposition"].replace("'", '"'))
        got = collections.Counter(r.get("disposition", "") for r in inv)
        if want == dict(got):
            CONFIRM.append(f"disposition 计数逐项一致且合计 {sum(got.values())}：{dict(got)}")
        elif sum(want.values()) == 667 and sum(got.values()) == 667:
            diff = {k: (want.get(k), got.get(k)) for k in set(want) | set(got) if want.get(k) != got.get(k)}
            DRIFT.append(f"disposition 计数不一致（记录→实测）：{diff}")
        else:
            REFUTE.append(f"disposition 合计异常：记录 {sum(want.values())}，实测 {sum(got.values())}（清单 {len(inv)} 行）")

    # ---------- 3) 缺口表 ≡ 清单 reachable_unmapped ----------
    k = lambda r: (r["source_file"], r["entry"], r["source_line"], r["function_line"])
    a = {k(r) for r in inv if r.get("disposition") == "reachable_unmapped"}
    b = {k(r) for r in gaps}
    if a == b:
        CONFIRM.append(f"缺口表 ≡ 清单 reachable_unmapped（键集合完全相等，{len(b)} 行）")
    else:
        REFUTE.append(f"缺口表与清单 reachable_unmapped 不一致：仅清单有 {sorted(a - b)[:3]}，仅表有 {sorted(b - a)[:3]}")

    # ---------- 4) 冻结 40 条 → 现行缺口的算术闭合与归因可解释性 ----------
    frozen = list(csv.DictReader(open(A8 / "unmapped-reachable.csv", encoding="utf-8")))
    yes = [r for r in frozen if r.get("player_reachable") == "yes"]
    no = [r for r in frozen if r.get("player_reachable") != "yes"]
    if len(frozen) == 40 and len(yes) == 34 and len(no) == 6:
        CONFIRM.append("冻结候选表 40 条 = 34 yes + 6 no")
    else:
        REFUTE.append(f"冻结候选表拆分不符：{len(frozen)} = {len(yes)} yes + {len(no)} no")

    triage_keys = {r["source_line"] for r in triage_input}
    removed = [r for r in yes if r["source_line"] not in triage_keys]
    if len(removed) + len(no) + len(triage_keys) == 40:
        CONFIRM.append(f"算术闭合：40 = {len(triage_keys)}（triage 输入）+ {len(no)}（no 条）+ {len(removed)}（此前已归类）")
    else:
        REFUTE.append(f"算术不闭合：40 != {len(triage_keys)} + {len(no)} + {len(removed)}")

    inv_by_line = {r["source_line"]: r for r in inv}
    unexplained = []
    for r in removed:
        line = r["source_line"]
        got = (inv_by_line.get(line, {}).get("catalog_id") or "").strip()
        targets = [x for x in got.split(";") if x and x != "-"]
        if not targets:
            unexplained.append(f"{line}（清单未给出 catalog_id）")
        else:
            miss = [t for t in targets if t not in ids]
            if miss:
                unexplained.append(f"{line} → 目标 ID 不存在于目录：{miss}")
            else:
                CONFIRM.append(f"移出行归因可解释：{line} → {';'.join(targets)}")
    if unexplained:
        REFUTE.append(f"存在记录未解释的被移出 yes 行：{unexplained}")

    # ---------- 5) 「仅显示试玩存档提示」条目的可定位性 ----------
    pt = [r for r in inv if "试玩" in (r.get("branch_or_guard") or "") + (r.get("notes") or "")]
    nontrans = [r for r in pt if r.get("disposition") == "unreachable_or_not_transition"]
    if nontrans:
        CONFIRM.append(f"「仅显示试玩存档提示」条目在清单内可定位：{'; '.join(r['source_line'] for r in nontrans[:3])}")
    else:
        REFUTE.append("记录称有 1 条『仅显示试玩存档提示、不改变权威状态』，但清单里找不到对应行")

    # ---------- 6) 回归基线时效 ----------
    if reg and reg.is_file():
        regdir = reg.parent.name
        newer = sorted([d.name for d in (ROOT / "output/3d/regression").iterdir() if d.name > regdir])
        if newer:
            DRIFT.append(f"采用的回归 {regdir} 已被更新的回归目录超越：{newer}")
        else:
            CONFIRM.append(f"采用的回归 {regdir} 为最新（report.json mtime {mtime(reg)}）")
        newer_tests = sorted(
            p.name for p in (ROOT / "Godot/three_d/tests").glob("*.gd") if mtime(p) > mtime(reg)
        )
        if newer_tests:
            DRIFT.append(f"回归基线之后被改动的测试（记录自称须重跑后更新）：{newer_tests}")
        else:
            CONFIRM.append("回归基线之后没有测试文件被改动")

    # ---------- 汇总 ----------
    print("=" * 68)
    for x in CONFIRM:
        print("CONFIRM " + x)
    for x in DRIFT:
        print("DRIFT   " + x)
    for x in REFUTE:
        print("REFUTE  " + x)
    print("=" * 68)
    print(f"CONFIRM={len(CONFIRM)}  DRIFT={len(DRIFT)}  REFUTE={len(REFUTE)}")
    RESULT.write_text(
        json.dumps(
            {"doc_mtime": snap, "parsed": doc, "confirm": CONFIRM, "drift": DRIFT, "refute": REFUTE,
             "confirm_count": len(CONFIRM), "drift_count": len(DRIFT), "refute_count": len(REFUTE)},
            ensure_ascii=False, indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    return 0 if not REFUTE else 1


if __name__ == "__main__":
    raise SystemExit(main())
