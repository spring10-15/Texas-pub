#!/usr/bin/env python3
"""A3 交付自检：从**源码 / 覆盖目录 / 测试**重新推导 `outcomes.csv` 的每条主张。

判定只认退出码与 REFUTE 计数：**exit 0 且 REFUTE 0** 才算通过。
本脚本只读；不写任何交付文件，只把结果 JSON 写到 `output/external-handoff/A3/`。

自检原则（本项目口径）：
- **跳过必须可见**：输入缺失一律计入 REFUTE，不静默 continue。
- **不把静态检查条数当语义结果数**：本脚本检查的是"主张是否可复核"，不宣称覆盖率。
- **行号用内容锚点**：不看行号本身是否"好看"，而是验证引用的行区间**确实落在它声称的那个函数体内**。

用法：python3 verify_outcomes.py
"""
import csv
import json
import pathlib
import re
import sys

def _find_root():
    """向上探测仓库根：找同时含 docs/3d-production 与 Godot/three_d 的祖先目录。

    不用硬编码 parents[N]——脚本可能在 docs/ 与 output/ 之间挪动，下标会失效。
    """
    for cand in [pathlib.Path(__file__).resolve(), *pathlib.Path(__file__).resolve().parents]:
        if (cand / 'docs/3d-production').is_dir() and (cand / 'Godot/three_d').is_dir():
            return cand
    raise SystemExit('❌ 找不到仓库根（向上探测 docs/3d-production 与 Godot/three_d 均失败）')


ROOT = _find_root()
CSV_PATH = ROOT / 'docs/3d-production/external-handoff/A3-poker-audit/outcomes.csv'
TRANSITIONS = ROOT / 'docs/3d-production/phase-1/coverage/transitions.json'
OUT_JSON = ROOT / 'output/external-handoff/A3/verify_a3_result.json'

REQUIRED_COLS = ['family', 'source_entry', 'source_line', 'precondition', 'action',
                 'accepted_or_rejected', 'postcondition', 'existing_catalog_id',
                 'existing_test', 'evidence_status', 'evidence_path', 'notes']
FAMILIES = ['short_all_in', 'exact_call_all_in', 'queue_reopen',
            'lone_funded_queue', 'aggression_discount', 'next_hand_heads_up']
STATUSES = ['已登记且有后继状态证据', '有测试但未登记', '未找到测试', '不可到达']

results = []          # {'check': str, 'verdict': 'CONFIRM'|'REFUTE', 'detail': str}
counts = {'CONFIRM': 0, 'REFUTE': 0}


def record(check, ok, detail=''):
    verdict = 'CONFIRM' if ok else 'REFUTE'
    counts[verdict] += 1
    results.append({'check': check, 'verdict': verdict, 'detail': detail})
    return ok


# ---------- 工具 ----------

FUNC_RE = re.compile(r'^func\s+([A-Za-z_][\w]*)\s*\(')
# 路径段不得含 `:`，扩展名放宽到任意字母数字（原先只列了 gd/json/py/... 会把 `.log` 误判为断链），
# 行号部分可选：`path:12` 或 `path:12-34`。
LOC_RE = re.compile(
    r'^(?P<path>[^\s:;（()]+?\.[A-Za-z0-9_]+)(?::(?P<a>\d+)(?:-(?P<b>\d+))?)?$')


def split_refs(cell):
    """把 'a; b; c' 拆成条目，剥掉行号与中文括注/括号尾巴。"""
    out = []
    for part in str(cell).split(';'):
        part = part.strip()
        if not part:
            continue
        # 去掉 （…） / (…) 尾巴（如 "xxx.gd:58-60（间接）"）
        part = re.sub(r'[（(][^）)]*[）)]\s*$', '', part).strip()
        if part:
            out.append(part)
    return out


def parse_loc(ref):
    """返回 (rel_path, start, end) 或 None。"""
    m = LOC_RE.match(ref)
    if not m:
        return None
    a = int(m.group('a')) if m.group('a') else None
    b = int(m.group('b')) if m.group('b') else a
    return m.group('path'), a, b


def func_spans(rel_path):
    """{func_name: (start_line, end_line)} —— 1-based，end 为下一个 func 前一行或 EOF。"""
    p = ROOT / rel_path
    if not p.is_file():
        return None
    lines = p.read_text(encoding='utf-8', errors='replace').splitlines()
    starts = [(i + 1, m.group(1)) for i, ln in enumerate(lines)
              if (m := FUNC_RE.match(ln))]
    spans = {}
    for idx, (lineno, name) in enumerate(starts):
        end = starts[idx + 1][0] - 1 if idx + 1 < len(starts) else len(lines)
        spans[name] = (lineno, end)
    return spans


# ---------- 主流程 ----------

