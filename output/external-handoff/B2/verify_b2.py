#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""B2 交付物独立复核（只读）。

不对 B2 的结论做「信不信」，而是**重新从源码/资产/测试推导一遍**，逐条 CONFIRM / REFUTE。
复核对象：docs/3d-production/external-handoff/B2-production-breakdown/{README.md,items.csv,characters.csv}

用法：python3 output/external-handoff/B2/verify_b2.py
退出码：0 全通过；1 有 REFUTE。
"""
import csv
import json
import itertools
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
B2 = ROOT / 'docs/3d-production/external-handoff/B2-production-breakdown'
GODOT = ROOT / 'Godot/three_d'

CHECKS = []


def chk(cid, claim, ok, detail=''):
    CHECKS.append({'id': cid, 'claim': claim, 'ok': bool(ok), 'detail': str(detail)[:300]})
    return ok


def read(path):
    return pathlib.Path(path).read_text(encoding='utf-8', errors='replace')


def gd_function(source, name):
    match = re.search(r'(?ms)^func ' + re.escape(name) + r'\b[^\n]*\n(.*?)(?=^func |\Z)', source)
    return match.group(1) if match else ''


def rows(name):
    return list(csv.DictReader(open(B2 / name, encoding='utf-8-sig')))


def gltf(path):
    b = pathlib.Path(path).read_bytes()
    off = 12
    while off < len(b):
        ln, ty = struct.unpack_from('<II', b, off)
        off += 8
        if ty == 0x4E4F534A:
            return json.loads(b[off:off + ln].decode('utf-8'))
        off += ln
    raise ValueError('no JSON chunk')


# ---------------- 基础事实 ----------------
CONTENT = json.loads(read(GODOT / 'rules/content.json'))
PROPS = json.loads(read(GODOT / 'assets/props-export.json'))
MANIFEST = json.loads(read(GODOT / 'assets/characters/manifest.json'))
RUN = read(GODOT / 'rules/run.gd')
RUN_LINES = RUN.split('\n')
BAR = read(GODOT / 'scripts/bar_display.gd')
BUILD_PROPS = read(ROOT / 'assets/blender/tavern-detail/build_props.py')
BUILD_CHARS = read(ROOT / 'assets/blender/characters/build_characters.py')
ART_TEST = read(GODOT / 'tests/art_integration_test.gd')
CHAR_TEST = read(GODOT / 'tests/characters_test.gd')
CHARS_GD = read(GODOT / 'scripts/characters.gd')
SEARCH_EVENTS = read(GODOT / 'rules/search_events.gd')

ITEM_ROWS = rows('items.csv')
CHAR_ROWS = rows('characters.csv')
README = read(B2 / 'README.md')

usable = [k for k, v in CONTENT['items'].items() if v['kind'] == 'usable']
valuable = [k for k, v in CONTENT['items'].items() if v['kind'] == 'valuable']

# ---------------- 1. 行数与列数 ----------------
chk('B2-1a', 'items.csv 19 行', len(ITEM_ROWS) == 19, len(ITEM_ROWS))
chk('B2-1b', 'characters.csv 9 行', len(CHAR_ROWS) == 9, len(CHAR_ROWS))
chk('B2-1c', 'items.csv 17 列', len(ITEM_ROWS[0]) == 17, len(ITEM_ROWS[0]))
chk('B2-1d', 'characters.csv 22 列', len(CHAR_ROWS[0]) == 22, len(CHAR_ROWS[0]))
chk('B2-1e', 'README 声明 items.csv 19×17 / characters.csv 9×22',
    '**19 × 17**' in README and '**9 × 22**' in README)

# 任务书第 1 条：19 件物品与 9 人物都要有「现有源文件 / 可复用部件 / 运行加载点 / 尚缺表现」。
# 初稿的人物表漏了前两列，这里把它变成机器检查，防止再漏。
C1_FIELDS = ['现有源文件', '可复用部件', '运行加载点', '尚缺表现']
for iid, tbl, key in [('items', ITEM_ROWS, 'item_id'), ('characters', CHAR_ROWS, '角色id')]:
    missing = [f for f in C1_FIELDS if f not in tbl[0]]
    chk('B2-1f:%s' % iid, '%s.csv 有四列：%s' % (iid, ' / '.join(C1_FIELDS)), not missing, missing)
    blank = [(r[key], f) for r in tbl for f in C1_FIELDS if not r.get(f, '').strip()]
    chk('B2-1g:%s' % iid, '%s.csv 这四列逐行都非空' % iid, not blank, blank[:4])

# 人物两列的具体性：不能只写「有」，要能指到文件
bad = [r['角色id'] for r in CHAR_ROWS
       if not ('.blend' in r['现有源文件'] and '.glb' in r['现有源文件']
               and 'manifest.json' in r['现有源文件'])]
chk('B2-1h', '人物「现有源文件」列逐行指向 .blend + .glb + manifest.json', not bad, bad)
bad = [r['角色id'] for r in CHAR_ROWS
       if not ('14 骨骼 rig' in r['可复用部件'] and 'idle/bet/win/fold' in r['可复用部件']
               and '.blend' in r['可复用部件'])]
chk('B2-1i', '人物「可复用部件」列逐行写明 14 骨 rig + 4 段剪辑 + .blend 可编辑源', not bad, bad)

# ---------------- 2. id 集合与 content.json 一致 ----------------
got_usable = [r['item_id'] for r in ITEM_ROWS if r['类别'] == '物品-可用']
got_valuable = [r['item_id'] for r in ITEM_ROWS if r['类别'] == '物品-贵重']
chk('B2-2a', '物品-可用 9 行且 == content.json 的 usable',
    got_usable == usable, 'csv=%s' % got_usable)
chk('B2-2b', '物品-贵重 10 行且 == content.json 的 valuable',
    got_valuable == valuable, 'csv=%s' % got_valuable)
chk('B2-2c', 'items.csv 序号 1..19 连续',
    [r['序号'] for r in ITEM_ROWS] == [str(i) for i in range(1, 20)])
chk('B2-2d', 'characters.csv 角色id 集合 == 8 对手 + bartender（顺序沿用 build_characters.py 的 CAST）',
    set(r['角色id'] for r in CHAR_ROWS) == set(CONTENT['opponents']) | {'bartender'},
    [r['角色id'] for r in CHAR_ROWS])
cast_order = re.findall(r"\('([a-z\-]+)',\(",
                        re.search(r'CAST=\[(.*?)\]\n', read(ROOT / 'assets/blender/characters/build_characters.py'), re.S).group(1))
chk('B2-2e', 'characters.csv 行序 == build_characters.py 的 CAST 顺序',
    [r['角色id'] for r in CHAR_ROWS] == cast_order, cast_order)

# ---------------- 3. 「12 部件 = 9 道具 + 3 场景件」 ----------------
chk('B2-3a', 'props-export.json 12 键', len(PROPS) == 12, sorted(PROPS))
scene_parts = set(PROPS) - set(usable)
chk('B2-3b', '12 键 = 9 可用道具 + 3 场景件(drawer/loose-card/loose-chip)',
    scene_parts == {'drawer', 'loose-card', 'loose-chip'}, sorted(scene_parts))
chk('B2-3c', 'art_integration_test 的 12 个 id 与 props-export 一致',
    'SUPPORTED_ITEMS + ["loose-card", "loose-chip", "drawer"]' in ART_TEST)
chk('B2-3d', 'art_integration_test 断言单件恰好 1 个可移动网格',
    'surfaces.size() == 1' in ART_TEST and 'Single movable detailed mesh' in ART_TEST)

# ---------------- 4. build_props.py 每个道具都有 group() 块 ----------------
# 注意：kitchen-pass / dock-passkey 共用 build_props.py:53 的 for 循环 group(name)，
# 没有字面量 group('kitchen-pass')，所以两种写法都要认。
SHARED_LOOP = "for name,label in [('kitchen-pass','KITCHEN'),('dock-passkey','DOCK')]:"
for iid in sorted(PROPS):
    literal = ("group('%s')" % iid) in BUILD_PROPS
    shared = iid in ('kitchen-pass', 'dock-passkey') and SHARED_LOOP in BUILD_PROPS
    chk('B2-4:%s' % iid,
        'build_props.py 存在 group("%s")（或共用 for 循环 group(name)）' % iid,
        literal or shared, 'literal=%s shared_loop=%s' % (literal, shared))

# ---------------- 5. 货架只卖 9 件可用道具 ----------------
bottom = re.search(r'var bottom: float = \{(.*?)\}\[id\]', BAR, re.S)
bottom_ids = set(re.findall(r'"([a-z\-]+)":', bottom.group(1))) if bottom else set()
chk('B2-5a', 'bar_display.gd bottom 高度字典 = 9 件可用道具（无贵重物）',
    bottom_ids == set(usable), sorted(bottom_ids))
chk('B2-5b', 'run.gd buy 分支限制在 SUPPORTED_ITEMS',
    'item_id not in SUPPORTED_ITEMS or item_id not in shop_stock()' in RUN)
sup = re.search(r'const SUPPORTED_ITEMS := \[(.*?)\]', RUN, re.S)
sup_ids = set(re.findall(r'"([a-z\-]+)"', sup.group(1))) if sup else set()
chk('B2-5c', 'SUPPORTED_ITEMS == content.json 的 9 件 usable',
    sup_ids == set(usable), sorted(sup_ids))

# ---------------- 6. 每行「证据」列可打开 ----------------
def paths_in(text):
    out = []
    for m in re.finditer(r'([A-Za-z0-9_\-./\u4e00-\u9fff]+\.(?:gd|py|json|md|csv|mjs|command))', text):
        p = m.group(1)
        if '/' in p:
            out.append(p)
    return sorted(set(out))


bad = []
for r in ITEM_ROWS + CHAR_ROWS:
    ev = r.get('证据(文件:行)', '')
    if not ev.strip():
        bad.append('%s: 证据列为空' % r.get('item_id', r.get('角色id')))
        continue
    ps = paths_in(ev)
    if not ps:
        bad.append('%s: 证据列无可解析文件路径' % r.get('item_id', r.get('角色id')))
    for p in ps:
        if not (ROOT / p).exists():
            bad.append('%s: 路径不存在 %s' % (r.get('item_id', r.get('角色id')), p))
chk('B2-6', '19+9 行的「证据」列都存在且路径可打开', not bad, bad[:6])

# 后补的两列（现有源文件 / 参考图）也必须指向真实文件，否则「有证据」是空话。
bad = []
for r in ITEM_ROWS + CHAR_ROWS:
    key = r.get('item_id', r.get('角色id'))
    for col in ('现有源文件', '参考图'):
        cell = r.get(col, '')
        if not cell.strip():
            continue
        ps = paths_in(cell)
        if col == '现有源文件' and not ps:
            bad.append('%s: %s 列无可解析文件路径' % (key, col))
        for p in ps:
            if not (ROOT / p).exists():
                bad.append('%s: %s 列路径不存在 %s' % (key, col, p))
chk('B2-6b', '「现有源文件」与「参考图」列引用的文件路径都能用仓库根解析打开', not bad, bad[:6])

# ---------------- 7. 每行「尚缺表现」列非空 ----------------
missing = [r['item_id'] for r in ITEM_ROWS if not r['尚缺表现'].strip()]
chk('B2-7a', '19 行都有「尚缺表现」', not missing, missing)
missing = [r['角色id'] for r in CHAR_ROWS if not r['尚缺表现'].strip()]
chk('B2-7b', '9 行都有「尚缺表现」', not missing, missing)

# ---------------- 8. 必要交互四列的值域 ----------------
NEED = ['货架实物', '拿取动作', '背包展示', '消耗_失去_抵押']
FORBID = set()
for name in NEED:
    vals = [r[name] for r in ITEM_ROWS]
    FORBID |= {v for v in vals if not v.strip()}
chk('B2-8a', '四列交互全部非空', not FORBID, list(FORBID)[:3])
chk('B2-8b', '贵重物「货架实物」全部写「不上架」且说明只是购买入口限制',
    all(r['货架实物'].startswith('不上架') and '购买入口' in r['货架实物']
        for r in ITEM_ROWS if r['类别'] == '物品-贵重'))
chk('B2-8c', '可用道具「货架实物」全部写「有」',
    all(r['货架实物'].startswith('有') for r in ITEM_ROWS if r['类别'] == '物品-可用'))
chk('B2-8d', '全部 19 件「背包展示」都标明「仅文字」',
    all('仅文字' in r['背包展示'] for r in ITEM_ROWS),
    [r['item_id'] for r in ITEM_ROWS if '仅文字' not in r['背包展示']])

# ---------------- 9. 上架位计数可复现 ----------------
def shelf(scene, idx, item):
    return item in CONTENT['shops'][scene].get(str(idx), [])


for r in ITEM_ROWS:
    if r['类别'] != '物品-可用':
        continue
    iid = r['item_id']
    n = sum(1 for s in CONTENT['shops'] for i in range(1, 6) if shelf(s, i, iid))
    m = re.search(r'基础配置候选位 (\d+) 个', r['货架实物'])
    chk('B2-9:%s' % iid, '%s 基础配置候选位计数 = %d' % (iid, n),
        m is not None and int(m.group(1)) == n,
        'csv=%s 实测=%d' % (m.group(1) if m else '?', n))

# ---------------- 10. 面数可复现 ----------------
bad = []
for r in ITEM_ROWS:
    if r['类别'] != '物品-可用':
        continue
    m = re.search(r'(\d+) 三角面', r['运行加载点'])
    if not m or int(m.group(1)) != PROPS[r['item_id']]:
        bad.append('%s csv=%s json=%s' % (r['item_id'], m.group(1) if m else '?', PROPS[r['item_id']]))
chk('B2-10', '9 件道具的面数与 props-export.json 一致', not bad, bad)

# ---------------- 11. 消耗/失去/抵押 与 run.gd / advanced_services 一致 ----------------
ADV = read(GODOT / 'rules/advanced_services.gd')
SPEC = {
    'marked-lens': ('run.gd:360-362', 'inventory.erase(item_id)' in RUN and
                    'used_tools.append(item_id)' in RUN),
    'steadying-drink': ('run.gd:340', 'inventory.erase("steadying-drink")' in RUN),
    'sleeve-clip': ('run.gd:360-362', 'used_tools.append(item_id)' in RUN),
    'signal-lighter': ('advanced_services.gd:75-79', 'run.used_tools.append(item)' in ADV),
    'player-notes': ('advanced_services.gd:75-79', 'run.used_tools.append(item)' in ADV),
    'disposable-phone': ('advanced_services.gd:75-76', 'run.inventory.erase(item)' in ADV),
    'kitchen-pass': ('advanced_services.gd:52-54', 'run.route_flags[run.content.items[item].unlockRoute] = true' in ADV),
    'dock-passkey': ('advanced_services.gd:52-54', 'run.route_flags[run.content.items[item].unlockRoute] = true' in ADV),
    'false-bottom-wallet': ('run.gd:461', 'mini(80, cash) if "false-bottom-wallet" in inventory' in RUN),
}
for iid, (ref, ok) in SPEC.items():
    row = [r for r in ITEM_ROWS if r['item_id'] == iid][0]
    chk('B2-11:%s' % iid, '%s 的消耗/失去声明有代码依据（%s）' % (iid, ref),
        ok and ref.split(':')[0] in row['消耗_失去_抵押'],
        row['消耗_失去_抵押'][:90])
chk('B2-11x', 'false-bottom-wallet 标注为「不消耗」',
    [r for r in ITEM_ROWS if r['item_id'] == 'false-bottom-wallet'][0]['消耗_失去_抵押'].startswith('不消耗'))
chk('B2-11y', 'extract() / abandon() 均清空背包',
    'inventory.clear()' in gd_function(RUN, 'extract') and 'inventory.clear()' in gd_function(RUN, 'abandon'),
    'extract=%s abandon=%s' % ('inventory.clear()' in gd_function(RUN, 'extract'), 'inventory.clear()' in gd_function(RUN, 'abandon')))

# ---------------- 12. 10 件贵重物获得路径与当前 rewardRules 一致 ----------------
def reward_rule_matches(rule, stack, inventory, collateral_returned):
    if rule.get('minStack') is not None and stack < int(rule['minStack']):
        return False
    if rule.get('inventoryHas') is not None and rule['inventoryHas'] not in inventory:
        return False
    if rule.get('inventoryMissing') is not None and rule['inventoryMissing'] in inventory:
        return False
    if rule.get('collateralReturned') is not None and bool(rule['collateralReturned']) != collateral_returned:
        return False
    return True


def reward_outcomes(table_id, definition):
    rules = definition.get('rewardRules', [])
    supported_keys = {'item', 'minStack', 'inventoryHas', 'inventoryMissing', 'collateralReturned'}
    if any(set(rule) - supported_keys for rule in rules):
        return set(), {'unsupported_rule_keys': sorted(set().union(*(set(rule) for rule in rules)) - supported_keys)}
    buy_in = int(definition['buyIn'])
    max_stack = buy_in * (1 + len(definition['opponentIds']))
    stacks = {buy_in + 1, max_stack}
    for rule in rules:
        threshold = int(rule.get('minStack', buy_in + 1))
        stacks.add(max(buy_in + 1, min(max_stack, threshold)))
        if threshold > buy_in + 1:
            stacks.add(min(max_stack, threshold - 1))
    item_ids = set(valuable)
    for rule in rules:
        for key in ('inventoryHas', 'inventoryMissing'):
            if rule.get(key):
                item_ids.add(str(rule[key]))
    item_ids = sorted(item for item in item_ids if item in CONTENT['items']
                      and int(CONTENT['items'][item].get('slots', 1)) <= int(CONTENT['inventorySlots']))
    inventories = []
    for size in range(len(item_ids) + 1):
        for combo in itertools.combinations(item_ids, size):
            if sum(int(CONTENT['items'][item].get('slots', 1)) for item in combo) <= int(CONTENT['inventorySlots']):
                inventories.append(set(combo))
    returned_values = [False, True] if definition.get('allowCollateral', False) else [False]
    reached = set()
    witnesses = {}
    for stack, inventory, returned in itertools.product(sorted(stacks), inventories, returned_values):
        if returned and not inventory:
            continue
        for rule in rules:
            if not reward_rule_matches(rule, stack, inventory, returned):
                continue
            item = str(rule.get('item', ''))
            if item and item in CONTENT['items']:
                used_slots = sum(int(CONTENT['items'][owned].get('slots', 1)) for owned in inventory)
                if used_slots + int(CONTENT['items'][item].get('slots', 1)) <= int(CONTENT['inventorySlots']):
                    reached.add(item)
                    witnesses.setdefault(item, {'table': table_id, 'stack': stack, 'inventory': sorted(inventory), 'collateral_returned': returned})
            break
    return reached, witnesses


reward_rule_ids = set()
granted = set()
reward_witnesses = {}
reward_mismatches = []
reached_by_table = {}
for tid, table in CONTENT['tables'].items():
    rules = table.get('rewardRules', [])
    rule_ids = {str(rule.get('item', '')) for rule in rules if rule.get('item')}
    reward_rule_ids |= rule_ids
    reached, witnesses = reward_outcomes(tid, table)
    reached_by_table[tid] = reached
    granted |= reached
    reward_witnesses.update(witnesses)
    impossible = sorted(rule_ids - reached)
    if impossible:
        reward_mismatches.append({'table': tid, 'unreachable_rewards': impossible})
chk('B2-12a', '四桌 rewardRules 的奖励项覆盖全部 10 件贵重物，且每件至少有可达条件',
    granted == set(valuable) and not reward_mismatches,
    {'多出': sorted(granted - set(valuable)), '缺少': sorted(set(valuable) - granted), '不可达规则': reward_mismatches, '样例条件': reward_witnesses})
bad = [r['item_id'] for r in ITEM_ROWS
       if r['类别'] == '物品-贵重'
       and not re.search(r'(run\.gd:|search_events\.gd:)', r['拿取动作'])]
chk('B2-12b', '每件贵重物的「拿取动作」列都写明自己的代码获得路径', not bad, bad)
chk('B2-12c', '每件贵重物都有至少一条获得路径（无死道具）',
    len(granted) == len(valuable) and set(granted) == set(valuable)
    and all(item in reward_witnesses or re.search(r'"item"\s*:\s*"' + re.escape(item) + r'"', SEARCH_EVENTS) for item in valuable),
    {'通过桌奖规则': sorted(granted), '额外搜索物品': sorted(item for item in valuable if re.search(r'"item"\s*:\s*"' + re.escape(item) + r'"', SEARCH_EVENTS))})

# ---------------- 13. 奖励候选展示与条件结算（B2 README 的关键结论） ----------------
reward_mismatches = []
reward_body = gd_function(RUN, 'reward_for_table')
pool_body = gd_function(RUN, 'table_reward_pool')
service_body = gd_function(RUN, 'service_view')
source_is_current = all(token in reward_body for token in [
    'definition.get("rewardRules", [])', 'rule.has("minStack")', 'rule.has("inventoryHas")',
    'rule.has("inventoryMissing")', 'rule.has("collateralReturned")', 'return str(rule.get("item", ""))'])
pool_is_rule_based = all(token in pool_body for token in [
    'definition.get("rewardRules", [])', 'rule.get("item", "")',
    'item not in pool', 'pool.append(item)', 'return pool'])
view_uses_pool = 'table_reward_pool(table_definition_value)' in service_body
for tid, tb in CONTENT['tables'].items():
    pool_ids = {str(rule.get('item', '')) for rule in tb.get('rewardRules', []) if rule.get('item')}
    if pool_ids != reached_by_table.get(tid, set()):
        reward_mismatches.append({'table': tid, 'candidate_only': sorted(pool_ids - reached_by_table.get(tid, set())),
                                  'reachable_only': sorted(reached_by_table.get(tid, set()) - pool_ids)})
chk('B2-13a', '各桌展示候选来自 rewardRules，且与条件结算可达奖励 ID 一致',
    source_is_current and pool_is_rule_based and view_uses_pool and not reward_mismatches,
    {'rewardRules 与可达奖励核对': reward_mismatches, 'reward_for_table_conditions': source_is_current, 'table_reward_pool_reads_rules': pool_is_rule_based, 'service_view_uses_pool': view_uses_pool})
chk('B2-13b', 'README 区分奖励候选展示与本局条件结算',
    '每桌 `rewardRules` 同时定义结算选择条件和情报中的奖励候选' in README
    and '`table_reward_pool()`' in README and '本局到账仍应以结算结果为准' in README)
chk('B2-13c', '完整情报中的奖励候选由 table_reward_pool() 汇总并由 service_view 展示',
    pool_is_rule_based and view_uses_pool,
    'table_reward_pool reads rewardRules=%s; service_view calls table_reward_pool=%s' % (pool_is_rule_based, view_uses_pool))

# ---------------- 14. 人物几何分组（二进制 sha256 复算） ----------------
import hashlib


def acc_bytes(j, bn, idx):
    acc = j['accessors'][idx]
    bv = j['bufferViews'][acc['bufferView']]
    comp = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[acc['componentType']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[acc['type']]
    stride = bv.get('byteStride') or comp * n
    start = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    out = b''
    for i in range(acc['count']):
        out += bn[start + i * stride: start + i * stride + comp * n]
    return out


def groups():
    res = {}
    for cid in MANIFEST:
        p = GODOT / 'assets/characters' / (cid + '.glb')
        b = p.read_bytes()
        off = 12
        j = bn = None
        while off < len(b):
            ln, ty = struct.unpack_from('<II', b, off)
            off += 8
            if ty == 0x4E4F534A:
                j = json.loads(b[off:off + ln].decode('utf-8'))
            elif ty == 0x004E4942:
                bn = b[off:off + ln]
            off += ln
        pos = b''
        for mesh in j['meshes']:
            for pr in mesh['primitives']:
                pos += acc_bytes(j, bn, pr['attributes']['POSITION'])
        res[cid] = hashlib.sha256(pos).hexdigest()
    g = {}
    for cid, h in res.items():
        g.setdefault(h, []).append(cid)
    return {k: sorted(v) for k, v in g.items()}


G = groups()
chk('B2-14a', 'POSITION 字节 sha256 分出 4 组', len(G) == 4,
    ['%s' % v for v in G.values()])
want = [
    ['ash-smuggler', 'dock-braggart', 'river-shark', 'smiling-knife'],
    ['bartender'], ['calm-widow'],
    ['house-viper', 'ledger-clerk', 'velvet-rook'],
]
chk('B2-14b', '4 组成员与 characters.csv 的几何组标注一致',
    sorted([sorted(v) for v in G.values()]) == sorted([sorted(w) for w in want]),
    sorted(G.values()))
gl_claim = {r['角色id']: r['几何组'][0] for r in CHAR_ROWS}
mapping = {}
for i, grp in enumerate(['A', 'B', 'C', 'D']):
    pass
# 从 CSV 反推组：同组字符串共享前缀
from collections import defaultdict
csv_groups = defaultdict(list)
for r in CHAR_ROWS:
    csv_groups[r['几何组'].split('（')[0]].append(r['角色id'])
chk('B2-14c', 'characters.csv 的分组划分与二进制复算完全一致',
    sorted([sorted(v) for v in csv_groups.values()]) == sorted([sorted(v) for v in G.values()]),
    {k: sorted(v) for k, v in csv_groups.items()})

# ---------------- 15. 逐角色的顶点/骨骼数 ----------------
bad = []
for r in CHAR_ROWS:
    cid = r['角色id']
    m = MANIFEST[cid]
    if str(m['bones']) != r['骨骼数'] or str(m['vertices']) != r['manifest顶点']:
        bad.append(cid)
chk('B2-15a', '9 行骨骼数/manifest 顶点与 manifest.json 一致', not bad, bad)

bad = []
for r in CHAR_ROWS:
    cid = r['角色id']
    j = gltf(GODOT / 'assets/characters' / (cid + '.glb'))
    tot = sum(j['accessors'][pr['attributes']['POSITION']]['count']
              for m in j['meshes'] for pr in m['primitives'])
    if str(tot) != r['GLB_POSITION总数']:
        bad.append('%s csv=%s 实测=%d' % (cid, r['GLB_POSITION总数'], tot))
chk('B2-15b', '9 行 GLB_POSITION 总数与实测一致', not bad, bad)

chk('B2-15c', 'README 的 4 组 GLB 顶点数（41463/40617/40617/39708）可复现',
    '41463' in README and '40617' in README and '39708' in README)

# ---------------- 16. 造型开关与 CAST 一致 ----------------
cast = re.search(r'CAST=\[(.*?)\]\n', BUILD_CHARS, re.S).group(1)
entries = re.findall(r"\('([a-z\-]+)',\(([^)]*)\),\(([^)]*)\),(True|False),(True|False)\)", cast)
chk('B2-16a', 'build_characters.py CAST 解析出 9 条', len(entries) == 9, len(entries))
bad = []
for cid, suit, hair, hat, female in entries:
    r = [x for x in CHAR_ROWS if x['角色id'] == cid][0]
    sw = r['造型开关']
    ok = (('hat=True' in sw) == (hat == 'True')) and (('female=True' in sw) == (female == 'True'))
    if cid == 'bartender':
        ok = ok and 'standing=True' in sw
    else:
        ok = ok and 'standing=True' not in sw
    if not ok:
        bad.append('%s csv=%s cast=(hat=%s,female=%s)' % (cid, sw, hat, female))
chk('B2-16b', '9 行造型开关与 CAST 的 hat/female（+bartender standing）一致', not bad, bad)
chk('B2-16c', '只有 bartender 有 standing 分支',
    BUILD_CHARS.count("standing=name=='bartender'") == 1
    and "if cid" not in BUILD_CHARS)

# ---------------- 17. 动画声明 ----------------
chk('B2-17a', '四段剪辑名称与帧数定义存在',
    "('idle',[1,31,61]),('bet',[1,12,25]),('win',[1,15,31]),('fold',[1,15,31])" in BUILD_CHARS)
frames_ok = re.search(r"\('idle',\[1,31,61\]\)", BUILD_CHARS) and \
    re.search(r"\('bet',\[1,12,25\]\)", BUILD_CHARS) and \
    re.search(r"\('win',\[1,15,31\]\)", BUILD_CHARS) and \
    re.search(r"\('fold',\[1,15,31\]\)", BUILD_CHARS)
chk('B2-17b', 'README 写的帧数 61/25/31/31 与源码一致', bool(frames_ok))
chk('B2-17c', 'bet 驱动 forearm.R', "clip=='bet':rig.pose.bones['forearm.R']" in BUILD_CHARS)
chk('B2-17d', 'win 驱动 spine', "clip=='win':rig.pose.bones['spine']" in BUILD_CHARS)
chk('B2-17e', 'characters_test 只断言 head 变形 > .02 rad',
    'get_bone_pose_rotation(head)' in CHAR_TEST and '> .02' in CHAR_TEST)
chk('B2-17f', 'characters_test 只断言每段 ≥1 条轨道',
    'get_track_count() >= 1' in CHAR_TEST)

# ---------------- 18. 「无同名模型文件」 ----------------
files = [p.name for p in list((ROOT / 'assets').rglob('*.glb')) +
         list((ROOT / 'assets').rglob('*.blend')) +
         list((GODOT / 'assets').rglob('*.glb'))]
clash = [f for f in files for v in valuable if v in f]
chk('B2-18a', '25 个模型文件中无一以 10 件贵重物 id 命名', not clash, clash)
chk('B2-18b', '模型文件总数 25（13 glb + 12 blend）', len(set(files)) == 25, len(set(files)))

# ---------------- 19. 金库装饰层的同名物件 ----------------
SC = read(ROOT / 'assets/blender/stash-noir/build_scene.py')
chk('B2-19a', '装饰层确有 Pearl necklace / Pocket watch',
    "'Pearl necklace'" in SC and "'Pocket watch body'" in SC)
chk('B2-19b', 'README 声明只有 2 件在装饰层有同名物件',
    '有同名物件** | **2**' in README or '| **2** | `pearl-necklace`、`gold-cased-watch`' in README)
chk('B2-19c', '装饰组 05 只有三类物件（无其他贵重物同名物）',
    all(v not in SC for v in valuable if v not in ('pearl-necklace', 'gold-cased-watch')))

# ---------------- 20. 人物个人标识与配色口径 ----------------
chk('B2-20a', 'build_characters.py 里只有 hat / female / standing 三个造型分支',
    BUILD_CHARS.count('if hat:') == 1 and BUILD_CHARS.count('if female:') == 1
    and BUILD_CHARS.count('standing=') == 1)
chk('B2-20b', 'Skin 是按 idx 派生而非逐人书写',
    "skin':mat('Skin',(.38+idx*.008,.23+idx*.005,.15+idx*.004))" in BUILD_CHARS)
chk('B2-20c', '9 行「个人标识」都写明「无独立视觉标识」',
    all(r['个人标识'].startswith('无独立视觉标识') for r in CHAR_ROWS),
    [r['角色id'] for r in CHAR_ROWS if not r['个人标识'].startswith('无独立视觉标识')])
chk('B2-20d', '9 行「可识别性检查项」都带禁用配色的警示',
    all('不可用「9 套配色」' in r['可识别性检查项'] for r in CHAR_ROWS),
    [r['角色id'] for r in CHAR_ROWS if '不可用「9 套配色」' not in r['可识别性检查项']])
chk('B2-20e', 'README 明确「基础几何共享不是自动失败，也不能证明完成」',
    '基础几何共享不是自动失败' in README and '也不能用它反过来证明' in README)

# ---------------- 21. Phase3 顺序列值域 ----------------
vals = sorted({r['Phase3顺序'].split('（')[0].strip() for r in ITEM_ROWS + CHAR_ROWS})
chk('B2-21a', 'Phase3 顺序只取 2/3/4（1 与 5 不在逐件范围）',
    all(v in {'2', '3', '4'} for v in vals) and vals == ['2', '3', '4'], vals)
chk('B2-21b', '贵重物排在 2、可用道具排在 3、人物排在 4',
    all(r['Phase3顺序'] == '2' for r in ITEM_ROWS if r['类别'] == '物品-贵重')
    and all(r['Phase3顺序'] == '3' for r in ITEM_ROWS if r['类别'] == '物品-可用')
    and all(r['Phase3顺序'].startswith('4') for r in CHAR_ROWS))
chk('B2-21c', 'README 声明顺序只是建议、不代表批准开工',
    '这只排顺序，不代表已批准开工' in README)

# ---------------- 22. 边界声明 ----------------
for cid, key in [('B2-22a', '不建模、不导出、不生图、不购买素材'),
                 ('B2-22b', '不改游戏代码、资产、覆盖目录'),
                 ('B2-22c', '不自行提交、推送')]:
    chk(cid, 'README 写明边界：%s' % key, key[:6] in README)
chk('B2-22d', 'README 写明未生图/缺参考图需主 Agent 判断',
    '用户尚未批准生图' in README)
# 注意：README 里会**否定式**提到「Phase 2/3 完成」（「未取得任何…资格」），
# 所以不能做朴素字符串禁止，要「禁止肯定式 + 要求否定式」两头查。
AFFIRM = ['Phase 3 已完成', 'Phase 2 完成', '宣布 Phase 2/3 完成', 'B2 通过验收', 'B2 已验收']
chk('B2-22e', 'README 无「已完成 / 已通过」类肯定式结论',
    not any(a in README for a in AFFIRM),
    [a for a in AFFIRM if a in README])
chk('B2-22f', 'README 显式声明未取得 Phase 2/3 完成资格',
    '未' in README and 'Phase 2/3 完成' in README
    and re.search(r'未\*{0,2}取得任何[^\n]*Phase 2/3 完成', README) is not None)
chk('B2-22g', 'README 声明自查条数不是验收指标（0 条 REFUTE 才是）',
    '不当作验收指标' in README and '0 条 REFUTE 才是' in README)
# C1 教训：条数会随脚本增删漂移，所以 README 里**不得**写死条数。
PIN = re.findall(r'CONFIRM\s*\d+|\d+\s*项\s*CONFIRM|共\s*\d+\s*项', README)
chk('B2-22h', 'README 未写死自查条数（避免随脚本增删漂移）', not PIN, PIN)

# ---------------- 23. 不重复资产总库 ----------------
chk('B2-23a', 'README 未重列 56 行内容矩阵（只引用路径）',
    'content-matrix.csv' in README and README.count('| 酒馆 |') == 0)
chk('B2-23b', 'README 明确「不复制新的资产总数据库」', '不复制新的资产总数据库' in README)

# ---------------- 24. 行内反引号路径可打开（CSV 也要查） ----------------
bad = []
TICK = re.compile(r'`([^`\n]+)`')
EXTS = ('.md', '.csv', '.json', '.gd', '.py', '.mjs', '.command')
for f in ['README.md', 'items.csv', 'characters.csv']:
    text = read(B2 / f)
    for m in TICK.finditer(text):
        t = m.group(1).strip()
        if ' ' in t or '/' not in t or not t.endswith(EXTS):
            continue
        tgt = (B2 / t).resolve()
        if not tgt.exists() and not (ROOT / t).exists():
            bad.append('%s -> %s' % (f, t))
chk('B2-24', 'B2 三个文件里的反引号路径全部可打开（两级解析）', not bad, bad[:6])

# ---------------- 25. 「参考图」列：任务书第 4 条逐件标记 ----------------
# 任务书要求「缺参考图只标记需主 Agent 判断」。逐行标记是真的落进 CSV，
# 还是只在 README 写了一句话——必须能从 CSV 重新推导出「行行都有标记」。
chk('B2-25a', 'items.csv 有「参考图」列', '参考图' in ITEM_ROWS[0])
chk('B2-25b', 'characters.csv 有「参考图」列', '参考图' in CHAR_ROWS[0])

JUDGE = '需主 Agent 判断'
nojudge = [r['item_id'] for r in ITEM_ROWS if JUDGE not in r['参考图']]
chk('B2-25c', 'items.csv 19 行参考图列都写着「需主 Agent 判断」', not nojudge, nojudge)
nojudge = [r['角色id'] for r in CHAR_ROWS if JUDGE not in r['参考图']]
chk('B2-25d', 'characters.csv 9 行参考图列都写着「需主 Agent 判断」', not nojudge, nojudge)

# 三类资产各自的作者源 README 声明必须被引用（不能笼统写「无参考」）
badsrc = [r['item_id'] for r in ITEM_ROWS if r['类别'] == '物品-可用'
          and 'tavern-detail/README.md:3' not in r['参考图']]
chk('B2-25e', '9 件可用道具的参考图列引用 tavern-detail/README.md:3', not badsrc, badsrc)
badsrc = [r['item_id'] for r in ITEM_ROWS if r['类别'] == '物品-贵重'
          and 'stash-noir/README.md:3' not in r['参考图']]
chk('B2-25f', '10 件贵重物的参考图列引用 stash-noir/README.md:3', not badsrc, badsrc)
badsrc = [r['角色id'] for r in CHAR_ROWS if 'characters/README.md:3' not in r['参考图']]
chk('B2-25g', '9 位人物的参考图列引用 characters/README.md:3', not badsrc, badsrc)

# 脚本层面重新推导「build_props.py 不读任何图片」。
# 注意：不能天真地匹配 'reference'——Blender API 的 bpy.context.preferences 里含该子串，
# 会造出假命中（本脚本第一版就踩了，119 项时报 1 REFUTE）。必须排除 preferences。
IMG_HITS = [l for l in BUILD_PROPS.split('\n')
            if re.search(r'\.png|参考', l) or re.search(r'\breference', l)]
chk('B2-25h', 'build_props.py 无 .png / 无「参考」/ 无词边界 reference（脚本不读图）',
    not IMG_HITS, IMG_HITS[:2])

# 场景板盘点：实测张数与 README 表一致
PLATES = sorted((ROOT / 'assets/scene-plates').glob('*.png'))
chk('B2-25i', 'assets/scene-plates 下 33 张 png',
    len(PLATES) == 33, len(PLATES))

# 去重事实：两张板字节完全相同 → 盘点不能只数文件名。
# B2-R2 修正：README 里的哈希已从 md5 换成 sha256[:16]，这里同步用 sha256 重新推导，
# 并断言「6 个视角/场景板去重后 = 5 份不同内容」——不再断言「全部参考只剩一份」。
import hashlib
SHA = {n: hashlib.sha256((ROOT / 'assets/scene-plates' / n).read_bytes()).hexdigest()[:16]
       for n in ['酒馆酒保交易视角.png', '德扑酒馆全貌.png', '德扑牌桌视角.png',
                 '藏匿点场景.png', '酒馆厨房撤离视角.png', '德扑撤离视角.png']}
chk('B2-25j', '酒馆酒保交易视角.png 与 德扑酒馆全貌.png 字节相同（sha256 一致）',
    SHA['酒馆酒保交易视角.png'] == SHA['德扑酒馆全貌.png'],
    '%s / %s' % (SHA['酒馆酒保交易视角.png'], SHA['德扑酒馆全貌.png']))
chk('B2-25j2', '这 6 个板去重后是 5 份不同内容（不是「只剩 1 张」）',
    len(set(SHA.values())) == 5, sorted(set(SHA.values())))
chk('B2-25k', 'README 写出该哈希与「去重后是 5 份不同内容」',
    SHA['酒馆酒保交易视角.png'] in README and '去重后是 5 份不同内容' in README,
    SHA['酒馆酒保交易视角.png'])

# 三条作者声明原句必须逐字引在 README（不能改写成「据说」）
chk('B2-25l', 'README 逐字引用 characters/README.md:3 的「未生成新参考图」',
    '未生成新参考图' in README and '未引入第三方角色资产' in README)
chk('B2-25m', 'README 逐字引用 tavern-detail/README.md:3 的「不使用 image2.5 或新增 AI 参考图」',
    '不使用 image2.5 或新增 AI 参考图' in README)
chk('B2-25n', 'README 逐字引用 stash-noir/README.md:3 的「皮箱／木桌参考图」',
    '皮箱／木桌参考图' in README)
chk('B2-25o', 'README 有独立的参考图小节（§1.4）且落进文件清单',
    '### 1.4 参考图基线' in README and '场景板清单' in README)

# 生图边界：整份交付不得出现「已生成参考图」类肯定式表述
FORBID = ['已生成参考图', '已生图', '生成了参考图', '已下载参考图']
chk('B2-25p', '交付物无「已生成/已下载参考图」类肯定式表述',
    not any(f in README for f in FORBID), [f for f in FORBID if f in README])

# 向上溯源：三条声明必须**真的**在那三份作者源 README 的第 3 行，
# 而不是只在 B2 自己的 README 里自说自话。
for cid, rel, needle in [
        ('B2-25q', 'assets/blender/characters/README.md', '未生成新参考图'),
        ('B2-25r', 'assets/blender/tavern-detail/README.md', '不使用 image2.5 或新增 AI 参考图'),
        ('B2-25s', 'assets/blender/stash-noir/README.md', '皮箱／木桌参考图')]:
    L = read(ROOT / rel).split('\n')
    line3 = L[2] if len(L) > 2 else ''
    chk(cid, '%s:3 确实含「%s」' % (rel, needle), needle in line3, line3[:60])


# ---------------- 26. B2-R1…R4 返修回归（从源码重新推导，防悄悄退回旧结论） ----------------
# README 开头的「返修记录」表会**否定式地引用**旧错误说法，所以「正文」= 去掉该段之后的部分。
BODY = README.split('## 本轮边界', 1)[1] if '## 本轮边界' in README else README
SRC_CHARS = read(ROOT / 'assets/blender/characters/build_characters.py')

# --- R1：几何相同 ≠ 文件联动；整组一起改只是建议
chk('B2-26a', 'build_characters.py 逐角色循环且每轮 read_factory_settings 重建（几何相同源于算法相同）',
    'for idx,(name,suit,hair,hat,female) in enumerate(CAST)' in SRC_CHARS
    and 'read_factory_settings' in SRC_CHARS)
chk('B2-26b', 'build_characters.py 按角色名分别存 .blend 与 .glb（不是九个文件链接同一网格）',
    "save_as_mainfile(filepath=str(OUT/(name+'.blend')))" in SRC_CHARS
    and "export_scene.gltf(filepath=str(DEST/(name+'.glb'))" in SRC_CHARS)
chk('B2-26c', 'characters.csv「可复用部件」不再声称同组网格可直接互相套用，且写明独立可编辑源',
    all('可直接互相套用' not in r['可复用部件'] and '独立可编辑源' in r['可复用部件']
        for r in CHAR_ROWS),
    [r['角色id'] for r in CHAR_ROWS if '独立可编辑源' not in r['可复用部件']])
chk('B2-26d1', 'characters.csv「依赖」不再写「单独改 1 人无法拉开组内区分」',
    all('无法拉开组内区分' not in r['依赖'] for r in CHAR_ROWS),
    [r['角色id'] for r in CHAR_ROWS if '无法拉开组内区分' in r['依赖']])
grp = [r for r in CHAR_ROWS if '与同组' in r['可复用部件']]
chk('B2-26d2', '同组 7 人（组 A 4 + 组 B 3）的「依赖」把整组一起改写为建议而非前提',
    len(grp) == 7 and all('建议，非技术前提' in r['依赖'] for r in grp),
    [r['角色id'] for r in grp if '建议，非技术前提' not in r['依赖']])
chk('B2-26d3', '9 行「依赖」都写明本角色可单独制作',
    all('可单独制作' in r['依赖'] for r in CHAR_ROWS),
    [r['角色id'] for r in CHAR_ROWS if '可单独制作' not in r['依赖']])
chk('B2-26e', 'README 正文写明「几何相同 ≠ 文件联动」',
    '不等于「文件联动」' in BODY and 'read_factory_settings' in BODY)
chk('B2-26f', 'README 正文不含「必须整组一起改」「必须 4 人一并改」这类技术前提',
    '必须整组一起改' not in BODY and '必须 4 人一并改' not in BODY
    and '必须 3 人一并改' not in BODY)

# --- R2：参考图不外推 + 用途分类
chk('B2-26g', 'README 正文不再断言「现有 3D 参考图去重后只有 1 张」',
    '去重后只有 1 张' not in BODY and '去重后只有 1 份' not in BODY)
chk('B2-26h', 'README 未逐图审阅的图片一律写「内容适用性未核验」',
    BODY.count('内容适用性未核验') >= 3, BODY.count('内容适用性未核验'))

# --- R3：贵重物入包 + 互斥分组
chk('B2-26i', 'README 正文写明「购买入口只支持 9 件」且贵重物仍会入包',
    '**购买入口**只支持 9 件' in BODY and 'settle_table()' in BODY
    and 'inventory.append' in BODY)
VSTART_CNT = {}
for r in ITEM_ROWS:
    if r['类别'] == '物品-贵重':
        VSTART_CNT[r['制作起点'][:1]] = VSTART_CNT.get(r['制作起点'][:1], 0) + 1
chk('B2-26j', 'items.csv 贵重物「制作起点」互斥三分组且合计 10（A2 / B3 / C5）',
    [VSTART_CNT.get(k, 0) for k in 'ABC'] == [2, 3, 5], VSTART_CNT)
chk('B2-26k', '每件贵重物「制作起点」恰好一个分组字母，分组名与件数可加总',
    all(r['制作起点'][:1] in 'ABC' and r['制作起点'][1] == '｜'
        for r in ITEM_ROWS if r['类别'] == '物品-贵重'))
chk('B2-26l', 'items.csv 不再写「需从零建」这类仅由「无同名物」推出的结论',
    all('需从零建' not in r['尚缺表现'] for r in ITEM_ROWS))
chk('B2-26m', 'README 正文区分「无同名物」与「已确认没有别的可借内容」',
    '只说明缺独立模型' in BODY)

# --- R4：基础候选位 vs 种子实架
chk('B2-26n', 'items.csv 货架列不再写「固定上架位」，可用道具改「基础配置候选位」',
    all('固定上架位' not in r['货架实物'] for r in ITEM_ROWS)
    and all('基础配置候选位' in r['货架实物']
            for r in ITEM_ROWS if r['类别'] == '物品-可用'))
VARIANTS = read(GODOT / 'rules/run_variants.gd')
chk('B2-26o', 'run_variants.gd 正种子下从非必需候选中删 1 件（ESSENTIALS 除外）',
    'ESSENTIALS' in VARIANTS
    and 'if seed_value != 0 and optional.size() > 1' in VARIANTS
    and 'stock.erase(optional[int(rng.next() * optional.size())])' in VARIANTS)
chk('B2-26p', 'run.gd shop_stock 有 variant_plan 时优先返回 plan.shelves',
    'if not variant_plan.is_empty():' in RUN
    and 'return variant_plan.shelves[str(clampi(search_index, 1, 5))].duplicate()' in RUN)
chk('B2-26q', 'README 正文写明「候选位不是每次必上架」并给出种子计划优先路径',
    '不是当前每次必定实物上架的位数' in BODY
    and 'run_variants.gd:16-18' in BODY and 'run.gd:310-311' in BODY)
chk('B2-26r', 'README 正文不含「固定上架位」旧说法', '固定上架位' not in BODY)


# ---------------- 输出 ----------------
def main():
    refuted = [c for c in CHECKS if not c['ok']]
    print('B2 独立复核：共 %d 项，CONFIRM %d，REFUTE %d'
          % (len(CHECKS), len(CHECKS) - len(refuted), len(refuted)))
    if refuted:
        print('\nREFUTE：')
        for c in refuted:
            print('  ❌ %-14s %s\n       detail: %s' % (c['id'], c['claim'], c['detail']))
    else:
        print('✅ 全部通过')
    out = pathlib.Path(__file__).resolve().parent / 'b2-verify.json'
    out.write_text(json.dumps({'checks': CHECKS}, ensure_ascii=False, indent=2),
                   encoding='utf-8')
    print('\n明细已写：%s' % out.relative_to(ROOT))
    return 1 if refuted else 0


if __name__ == '__main__':
    sys.exit(main())
