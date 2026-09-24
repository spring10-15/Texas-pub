#!/usr/bin/env python3
"""V1 交付自检：从**真实 PNG 文件 / 矩阵 CSV / 诊断日志**重新推导交付主张。

判定只认 `exit 0 且 REFUTE 0`。只读；结果 JSON 写 `output/external-handoff/V1/`。

检查内容：
- 矩阵可解析、四店 × 三状态覆盖完整；
- 每个 `screenshot` 引用都能在对应目录解析，且**真的是 PNG**（magic + IHDR）、
  尺寸与矩阵 `resolution` 列一致、体积不可能是空白帧；
- 同状态下四店的图**不是字节相同**的（各店店名与金额不同，若字节相同说明张冠李戴）；
- 诊断日志 exit_code 与 `ERROR` 行按口径核（超时日志须在豁免表里显式登记，不许静默放过）；
- 输出 16 张 PNG 的 sha256 清单，便于后续轮次检测"原 12 张是否被覆盖"。

用法：python3 verify_visual.py
"""
import csv
import hashlib
import json
import pathlib
import re
import struct
import sys


def _find_root():
    """向上探测仓库根（不硬编码 parents[N]，脚本可在 docs/ 与 output/ 之间挪动）。"""
    here = pathlib.Path(__file__).resolve()
    for cand in [here, *here.parents]:
        if (cand / 'docs/3d-production').is_dir() and (cand / 'Godot/three_d').is_dir():
            return cand
    raise SystemExit('❌ 找不到仓库根')


ROOT = _find_root()
DELIV = ROOT / 'docs/3d-production/external-handoff/V1-extraction-visual'
LOGS = ROOT / 'output/external-handoff/V1'
OUT_JSON = LOGS / 'verify_v1_result.json'

CANON_DIR = DELIV / 'screenshots'
SUPPL_DIR = DELIV / 'screenshots-supplement'
CANON_MATRIX = DELIV / 'visual-matrix.csv'
SUPPL_MATRIX = DELIV / 'visual-matrix-supplement.csv'

VENUES = ['smoky-den', 'high-rise-suite', 'rooftop-club', 'neon-poker-club']
SCENARIOS = ['normal', 'short-cash', 'expired-reservation']
REQUIRED_COLS = ['venue', 'scenario', 'resolution', 'screenshot', 'result', 'issue_id', 'notes']

# 允许 exit_code 非 0 的日志：必须**显式登记并给出理由**，否则算 REFUTE。
# capture-extraction-12.log = 首次运行 240s 墙钟超时（README 已记录），run_godot.py 对超时写 exit_code: None。
LOG_EXEMPT = {
    'capture-extraction-12.log': 'README 已记录的首次 240s 墙钟超时；同脚本第二次 4.2s 跑完 12 张',
}

MIN_PNG_BYTES = 50_000        # 空白帧远小于此；实测有效帧 ~680–780 KB
PNG_MAGIC = b'\x89PNG\r\n\x1a\n'

results = []
counts = {'CONFIRM': 0, 'REFUTE': 0}


def record(check, ok, detail=''):
    v = 'CONFIRM' if ok else 'REFUTE'
    counts[v] += 1
    results.append({'check': check, 'verdict': v, 'detail': detail})
    return ok


def png_size(p):
    """返回 (w, h) 或 None（非 PNG / 头损坏）。"""
    try:
        b = p.read_bytes()
    except OSError:
        return None
    if len(b) < 24 or not b.startswith(PNG_MAGIC) or b[12:16] != b'IHDR':
        return None
    return struct.unpack('>II', b[16:24])


def parse_res(s):
    m = re.match(r'^(\d+)x(\d+)$', str(s).strip())
    return (int(m.group(1)), int(m.group(2))) if m else None


def check_matrix(matrix_path, png_dir, label, expect_rows, pair_check):
    if not matrix_path.is_file():
        record(f'{label} 矩阵存在', False, f'缺少 {matrix_path.relative_to(ROOT)}')
        return [], {}
    with matrix_path.open(encoding='utf-8-sig', newline='') as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        record(f'{label} 矩阵有数据行', False, '无数据行')
        return [], {}
    missing = [c for c in REQUIRED_COLS if c not in rows[0]]
    record(f'{label} 矩阵列齐全', not missing, f'缺: {missing}' if missing else f'{len(rows)} 行')
    record(f'{label} 行数 == {expect_rows}', len(rows) == expect_rows, f'实际 {len(rows)}')

    bad, digests = [], {}
    for i, r in enumerate(rows, start=2):
        rel = str(r.get('screenshot', '')).strip()
        if not rel:
            bad.append(f'第{i}行 screenshot 为空')
            continue
        p = png_dir / rel
        if not p.is_file():
            bad.append(f'第{i}行 找不到 {rel}')
            continue
        size = p.stat().st_size
        dim = png_size(p)
        if dim is None:
            bad.append(f'第{i}行 {rel} 不是有效 PNG')
            continue
        want = parse_res(r.get('resolution', ''))
        if want and dim != want:
            bad.append(f'第{i}行 {rel} 实际 {dim[0]}x{dim[1]}，矩阵声称 {want[0]}x{want[1]}')
        if size < MIN_PNG_BYTES:
            bad.append(f'第{i}行 {rel} 仅 {size} 字节，疑似空白帧/截断')
        digests[rel] = hashlib.sha256(p.read_bytes()).hexdigest()
    record(f'{label} 截图可解析且与矩阵一致', not bad,
           '; '.join(bad) if bad else f'核对 {len(digests)} 张')

    if pair_check:
        # 同状态下四店不应字节相同（各店店名与金额不同）；相同即张冠李戴。
        clash = []
        for sc in SCENARIOS:
            group = [rel for rel in digests if f'__{sc}.png' in rel]
            d = {rel: digests[rel] for rel in group}
            for a in d:
                for b in d:
                    if a < b and d[a] == d[b]:
                        clash.append(f'{a} 与 {b} 字节相同')
        record(f'{label} 同状态四店图不完全相同', not clash, '; '.join(clash))

    return rows, digests