def main():
    if not CSV_PATH.is_file():
        record('输入存在性', False, f'缺少 {CSV_PATH.relative_to(ROOT)}')
        return finish()
    if not TRANSITIONS.is_file():
        record('输入存在性', False, f'缺少 {TRANSITIONS.relative_to(ROOT)}')
        return finish()

    with CSV_PATH.open(encoding='utf-8-sig', newline='') as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        record('输入存在性', False, 'outcomes.csv 无数据行')
        return finish()

    # C1 列齐全
    missing = [c for c in REQUIRED_COLS if c not in rows[0]]
    record('C1 CSV 含任务书要求的 12 列', not missing, f'缺列: {missing}' if missing else f'{len(rows)} 行')

    # C2 六个 family 齐全
    present = {r['family'] for r in rows}
    absent = [f for f in FAMILIES if f not in present]
    record('C2 六个 family 全部出现', not absent, f'缺: {absent}' if absent else f'出现 {len(present)} 个')

    # C3 行号内容锚点：引用的行区间必须落在它声称的入口函数体内。
    # source_entry 允许 "A -> B" 链式写法（本 CSV 第 8 行即 `Table.advance -> Poker.settle_pots`），
    # 此时**命中链上任一环节的函数体**即算通过——链表示"这条语义由这几个入口共同产生"。
    anchor_bad, anchor_checked = [], 0
    for i, r in enumerate(rows, start=2):
        chain = [seg.strip().split('.')[-1]
                 for seg in r['source_entry'].split('->') if seg.strip()]
        for ref in split_refs(r['source_line']):
            loc = parse_loc(ref)
            if not loc:
                anchor_bad.append(f'第{i}行 source_line 无法解析: {ref!r}')
                continue
            rel, a, b = loc
            if a is None:
                anchor_bad.append(f'第{i}行 source_line 缺行号: {ref!r}')
                continue
            spans = func_spans(rel)
            if spans is None:
                anchor_bad.append(f'第{i}行 source_line 文件不存在: {rel}')
                continue
            anchor_checked += 1
            named = [c for c in chain if c in spans]
            if not named:
                anchor_bad.append(f'第{i}行 {rel} 中找不到入口函数 {chain}')
                continue
            if not any(spans[c][0] <= a and b <= spans[c][1] for c in named):
                anchor_bad.append(
                    f'第{i}行 声称 {" / ".join(chain)} 的 {a}-{b}，'
                    f'实际函数体: ' + ', '.join(f'{c}={spans[c][0]}-{spans[c][1]}' for c in named))
    record('C3 source_line 落在所声称入口的函数体内', not anchor_bad,
           '; '.join(anchor_bad) if anchor_bad else f'核对 {anchor_checked} 处引用')

    # C4 existing_catalog_id 必须真实存在
    cat = json.loads(TRANSITIONS.read_text(encoding='utf-8'))
    known = {t['id'] for t in cat['transitions']}
    id_bad, id_count = [], 0
    for i, r in enumerate(rows, start=2):
        for cid in split_refs(r['existing_catalog_id']):
            id_count += 1
            if cid not in known:
                id_bad.append(f'第{i}行 {cid!r} 不在 transitions.json')
    record('C4 existing_catalog_id 均存在于覆盖目录', not id_bad,
           '; '.join(id_bad) if id_bad else f'核对 {id_count} 个 ID')

    # C5 existing_test / evidence_path 里的路径必须存在
    path_bad, path_count = [], 0
    for i, r in enumerate(rows, start=2):
        for col in ('existing_test', 'evidence_path'):
            for ref in split_refs(r[col]):
                loc = parse_loc(ref)
                if not loc:
                    path_bad.append(f'第{i}行 {col} 无法解析: {ref!r}')
                    continue
                path_count += 1
                if not (ROOT / loc[0]).exists():
                    path_bad.append(f'第{i}行 {col} 路径不存在: {loc[0]}')
    record('C5 引用路径均可从仓库根打开', not path_bad,
           '; '.join(path_bad) if path_bad else f'核对 {path_count} 个路径')

    # C6 状态与两列的三角一致性
    tri_bad = []
    for i, r in enumerate(rows, start=2):
        st, cid, tst = r['evidence_status'], r['existing_catalog_id'].strip(), r['existing_test'].strip()
        if st not in STATUSES:
            tri_bad.append(f'第{i}行 evidence_status 非法: {st!r}')
        elif st == '已登记且有后继状态证据':
            if not cid:
                tri_bad.append(f'第{i}行 {st} 却没有 catalog_id')
            if not tst:
                tri_bad.append(f'第{i}行 {st} 却没有测试')
        elif st == '有测试但未登记':
            if cid:
                tri_bad.append(f'第{i}行 {st} 却填了 catalog_id: {cid!r}')
            if not tst:
                tri_bad.append(f'第{i}行 {st} 却没有测试')
        elif st == '未找到测试':
            if tst:
                tri_bad.append(f'第{i}行 {st} 却填了测试: {tst!r}')
    record('C6 evidence_status 与 catalog_id/测试列自洽', not tri_bad,
           '; '.join(tri_bad) if tri_bad else f'核对 {len(rows)} 行')

    # C7 accepted_or_rejected 取值
    ar_bad = [f'第{i}行 {r["accepted_or_rejected"]!r}'
              for i, r in enumerate(rows, start=2)
              if r['accepted_or_rejected'] not in ('accepted', 'rejected')]
    record('C7 accepted_or_rejected ∈ {accepted, rejected}', not ar_bad, '; '.join(ar_bad))

    return finish()


def finish():
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        'script': pathlib.Path(__file__).name,
        'csv': str(CSV_PATH.relative_to(ROOT)),
        'counts': counts,
        'checks': results,
        'verdict': 'PASS' if counts['REFUTE'] == 0 else 'FAIL',
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    for r in results:
        mark = '✅' if r['verdict'] == 'CONFIRM' else '❌'
        print(f"{mark} {r['check']}  {r['detail']}")
    print(f"\nCONFIRM={counts['CONFIRM']}  REFUTE={counts['REFUTE']}  "
          f"verdict={payload['verdict']}")
    print(f'结果 JSON: {OUT_JSON.relative_to(ROOT)}')
    return 1 if counts['REFUTE'] else 0


if __name__ == '__main__':
    sys.exit(main())
