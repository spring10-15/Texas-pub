#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""B2 交付物生成器（只写 CSV，不碰游戏代码/资产/覆盖目录）。

输入（全部只读）：
  Godot/three_d/rules/content.json            物品/牌桌/对手/酒馆定义
  Godot/three_d/assets/props-export.json      12 个道具部件的三角面数
  Godot/three_d/assets/characters/manifest.json  9 人物骨骼/顶点/片段
  Godot/three_d/assets/characters/*.glb       实测 POSITION 总数与材质名
  assets/blender/tavern-detail/build_props.py 9 件可用道具的构件作者源
  assets/blender/characters/build_characters.py  9 人物的 CAST 与造型开关

输出：
  docs/3d-production/external-handoff/B2-production-breakdown/items.csv      19 行
  docs/3d-production/external-handoff/B2-production-breakdown/characters.csv  9 行

用法：python3 output/external-handoff/B2/build_breakdown.py
"""
import csv
import json
import struct
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[3]
DEST = OUT / 'docs/3d-production/external-handoff/B2-production-breakdown'
GODOT = OUT / 'Godot/three_d'

# ---- 只读：content.json -----------------------------------------------------
CONTENT = json.loads((GODOT / 'rules/content.json').read_text(encoding='utf-8'))
ITEMS = CONTENT['items']
SHOPS = CONTENT['shops']
PROPS_TRI = json.loads((GODOT / 'assets/props-export.json').read_text(encoding='utf-8'))
MANIFEST = json.loads((GODOT / 'assets/characters/manifest.json').read_text(encoding='utf-8'))


def gltf_json(path):
    b = pathlib.Path(path).read_bytes()
    off = 12
    while off < len(b):
        ln, ty = struct.unpack_from('<II', b, off)
        off += 8
        if ty == 0x4E4F534A:
            return json.loads(b[off:off + ln].decode('utf-8'))
        off += ln
    raise ValueError('no JSON chunk in %s' % path)


def glb_position_total(path):
    j = gltf_json(path)
    return sum(j['accessors'][pr['attributes']['POSITION']]['count']
               for m in j['meshes'] for pr in m['primitives'])


def shelf_slots(item_id):
    """该道具在 4 家酒馆 × 搜索档 里被 content.shops 列为候选的上架位（**基础配置候选位**）。"""
    hits = []
    for scene, slots in SHOPS.items():
        for idx, stock in slots.items():
            if item_id in stock:
                hits.append('%s#%s' % (scene, idx))
    return hits


# ---- items.csv --------------------------------------------------------------
ITEM_HEADER = [
    '序号', '类别', 'item_id', '中文名', '现有源文件', '可复用部件', '制作起点', '运行加载点',
    '货架实物', '拿取动作', '背包展示', '消耗_失去_抵押', '参考图', '尚缺表现',
    'Phase3顺序', '依赖', '证据(文件:行)',
]
# 已有完整模型的 9 件可用道具的「制作起点」
START_USABLE = '已有完整模型｜interactive-props.glb 内的独立命名节点，可直接改材质/比例/贴图'

# 10 件贵重物的「制作起点」= 互斥三分组（B2-R3：旧稿 2+2+8 数字不自洽，已改为互斥且合计为 10）
#   A 装饰层有同名物件 2 件 ／ B 无同名但有同族基底 3 件 ／ C 无同名也无同族基底 5 件
VSTART = {
    'pearl-necklace': 'A｜装饰层有同名物件',
    'gold-cased-watch': 'A｜装饰层有同名物件',
    'old-silver-lighter': 'B｜无同名，有同族基底：可用道具 signal-lighter（打火机）',
    'ivory-chip': 'B｜无同名，有同族基底：场景件 loose-chip（筹码）',
    'antique-coin': 'B｜无同名，有同族基底：场景件 loose-chip 的圆盘+边齿（**仅部分可借**）',
    'ruby-cufflink': 'C｜无同名，也无同族基底',
    'sealed-bond': 'C｜无同名，也无同族基底',
    'emerald-brooch': 'C｜无同名，也无同族基底',
    'obsidian-idol': 'C｜无同名，也无同族基底',
    'vault-promissory': 'C｜无同名，也无同族基底',
}
# 「尚缺表现」里关于「离成品还差什么」——按分组给，不写「必须从零建」这种由「无同名物」直接推出的结论
VSTART_GAP = {
    'A': '；装饰层同名物件是合并进 stash.glb 的装饰几何，不能直接当可拾取模型；'
         '可拾取模型的形制与体积需要另定，**未核实**',
    'B': '；同族道具只提供形制与比例参照（材质/面值/内嵌色），可拾取模型仍需重建，细节与体积**未核实**',
    'C': '；装饰层与可用道具里都没有可直接借用的形制，具体几何与体积**未核实**',
}

# 9 件可用道具：build_props.py 里各自的 group() 构件块行号 + 构件清单
USABLE_SRC = {
    'marked-lens': ('36-37', 'Lens rim、Smoked lens(enamel)、Folded handle(dark)、Handle hinge（共 4 件构件）'),
    'signal-lighter': ('38-39', 'Lighter case、Hinged lid、Lid seam(dark)、Flint wheel(dark)、铭文 N（共 5 件构件）'),
    'sleeve-clip': ('40-42', 'Clip side×2、Clip bridge、Inner tongue、Spring（共 5 件构件）'),
    'disposable-phone': ('43-47', 'Phone shell(dark)、Display(enamel)、屏幕文本 01:49、Key×12、Antenna(dark)（共 16 件构件）'),
    'player-notes': ('48-52', 'Paper block、Leather cover×2、Book spine、铭文 NOTES/NOIR、Foil rule×2（共 7 件构件）'),
    'kitchen-pass': ('53-54', 'Pass card、Printed band(enamel)、文本 KITCHEN、文本 ADMIT ONE、Eyelet（共 5 件构件）'),
    'dock-passkey': ('53-54', '与 kitchen-pass 同构五件构件，铭文换为 DOCK'),
    'false-bottom-wallet': ('55-60', 'Leather fold×2、Fold seam、Saddle stitch×18、铭文 N（共 22 件构件，构件数最多）'),
    'steadying-drink': ('61-62', 'Bottle body、Bottle neck、Cork(walnut)、Bottle shoulder、Paper label、铭文 TONIC（共 6 件构件）'),
}

# 9 件可用道具。每行的证据都可按「证据」列逐个打开复核。
USABLE = {
    'marked-lens': dict(
        shelf='有｜run.gd:309-317 shop_stock() 驱动；bar_display.gd:24-37 逐件生成实物 + Label3D 名称/价格',
        take='有｜world.gd:873-880 购买后 bar_display.deliver(id) + characters.deliver() 递物动画',
        consume='消耗｜run.gd:360-362 inventory.erase + used_tools.append；run.gd:363 heat+1；run.gd:274-275 每桌一次',
        gap='无背包图标；使用时无 3D 反馈（牌面变化发生在牌桌 UI）；无「已使用」视觉状态',
        order='3',
        deps='背包展示形式（图标 or 3D）需先定',
        ev='assets/blender/tavern-detail/build_props.py:36-37｜Godot/three_d/scripts/world.gd:978-983｜'
           'Godot/three_d/scripts/bar_display.gd:24-37,52-56｜Godot/three_d/tests/art_integration_test.gd:24-28｜'
           'Godot/three_d/tests/tool_coverage_test.gd:12-21',
    ),
    'signal-lighter': dict(
        shelf='有｜9 个基础配置候选位（4 店 × 搜索档 #2/#3/#5）',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜advanced_services.gd:75-79 inventory.erase + used_tools；heat 字段为 0（run.gd:9 表内 heat=0）',
        gap='无背包图标；读牌力结果只有文字（advanced_services.gd:74「强/中/弱」），打火机本身无表现',
        order='3',
        deps='同 marked-lens；牌力读数视觉化若要加需主 Agent 判断',
        ev='assets/blender/tavern-detail/build_props.py:38-39｜Godot/three_d/rules/advanced_services.gd:10-20,67-79｜'
           'Godot/three_d/tests/signal_coverage_test.gd:20-47｜Godot/three_d/tests/routes_items_test.gd:77',
    ),
    'player-notes': dict(
        shelf='有｜20 个基础配置候选位（4 店 × 全部 5 个搜索档，唯一全档入选候选道具）',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜advanced_services.gd:75-79 使用后 inventory.erase + used_tools；同一对手重复记录被拒（:18-19）',
        gap='无背包图标；对手风格只有文字（advanced_services.gd:66），笔记没有写在书页上的表现',
        order='3',
        deps='同 marked-lens；对手风格视觉化的承载方式未定',
        ev='assets/blender/tavern-detail/build_props.py:48-52｜Godot/three_d/rules/advanced_services.gd:18-19,64-66｜'
           'Godot/three_d/tests/redundant_intel_test.gd:26-33｜Godot/three_d/tests/routes_items_test.gd:74-75',
    ),
    'steadying-drink': dict(
        shelf='有｜9 个基础配置候选位（smoky-den/high-rise-suite/rooftop-club 的 #1/#2/#4，neon #1）',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜run.gd:340 drink 时 inventory.erase("steadying-drink")；run.gd:298-299 背包内必须有',
        gap='无背包图标；「喝掉」只有 HUD 文本（run.gd:345），瓶子不会从货架减少到手上的可见过程',
        order='3',
        deps='同 marked-lens；酒保递物动画已复用（characters.gd:57-59）',
        ev='assets/blender/tavern-detail/build_props.py:61-62｜Godot/three_d/rules/run.gd:295-301,338-345｜'
           'Godot/three_d/tests/service_coverage_test.gd:10-38',
    ),
    'disposable-phone': dict(
        shelf='有｜9 个基础配置候选位（4 店 × #3/#5）+ run.gd:314-316 在 search_index==2 强制补货',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜advanced_services.gd:75-76 每次使用 inventory.erase（无 used_tools，故可多买多用）',
        gap='无背包图标；手机屏幕为静态贴图文本（build_props.py:44），不随接应路线刷新而变化',
        order='3',
        deps='同 marked-lens；若要屏幕动态化需重导 GLB（本轮不做）',
        ev='assets/blender/tavern-detail/build_props.py:43-47｜Godot/three_d/rules/run.gd:314-316｜'
           'Godot/three_d/rules/advanced_services.gd:55-63,75-76｜Godot/three_d/tests/routes_items_test.gd:65-68,87',
    ),
    'kitchen-pass': dict(
        shelf='有｜6 个基础配置候选位（smoky-den #1/#3、high-rise-suite #3、rooftop-club #1/#3、neon #3）',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜advanced_services.gd:52-54,76 揭示 unlockRoute 后 inventory.erase（一次性）',
        gap='无背包图标；通行证与 dock-passkey 除铭文外完全同构，卡面差异只有一行字（build_props.py:53-54）',
        order='3',
        deps='同 marked-lens；两张证件是否需要更强区分度属主 Agent 判断',
        ev='assets/blender/tavern-detail/build_props.py:53-54｜Godot/three_d/rules/advanced_services.gd:38-43,52-54｜'
           'Godot/three_d/tests/routes_items_test.gd:37,114-116｜Godot/three_d/tests/scene_rules_test.gd:48',
    ),
    'dock-passkey': dict(
        shelf='有｜6 个基础配置候选位（smoky-den #2/#4、high-rise-suite #2、rooftop-club #2、neon #2/#4）',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜advanced_services.gd:52-54,76 揭示 river-launch 后 inventory.erase（一次性）',
        gap='同 kitchen-pass：与后厨通行证同构，仅铭文不同；无背包图标',
        order='3',
        deps='同 kitchen-pass',
        ev='assets/blender/tavern-detail/build_props.py:53-54｜Godot/three_d/rules/advanced_services.gd:38-43,52-54｜'
           'Godot/three_d/tests/advanced_coverage_test.gd:16-17｜Godot/three_d/tests/scene_rules_test.gd:48',
    ),
    'false-bottom-wallet': dict(
        shelf='有｜仅 4 个基础配置候选位（smoky-den #2、high-rise-suite #1/#4、neon #2），覆盖率最低',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='不消耗｜被动效果，全程留在背包；仅 run.gd:461 abandon 时结算 mini(80, cash)，随后随 run.gd:466 inventory.clear() 一并消失',
        gap='无背包图标；被动效果没有任何提示（背包文案不标注「宽松失败保留 80」）',
        order='3',
        deps='同 marked-lens；被动效果说明是否写进背包文案属主 Agent 判断',
        ev='assets/blender/tavern-detail/build_props.py:55-60｜Godot/three_d/rules/run.gd:458-469｜'
           'Godot/three_d/tests/routes_items_test.gd:82,101｜Godot/three_d/tests/lifecycle_coverage_test.gd:66',
    ),
    'sleeve-clip': dict(
        shelf='有｜16 个基础配置候选位（4 店 × 搜索档 #2/#3/#4/#5，覆盖最广）',
        take='有｜同 marked-lens（world.gd:873-880）',
        consume='消耗｜run.gd:360-362 inventory.erase + used_tools；run.gd:363 heat+2（heat 字段同为 2）；run.gd:278-279 仅翻牌前首次行动前可用',
        gap='无背包图标；换牌结果只在牌桌手牌区体现，袖夹本身无表现',
        order='3',
        deps='同 marked-lens',
        ev='assets/blender/tavern-detail/build_props.py:40-42｜Godot/three_d/rules/run.gd:276-280,353-363｜'
           'Godot/three_d/tests/services_save_test.gd:66｜Godot/three_d/tests/tool_coverage_test.gd:12-21',
    ),
}

VALUABLE_GAP = '无独立可拾取模型、无背包图标'
VALUABLE_EV_TAIL = ('Godot/three_d/tests/payout_coverage_test.gd｜Godot/three_d/tests/extraction_conservation_test.gd｜'
                    'Godot/three_d/tests/entry_coverage_test.gd:25')

# 金库装饰组 assets/blender/stash-noir/build_scene.py:145-163 的 "05 • Personal valuables"
# 只含三类物件：Silver cigarette case / Pearl necklace / Pocket watch。
# 十件贵重物里只有 2 件在装饰层有同名物件，其余 8 件连装饰同名物都没有——这两种情况必须分开写。
DECOR_NONE = ('无（金库装饰组 05 只有 Silver cigarette case / Pearl necklace / Pocket watch 三类，'
              '本件在装饰层也没有同名物件）')
DECOR = {
    'pearl-necklace': '有同名装饰物件｜build_scene.py:149-154 Pearl necklace×49 + Necklace inner loop×19 + '
                      'Necklace clasp（Warm pearl / Tarnished silver 材质）',
    'gold-cased-watch': '有同名装饰物件｜build_scene.py:155-163 Pocket watch body + Ivory enamel watch dial + '
                        'Watch bezel + 12 个 Watch hour 文字 + 分/时针 + Watch bow',
    'ivory-chip': '无同名物件｜仅材质库里有 "Ivory chip inlay"（build_scene.py:38）与 04 组 Clay poker chip 可作材质/形制参考',
}
DECOR_REUSE = {
    'pearl-necklace': 'Warm pearl / Tarnished silver 材质可直接复用；装饰件已含完整项链几何',
    'gold-cased-watch': 'Aged brass / Polished gold edges / Ivory chip inlay 材质可直接复用；装饰件已含表壳、表盘、指针、表冠全套构件',
    'ivory-chip': 'Ivory chip inlay 材质可复用作筹码内嵌',
}
# 已存在的同族道具/场景件（不是同名，但形制接近，可省一次从零建模）
PROP_ANALOGUE = {
    'old-silver-lighter': '同族参考：可用道具 signal-lighter（build_props.py:38-39，548 tri）已是打火机形制，换材质即可近似',
    'ivory-chip': '同族参考：场景件 loose-chip（build_props.py:70-74，3052 tri）已是筹码，含边齿与面值文字，改面值/内嵌色即可',
    'antique-coin': '同族参考：场景件 loose-chip 的圆盘+边齿结构可作纪念币基底',
}


def valuable_rows():
    """10 件贵重物：无独立模型，交互只有「获得 / 抵押 / 出售 / 失去」。"""
    granted = {
        'old-silver-lighter': ('货运桌奖励（非首选档）｜run.gd:199 stack<90 且背包已有 ivory-chip 时发放；'
                              '另可由货运桌搜索事件直接取得 search_events.gd:4'),
        'ivory-chip': '货运桌奖励（首选档）｜run.gd:199 背包无 ivory-chip 时必定发放；content.json signatureReward',
        'ruby-cufflink': '货运桌奖励（高档）｜run.gd:199 stack>=90 且背包已有 ivory-chip',
        'gold-cased-watch': '镜厅奖励（常规档）｜run.gd:201 未归还抵押且 stack<170',
        'antique-coin': '镜厅奖励（抵押线）｜run.gd:201 抵押物归还时发放；content.json signatureReward',
        'sealed-bond': '镜厅奖励（高档）｜run.gd:201 未归还抵押且 stack>=170',
        'pearl-necklace': '账房地窖奖励（高档）｜run.gd:200 stack>=130；content.json signatureReward',
        'emerald-brooch': ('账房地窖奖励（常规档）run.gd:200 stack<130；'
                           '另可由镜厅搜索事件直接取得 search_events.gd:6'),
        'obsidian-idol': '余烬桌奖励（常规档）｜run.gd:202 stack<220',
        'vault-promissory': '余烬桌奖励（高档）｜run.gd:202 stack>=220；content.json signatureReward',
    }
    order = [k for k, v in ITEMS.items() if v['kind'] == 'valuable']
    rows = []
    for i, item_id in enumerate(order, start=1):
        it = ITEMS[item_id]
        slots2 = '（占 2 格，run.gd:254-258 计入 slots_used）' if int(it['slots']) == 2 else ''
        rows.append([
            str(9 + i), '物品-贵重', item_id, it['name'],
            '无 %s.glb / 无 %s.blend（全项目 25 个模型文件无一以本 id 命名，清单见 README 表 1-3）｜'
            '可打开核对的对应物：assets/blender/stash-noir/build_scene.py:145-163（装饰层）、'
            'Godot/three_d/assets/props-export.json（12 键，不含贵重物）｜%s'
            % (item_id, item_id, DECOR.get(item_id, DECOR_NONE)),
            DECOR_REUSE.get(item_id, '仅材质库复用（Aged brass / Polished gold edges / Tarnished silver / Charcoal，'
                                     'build_scene.py:35-43）；无独立构件')
            + ('｜' + PROP_ANALOGUE[item_id] if item_id in PROP_ANALOGUE else ''),
            VSTART[item_id],
            '不适用（无实例化路径：Godot/three_d/scripts/world.gd:978-983 make_detailed_prop() 只按 '
            'interactive-props.glb 的 12 个命名节点取件，10 件贵重物均不在其中）',
            '不上架｜**购买入口**（run.gd:286 buy 分支）要求 item_id in SUPPORTED_ITEMS（仅 9 件）；'
            '注意这不等于贵重物进不了背包——run.gd:203-204 settle_table() 会把桌奖贵重物 inventory.append',
            '不适用（无实物拿取动作）｜' + granted[item_id],
            '仅文字｜services_hud.gd:45 与 run.gd:440-442 bag 串（item_name）；无图标、无模型；'
            '抵押选择只在牌桌 HUD 下拉里出现（table_hud.gd:140-149）',
            '抵押｜run.gd:165-173 仅 allowCollateral 桌（mirror-hall/embers-table）可抵押 1 件，进入时移出背包；'
            'run.gd:191-194 末手获胜才归还，否则 run.gd:212 判定失去。出售｜run.gd:334-337 + run.gd:447-449 sale_value() '
            '按 value 计价。失去｜run.gd:241 extract / run.gd:466 abandon 时 inventory.clear() 全清' + slots2,
            REF_VALUABLE,
            VALUABLE_GAP + VSTART_GAP[VSTART[item_id][0]],
            '2',
            '需先定「贵重物是否做独立模型」与「体积差异是否只做占 2 格的 3 件」；两项均为产品判断，需主 Agent 定',
            'Godot/three_d/assets/props-export.json（12 键，无贵重物）｜assets/blender/stash-noir/build_scene.py:145-163｜'
            'Godot/three_d/rules/run.gd:165-212,241,254-258,334-337,447-449｜Godot/three_d/scripts/table_hud.gd:140-149｜'
            + VALUABLE_EV_TAIL,
        ])
    return rows


def build_items():
    rows = []
    order = [k for k, v in ITEMS.items() if v['kind'] == 'usable']
    for i, item_id in enumerate(order, start=1):
        it = ITEMS[item_id]
        us = USABLE[item_id]
        lines, parts = USABLE_SRC[item_id]
        tri = PROPS_TRI.get(item_id, '?')
        slots = shelf_slots(item_id)
        rows.append([
            str(i), '物品-可用', item_id, it['name'],
            'assets/blender/tavern-detail/build_props.py:%s（group("%s") 构件块）' % (lines, item_id),
            parts,
            START_USABLE,
            'Godot/three_d/scripts/world.gd:978-983 make_detailed_prop()；world.gd:11 PROPS_ASSET 指向 '
            'interactive-props.glb（12 个命名节点，%s 三角面）；货架交互锚点见 '
            'Godot/three_d/scripts/bar_display.gd:37（ShelfItem）' % tri,
            '%s｜content.shops 基础配置候选位 %d 个：%s｜**实架以种子计划为准**：'
            'run_variants.gd:16-18 正种子下从非必需候选中删 1 件（ESSENTIALS 三件永不被删）；'
            'run.gd:310-311 shop_stock() 有 variant_plan 时优先返回 plan.shelves'
            % (us['shelf'], len(slots), '、'.join(slots)),
            us['take'],
            '仅文字｜Godot/three_d/scripts/services_hud.gd:45「我的背包 n/6 格」+ run.gd:440-442 bag 名称串；'
            '全文件无 TextureRect/Sprite，无图标、无 3D 展示',
            us['consume'],
            REF_SHELF,
            us['gap'],
            us['order'],
            us['deps'],
            'assets/blender/tavern-detail/build_props.py｜Godot/three_d/assets/props-export.json｜' + us['ev'],
        ])
    rows.extend(valuable_rows())
    return rows


# ---- characters.csv ---------------------------------------------------------
CHAR_HEADER = [
    '序号', '角色id', '席名/中文名', '几何组', '现有源文件', '可复用部件',
    '骨骼数', 'manifest顶点', 'GLB_POSITION总数',
    '造型开关', '配色(Wool/Hair/Skin)', '轮廓', '服装', '个人标识', '现有动画',
    '运行加载点', '参考图', '可识别性检查项', '尚缺表现', 'Phase3顺序', '依赖', '证据(文件:行)',
]

# 任务书第 1 条对「9 人物」同样要求「现有源文件 / 可复用部件 / 运行加载点 / 尚缺表现」四列，
# 与 19 件物品同口径。初稿只写了后两列，这两列是补的。
SRC_CHAR = ('assets/blender/characters/build_characters.py:9（CAST 第 %d 条）+:33-36,49-69,92,102-113；'
            'assets/blender/characters/%s.blend（可编辑源，14 骨 + 1 蒙皮网格 + 贴图内嵌，'
            'assets/blender/characters/README.md:5）；Godot/three_d/assets/characters/%s.glb；'
            'Godot/three_d/assets/characters/manifest.json')


def reuse_char(grp, cid, same):
    """该角色身上哪些东西对 Phase 3 是可复用的。

    ⚠️ 口径（B2-R1 修正）：几何相同**不等于**文件联动。
    build_characters.py:34 每轮 read_factory_settings 重建，:117/:120 按角色名分别存
    .blend/.glb；characters.gd:6-21 actor() 按角色 id 分别加载。所以每个角色都有独立可编辑源，
    可以单独制作；只有「改共用生成逻辑并全量重导」才会影响同组。
    """
    base = ('14 骨骼 rig（Godot/three_d/tests/characters_test.gd:19 断言）；'
            '4 段剪辑 idle/bet/win/fold；材质库（Wool / Hair / Skin / Ivory cotton / '
            'Polished leather / Brass，build_characters.py:33-92）；'
            'assets/blender/characters/%s.blend 为**独立可编辑源**，改本角色不需要动别人' % cid)
    if same:
        return ('与同组 %s 当前几何一致（同一循环 build_characters.py:33 生成、算法相同，'
                '不是同一份网格）；%s' % ('、'.join(same), base))
    return ('几何独有（组 %s 无同组成员），可作其他角色的对照基线；%s' % (grp, base))


def deps_char(cid, same):
    """B2-R1：整组一起改只是**建议**，不是技术前提。"""
    shared = ('各角色按名分别存 .blend/.glb（build_characters.py:117,120），本角色可单独制作；'
              '改共用生成逻辑并全量重导需重跑 build_characters.py（本轮不做）')
    if same:
        return ('与同组 %s 当前几何一致：单独改本角色会打破组内一致性，**建议**整组一并过风格与'
                '性能检查（建议，非技术前提）；%s' % ('、'.join(same), shared))
    return '几何独有，无同组联动；%s' % shared

# 参考图口径（任务书第 4 条：缺参考图只标记，不自行生图）。
# 实测：三份作者源都没有「逐件」参考图——build_props.py 中 png/参考/reference 命中 0；
# 但三份 README 各自声明了整体依据，必须引用原句，不能笼统写成「无参考」。
REF_SHELF = ('无逐件参考图｜assets/blender/tavern-detail/build_props.py 全文不含 .png、不含「参考」、'
             '不含词边界上的 reference（脚本不读任何图片文件）；'
             '作者在 assets/blender/tavern-detail/README.md:3 声明「根据现有藏匿点、烟雾酒馆和酒保交易'
             '参考图手工编写 Blender 建模脚本，不使用 image2.5 或新增 AI 参考图」——'
             '即 9 件可用道具只有整体场景板作依据，没有逐件设计图｜'
             '是否补逐件参考图需主 Agent 判断（用户尚未批准生图）')
REF_VALUABLE = ('无参考图｜作者源可查的参考图只有 assets/blender/stash-noir/README.md:3 的「皮箱／木桌参考图」，'
                '10 件贵重物里没有任何一件有对应参考图｜'
                '是否补参考图需主 Agent 判断（用户尚未批准生图）')
REF_CHAR = ('有整体参考｜assets/blender/characters/README.md:3 声明来源为「酒馆酒保交易视角.png」与'
            '「德扑牌桌视角.png」（即 assets/scene-plates/ 下同名两张板），'
            '并明示「未生成新参考图，也未引入第三方角色资产」｜'
            '无单人设计图：9 人都从这两张板推导｜'
            '是否补逐人参考图需主 Agent 判断（用户尚未批准生图）')

# build_characters.py:9 CAST 的顺序即 idx（skin 由 idx 公式派生）
CAST = [
    ('dock-braggart', (.13, .085, .045), (.035, .023, .015), True, False),
    ('ledger-clerk', (.045, .055, .065), (.08, .065, .045), False, False),
    ('river-shark', (.055, .06, .053), (.25, .24, .20), True, False),
    ('velvet-rook', (.09, .025, .038), (.022, .013, .01), False, False),
    ('calm-widow', (.035, .03, .055), (.04, .02, .012), False, True),
    ('smiling-knife', (.09, .095, .095), (.04, .025, .014), True, False),
    ('house-viper', (.024, .065, .052), (.022, .02, .015), False, False),
    ('ash-smuggler', (.115, .09, .075), (.14, .13, .12), True, False),
    ('bartender', (.045, .042, .034), (.19, .18, .16), False, False),
]
GROUP = {
    'ash-smuggler': 'A', 'dock-braggart': 'A', 'river-shark': 'A', 'smiling-knife': 'A',
    'house-viper': 'B', 'ledger-clerk': 'B', 'velvet-rook': 'B',
    'bartender': 'C', 'calm-widow': 'D',
}
GROUP_NOTE = {
    'A': 'A（4 人共用，hat=True）',
    'B': 'B（3 人共用）',
    'C': 'C（bartender 独有，standing=True）',
    'D': 'D（calm-widow 独有，female=True）',
}
GROUP_SIZE = {'A': 4, 'B': 3, 'C': 1, 'D': 1}
GROUP_SHORT = {'A': '组 A', 'B': '组 B', 'C': '组 C', 'D': '组 D'}
GROUP_ROLE = {
    'A': '4 人共用几何，仅 Wool/Hair 配色不同',
    'B': '3 人共用几何，仅 Wool/Hair 配色不同',
    'C': '几何独有（站姿），但与组 B 顶点数同为 39558',
    'D': '几何独有（束发 + 女装投影）',
}
SILHOUETTE = {
    'A': '坐姿；礼帽（Felt hat brim + Hat crown，build_characters.py:64-65）加高头顶轮廓',
    'B': '坐姿；无帽，头顶轮廓更低',
    'C': '站姿（lift=.35，膝/踝位置随之上提，build_characters.py:35,42）',
    'D': '坐姿；无帽；后脑加「Pinned hair」束发体块（build_characters.py:63）',
}
SEAT = {
    'dock-braggart': '货运桌左席', 'ledger-clerk': '货运桌右席',
    'river-shark': '账房地窖左席', 'velvet-rook': '账房地窖右席',
    'calm-widow': '镜厅左席', 'smiling-knife': '镜厅右席',
    'house-viper': '余烬桌左席', 'ash-smuggler': '余烬桌右席',
    'bartender': '四店吧台（每店 1 位，characters.gd:27 固定坐标 2.55/0/.4，yaw −π/2）',
}
ARCHETYPE = {k: v['archetype'] for k, v in CONTENT['opponents'].items()}

CLIP_NOTE = ('idle/bet/win/fold 四段（build_characters.py:102-113）。每段只驱动 1–2 根骨骼：'
             '四段都有 head，bet 额外 forearm.R，win 额外 spine（:108-110）；'
             'Godot/three_d/tests/characters_test.gd:23,29 只断言「≥1 条轨道」与 head 旋转变化 >0.02 rad')


def build_characters():
    rows = []
    for i, (cid, suit, hair, hat, female) in enumerate(CAST, start=1):
        idx = i - 1
        skin = (.38 + idx * .008, .23 + idx * .005, .15 + idx * .004)
        m = MANIFEST[cid]
        total = glb_position_total(GODOT / 'assets/characters' / (cid + '.glb'))
        switches = []
        if hat:
            switches.append('hat=True')
        if female:
            switches.append('female=True')
        if cid == 'bartender':
            switches.append('standing=True')
        if not switches:
            switches.append('无（hat/female/standing 三开关均 False，走基础坐姿分支）')
        grp = GROUP[cid]
        same = [c for c, _, _, _, _ in CAST if GROUP[c] == grp and c != cid]
        if same:
            ident = ('无独立视觉标识｜与同组 %s 共用几何、共用帽/发，差异只在 Wool/Hair 配色'
                     % '、'.join(same))
            check = ('需实机确认：在实际座位距离（characters.gd:26 对手席 x=−1.1 / 0.25）与牌桌照明'
                     '（world.gd:285-286 主光 2.2/1.0 + tavern_layout.gd:80-81 1.1/1.4 + FILMIC 色调映射 '
                     'world.gd:311-318）下，能分辨本角色与同组 %s；本组 %d 人轮廓完全一致，'
                     '只能靠西装/发色深浅区分' % ('/'.join(same), GROUP_SIZE[grp]))
        else:
            ident = '无独立视觉标识｜几何独有（%s），但无道具/纹样/配饰等人物标识' % GROUP_ROLE[grp]
            check = ('需实机确认：在实际座位距离与牌桌照明（world.gd:285-286 主光 2.2/1.0 + '
                     'tavern_layout.gd:80-81 1.1/1.4 + FILMIC 色调映射 world.gd:311-318）下，'
                     '能分辨本角色与其余 8 人；本角色靠几何（%s）而非配色区分' % GROUP_ROLE[grp])
        check += '。⚠️ 不可用「9 套配色」当作 9 人独立完成——配色是材质参数，不是造型识别度'
        rows.append([
            str(i), cid, SEAT[cid], GROUP_NOTE[grp],
            SRC_CHAR % (i, cid, cid),
            reuse_char(grp, cid, same),
            str(m['bones']), str(m['vertices']), str(total),
            '、'.join(switches),
            'Wool(%.3f,%.3f,%.3f) / Hair(%.3f,%.3f,%.3f) / Skin(%.3f,%.3f,%.3f)'
            % (suit + hair + skin),
            SILHOUETTE[grp],
            '西装椭圆体 + 无扣翻领×2 + 领带 + 马甲三扣 + 贴体衬衫（Fitted shirt）；'
            + ('Sleeve 用 shirt 材质（站姿分支，build_characters.py:69）' if cid == 'bartender' else 'Sleeve 用 suit 材质')
            + ('；Jacket 半径收窄至 .18（build_characters.py:49），Fitted shirt 投影同步收窄（:92）' if female else ''),
            ident,
            CLIP_NOTE,
            'Godot/three_d/scripts/characters.gd:6-21 actor() 载入 '
            'res://three_d/assets/characters/%s.glb；：22-27 build() 座位固定 x=−1.1/0.25；'
            ':32-42 sync() 换桌重建；:44-56 refresh() 由 Godot/three_d/scripts/world.gd:667 每手调用' % cid,
            REF_CHAR,
            check,
            '五官/表情拓扑未做（体素融合面部）；无指骨；发牌/下注/递物为通用 1–2 骨骼摆动；'
            '无个人标识道具；约 4 万顶点未做低模与性能验收',
            '4（人物辨识度）',
            deps_char(cid, same),
            'assets/blender/characters/build_characters.py:9,33-36,49-69,92,102-113｜'
            'assets/blender/characters/README.md:3,5,9｜'
            'assets/blender/characters/%s.blend（可编辑源）｜'
            'Godot/three_d/assets/characters/manifest.json｜Godot/three_d/assets/characters/%s.glb｜' % (cid, cid) +
            'Godot/three_d/scripts/characters.gd:6-59｜Godot/three_d/scripts/world.gd:285-286,311-318,667｜'
            'Godot/three_d/scripts/tavern_layout.gd:80-81｜Godot/three_d/tests/characters_test.gd:19-33,44-46',
        ])
    return rows


def write_csv(name, header, rows):
    path = DEST / name
    with path.open('w', encoding='utf-8-sig', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)
    return path, len(rows), len(header)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    items = build_items()
    chars = build_characters()
    p1, n1, c1 = write_csv('items.csv', ITEM_HEADER, items)
    p2, n2, c2 = write_csv('characters.csv', CHAR_HEADER, chars)
    print('ITEMS      %s  rows=%d cols=%d' % (p1.name, n1, c1))
    print('CHARACTERS %s  rows=%d cols=%d' % (p2.name, n2, c2))
    assert n1 == 19, 'items.csv 必须 19 行，实为 %d' % n1
    assert n2 == 9, 'characters.csv 必须 9 行，实为 %d' % n2


if __name__ == '__main__':
    main()