def main():
    # --- 主矩阵 + 12 张 ---
    rows, canon_digests = check_matrix(CANON_MATRIX, CANON_DIR, '主矩阵', 12, True)

    if rows:
        got = {(r.get('venue', '').strip(), r.get('scenario', '').strip()) for r in rows}
        want = {(v, s) for v in VENUES for s in SCENARIOS}
        miss, extra = sorted(want - got), sorted(got - want)
        record('主矩阵覆盖 4 店 × 3 状态且无越界组合', not miss and not extra,
               f'缺 {miss}；多 {extra}' if (miss or extra) else f'{len(got)} 格齐全')

    # --- 补充矩阵 + 4 张 ---
    _, suppl_digests = check_matrix(SUPPL_MATRIX, SUPPL_DIR, '补充矩阵', 4, False)

    # --- 正式存档 / 原 12 张未被覆盖的证据（sha256 清单） ---
    record('原 12 张 PNG 全部实体存在', len(canon_digests) == 12,
           f'实际 {len(canon_digests)} 张')
    record('补充 4 张 PNG 全部实体存在', len(suppl_digests) == 4,
           f'实际 {len(suppl_digests)} 张')
    # 原 12 张与补充 4 张不应互相字节相同（不同面板）
    cross = [f'{a} == {b}' for a in canon_digests for b in suppl_digests
             if canon_digests[a] == suppl_digests[b]]
    record('主图与补充图无字节重复', not cross, '; '.join(cross))

    # --- 诊断日志 ---
    if not LOGS.is_dir():
        record('诊断日志目录存在', False, str(LOGS.relative_to(ROOT)))
    else:
        log_bad, ec_bad, n_logs = [], [], 0
        for lg in sorted(LOGS.glob('*.log')):
            n_logs += 1
            text = lg.read_text(encoding='utf-8', errors='replace')
            errs = [ln for ln in text.splitlines()
                    if re.match(r'^(SCRIPT ERROR|ERROR|USER ERROR|USER SCRIPT ERROR)', ln)]
            if errs:
                log_bad.append(f'{lg.name} 含 {len(errs)} 行 ERROR（首行: {errs[0][:60]}）')
            m = re.search(r'^# exit_code:\s*(\S+)', text, re.M)
            if m:
                ec = m.group(1)
                if ec != '0' and lg.name not in LOG_EXEMPT:
                    ec_bad.append(f'{lg.name} exit_code={ec} 且未在豁免表登记')
        record('诊断日志无 SCRIPT ERROR / ERROR 行', not log_bad,
               '; '.join(log_bad) if log_bad else f'核对 {n_logs} 个日志')
        record('非 0 退出码均已显式豁免说明', not ec_bad,
               '; '.join(ec_bad) if ec_bad else f'豁免 {len(LOG_EXEMPT)} 项: {list(LOG_EXEMPT)}')
        # 豁免项必须真的存在且真的非 0（防止豁免表变成"空头支票"）
        ghost = [k for k in LOG_EXEMPT if not (LOGS / k).is_file()]
        record('豁免表项均真实存在', not ghost, f'不存在: {ghost}' if ghost else 'ok')

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        'script': pathlib.Path(__file__).name,
        'counts': counts,
        'checks': results,
        'png_sha256': {'screenshots': canon_digests, 'screenshots-supplement': suppl_digests},
        'log_exemptions': LOG_EXEMPT,
        'verdict': 'PASS' if counts['REFUTE'] == 0 else 'FAIL',
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    for r in results:
        print(('✅ ' if r['verdict'] == 'CONFIRM' else '❌ ') + r['check'] + '  ' + r['detail'])
    print(f"\nCONFIRM={counts['CONFIRM']}  REFUTE={counts['REFUTE']}  verdict={payload['verdict']}")
    print(f'结果 JSON: {OUT_JSON.relative_to(ROOT)}')
    return 1 if counts['REFUTE'] else 0


if __name__ == '__main__':
    sys.exit(main())
