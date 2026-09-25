# 任务 B：内容与资产对应检查（交付说明 · B1 返修后）

执行日期：2026-09-21（初版，基线 `b158491`）；**返修日期：2026-09-22（基线 `413dce9`）**。

> **本文件已按主 Agent《外部交付验收与后续任务（2026-09-21）》第 4 节 B1 返修。**
> 逐条「修订前 → 新证据 → 修订后」见同目录 **`corrections.md`**；机器可核对快照见
> `output/external-handoff/B1/b1-audit.json`（重跑脚本 `output/external-handoff/B1/b1_audit.py`，只读）。
> 本轮**只做事实返修**：未执行 build/export，未覆盖资产，未生图，未改代码或规则，未 commit。
> **返修后已做对抗性审查**：`firstAggressionDiscount` 一行的"0 命中"与复现命令曾自相矛盾，已修正为三口径（内容字段名 0 / 同义状态字段 12 行 / 字面量 `10` 共 7 处），见 §2.5 与 `corrections.md` B1-7 的「审查后订正」；总报告见 `docs/3d-production/external-handoff/对抗性审查-B1C1-2026-09-22.md`。

本轮**沿用**上一轮 `docs/3d-production/inventory/` 的清点结论，不重做素材清单；编号与命名保持原样，本目录只补"当前实现状态"与差异。

依据顺序：`Godot/three_d/rules/content.json` + 实际执行代码 > `src/data.js` > 文档。文档与代码冲突时以代码为准，并记录冲突（见任务 C 的 `doc-corrections.md`）。

---

## 一、计数口径（必须先讲清楚，否则数字对不上）

| 类别 | 目标值 | 本轮实测 | 口径说明 |
|---|---:|---:|---|
| 酒馆 | 4 | 4 | `content.json` 的 `scenes`。四店**共用同一套 3D 空间外壳**，差异只体现在费率/货架/路线/色板 |
| 牌桌 | 4 | 4 | `content.json` 的 `tables`：cargo-table / ledger-cellar / mirror-hall / embers-table。牌桌可在任意酒馆出现（房间连接池），不属于某一家酒馆 |
| 对手 | 8 | 8 | `content.json` 的 `opponents`，每桌 2 位。**酒保不是第 9 位对手**，单独在 `content-matrix.csv` 里以"酒保"类别记录 |
| 物品 | 19 | 19 | 9 usable（`kind:"usable"`）+ 10 valuable（`kind:"valuable"`） |
| **酒馆专属路线** | **16** | **16** | **口径：4 家酒馆 × 每店（2 条固定 + 2 条特殊）= 16**。这是"16 条"的唯一算法 |
| 通用撤离类型 | 4（非上述 16 的一部分） | 4 | general / fixed / dropbag-cash / dropbag-valuables，见 `routes.gd:10-42`。它们是**跨店共用的撤离类型**，不计入 16 |

> 上一轮 inventory 里"16 条专属 + 4 类通用"的写法正确。若有人把 `generalExtractionFlatFee` 这类**每店费率**也当成路线，或把 `fixed` 通用类型与 8 条固定路线重复计数，就会得到 20 或 24。**本表以 4×(2+2)=16 为准。**

### 交付文件的行数（返修后口径）

| 文件 | 数据行 | 列数 | 说明 |
|---|---:|---:|---|
| `content-matrix.csv` | **56** | 18 | 酒馆 4 + 牌桌 4 + 物品 19 + 对手 8 + 酒保 1 + 路线（固定 8 + 特殊 8）+ 通用撤离 4 = **56** |
| `asset-gaps.csv` | **14** | 8 | 与上一版一致，本轮只改其中 5 行的内容 |

> **上一版 §一 末尾写的「共 55 行 … = 实际 56 行」自相矛盾，已删除。当前统一为 56 行。**
> 行数重跑：`python3 -c "import csv;print(len(list(csv.DictReader(open('content-matrix.csv',encoding='utf-8-sig')))))"`

### 道具的"三级数量"（上一版把三级混成了一级）

上一版写「9 件可用道具有独立 GLB」，被读成 9 个独立文件。实际是**一个文件、十二个部件、九件道具**：

| 层级 | 数量 | 证据 |
|---|---:|---|
| **文件数** | **1** | `world.gd:11 PROPS_ASSET = preload("res://three_d/assets/interactive-props.glb")` |
| **网格/部件数** | **12** | `interactive-props.glb` 的 glTF 节点名 12 组；`props-export.json` 12 键；`art_integration_test.gd:24-28` 对 12 个 id 逐个断言 |
| **道具数（usable）** | **9** | `content.json` 的 `kind:"usable"`；另 3 个部件（`drawer` / `loose-card` / `loose-chip`）是场景件，不是道具 |

---

## 二、逐类核对结果

### 2.1 物品（19 项）

- **9 件可用道具**：购买/出售、使用时机、风声与占格、消耗记录（`used_tools`）、存档回放均有一致性断言；9 件在场景里都是 `interactive-props.glb` 内的**命名部件**（见上表）。其中 5 件（透镜、袖夹、手机、笔记、通行证）在 `service_reason` / `advanced_services.reason` 里有独立拒绝分支并已被覆盖套件命中。
  唯一 `部分验证`：**信号打火机**的强/中/弱阈值与有效对手计数仍列在 `pending_families.signal_analysis`（**功能已实现，缺的是独立断言**）。
- **10 件贵重物**：价值、占格、抵押、撤离计价、奖励发放都已在规则侧生效且被测试覆盖；**7 件的"出售路径"没有独立断言**——`sale_value()`（`run.gd:447-449`）对贵重物返回 `value` 而非 `sell`，这条分支只在 3 件（ivory-chip / emerald-brooch / pearl-necklace）上被测过。
  > **写法纠正**：这里只能写「出售路径**未单独断言**」，**不能写"没有售卖逻辑"**。`sale_value()` 是明确存在且在跑的分支；缺的是覆盖粒度，不是功能。
- **占 2 格的贵重物是 3 件，不是 4 件**：`content.json` 实测 `slots == 2` 仅 **sealed-bond / obsidian-idol / vault-promissory**；其余 7 件为 1 格。背包 6 格（`inventorySlots: 6`）下"带 2 格重物撤离"的取舍仍存在，但门槛比上一版描述低一档。
- **3D 呈现**：10 件贵重物都**没有独立模型，也没有背包/奖励的 3D 表现**（界面为纯文字，`table_hud.gd:144-148` 抵押下拉）。但"3D 完全不可见"**是错的**：`stash-noir` 有第 05 组「Personal valuables」静物装饰（银烟盒 / 珍珠项链 / 怀表），经 `export_game_asset.py:17`（保留组号 01-07）与 `:53`（`'05':'Valuables'`）合并进 `stash.glb` 的 **`Valuables` 节点**，随 `world.gd:181` 在藏匿点加载 → **可见**。逐件对应见 §三 与 `corrections.md` B1-4。
- 物品获得来源只有两条：**商店购买**（9 件可用道具，按轮次/种子决定货架）与**牌桌盈利奖励**（10 件贵重物，`run.gd:198-202` 硬编码映射）。搜索事件也能产出一件旧银打火机（`search_coverage_test.gd:51`）。

### 2.2 路线（16 + 4）

- 16 条酒馆专属路线的**预付/尾款/风声上限**四项数值已逐条核到 `content.json` 行号，并可与 `routes.gd`、`run.gd`、`advanced_services.gd` 对上。
- **两段式扣费已核实**：固定路线先在探索阶段付 `reserve_fee()`（`run.gd:530-531`），撤离时再付 `finalCost`（`routes.gd:20`），**两次独立扣除，不互相抵扣**。上一轮 inventory 的 §2 疑点 P1 结论正确。
- **特殊路线无预付款**：`specialRoutes` 条目里根本没有 `reserveCost` 字段，只收 `finalCost`，并从 `hiddenRouteRevealDiscount` 中扣减（`routes.gd:27`）。
- **有效期只对 `fixed` 生效**：`expiresAfterSearch = search_index + max(1, fixedRouteGraceSearches)`（`advanced_services.gd:50`），轮数按店不同（2/3/1/2）。
- **失败代价**：撤离本身没有"失败罚金"概念。真正会丢东西的只有两种紧急出口（舍弃 40% 现金 / 舍弃全部贵重物）和放弃本局（只靠夹层钱包保留 80）。**`forcedExitLossFactor` 这个每店系数在 Godot 侧未被任何代码读取**（见 2.5）。
- **`specialRoutes` 的键与实际 `id` 不一致**（仅 smoky-den 一致）：high-rise 的键 `service-stairs`→id `service-elevator`、`river-launch`→`basement-garage`；rooftop 的键 `service-stairs`→`emergency-exit`、`river-launch`→`helipad-drop`；neon 的键 `service-stairs`→`neural-jammer`、`river-launch`→`quantum-portal`。**本轮确认这不是文档笔误，而是 `content.json` 里真实存在的数据形态**，且 `run.gd:536-538` 与 `advanced_services.gd:53/55` 都按**键**取用、`route_name()`（`run.gd:536`）展示时用**id**，两套名字同时在跑。

### 2.3 对手（8 位）

- 8 位对手的 `archetype` 与 5 个性格参数（`aggression / caution / bluff / finalHandSpike / patternPunish`）在 `content.json` 完整定义，且 `opponent_profiles` 断言了分布差异（例如 smiling-knife 的终手 all-in 概率高于早期）。
- 桌位分配是**种子洗牌**的：两组分别洗牌、每桌各取一位，八位都可能出现在任意桌（`seeded-pools.md` 第三批）。**因此"某位对手只属于某个酒馆"的说法不成立**，只有"某张牌桌"是固定的。
- **三种数量口径（补齐）**：**8 位对手 / 9 个角色 / 4 套几何 × 9 套配色**。上一版把"顶点数只有 3 种取值"直接推成"实际是 3 套共享网格"，**这一步推理不成立**——见 §三 人物行与 `corrections.md` B1-2。
- **`content.json` 里四张牌桌各自的静态 `opponentIds` 是对局中不可达、但不可删的字段。**
  - 不可达：对局起始种子由 `world.gd:772` 用 `int(randi() % 2147483646) + 1` 生成，**恒 ≥ 1**；而 `run_variants.gd:30-31` 只在 `seed_value == 0` 时才回落到静态名单。
  - **不可删**（上一版只说了"半死字段"，漏了这层）：该分支同时承担 **① 旧存档兼容**（`opponent_pool_test.gd:66` 断言"旧计划保留历史名单"）、**② 调试/回放入口**（`run_variants.gd:17-18 / :23` 的货架变异与初始接应都以 `seed_value != 0` 为条件）。**建议标注为"仅 seed=0（旧存档兼容 / 调试回放）生效"，而不是删除。**
  - 实际生效的是 `run_variants.gd:33-35`：`PRESSURE_POOL = ["dock-braggart","velvet-rook","ash-smuggler","smiling-knife"]` 与 `VALUE_POOL = ["ledger-clerk","calm-widow","river-shark","house-viper"]` 各自洗牌后，第 i 桌取 `[pressure[i], value[i]]`，再由 `run.gd:161-162` **整表覆盖** `definition.opponentIds`。
  - 由此产生两条容易踩坑的推论：**①** 每张桌的第 0 位（左位）永远是压力池成员、第 1 位（右位）永远是价值池成员，两池互不越位；**②** 静态数据的**顺序**与运行时约定 `[pressure, value]` **只有 cargo-table 一致**——`cargo-table: ["dock-braggart","ledger-clerk"]` 是 `[pressure, value]`，而 `ledger-cellar: ["river-shark","velvet-rook"]`、`mirror-hall: ["calm-widow","smiling-knife"]`、`embers-table: ["house-viper","ash-smuggler"]` 都是 `[value, pressure]`，**正好相反**。这个"四个桌里只有一个对"的不一致本身才是要报的坑。
  - 实践影响：任务 A 的 `two_tables` 套件就是因为照静态名单断言"账房地窖左位 = river-shark"而永久失败（详见 `../A-regression/issues.md` A-5b）。建议主 Agent 择机把静态 `opponentIds` 与运行时常量对齐为 `[pressure, value]`。
- 酒保不计入 8 位对手。

### 2.4 酒馆规则差异（4 家）

- 已逐店核对 12 个参数，**10 个确实被执行代码读取**：`heatReductionCost`、`generalExtractionFlatFee`、`generalExtractionRate`、`lockdownSurcharge`、`fixedRouteReserveDiscount`、`fixedRouteGraceSearches`、`entryHeatBonus`、`hiddenRouteRevealDiscount`、`tableToolHeatBonus`（`run.gd:363` + `advanced_services.gd:79`）、`winHeatRelief`（`run.gd:209`）。
- **2 个参数存在但没有任何执行代码读取**：`intelBonus`、`forcedExitLossFactor`。

### 2.5 `content.json` 里"存在但 Godot 侧没读（或只读一部分）"的字段

在 `Godot/three_d/**/*.gd` 全量检索后，按**性质**分三层（上一版只有"读了/没读"两层，导致 `baseRewardPool` 被误判）：

| 字段 | 位置 | 命中 | 性质 | 影响 |
|---|---|---:|---|---|
| `baseRewardPool` | 四张牌桌 | **1（`run.gd:432`）** | **仅展示** | **上一版写"未被读取"是错的**：它在情报文案里被拼进字符串。但奖励**发放**走 `run.gd:198-202` 的硬编码 `match`，与之**不同源** → "情报显示的奖励池 ≠ 实际发放规则"这个影响仍然成立，原因从"零读取"改为"**双份真相**" |
| `signatureReward` | 四张牌桌 | 0 | 未读取 | 奖励由 `run.gd:198-202` 硬编码，数据与逻辑双份真相 |
| `firstAggressionDiscount: 10` | cargo-table | **内容字段名 0；同义状态字段 12 行** | 未读取（**字面量 `10` 共 7 处** + 1 处桌名门 + 2 处断言） | `content.json` 的字段名 `firstAggressionDiscount` **确实 0 命中**。但折扣不是"没有实现"，而是由**运行时状态字段** `firstAggressionDiscountAvailable` 承担：`table.gd:26` 用 `state.tableDef.id == "cargo-table"` 定值开关，`table.gd:67` 与 `table_hud.gd:201` 取字面量 `10`。**字面量 `10` 共 7 处**：生产 2（`table.gd:67`、`table_hud.gd:201`）＋测试 5（`tests/raise_preview_test.gd:19`、`tests/poker_action_coverage_test.gd:32`、`tests/poker_guard_coverage_test.gd:29/30/31`）；另有 **2 处断言把折扣写进期望值**（`tests/table_test.gd:67`、`tests/two_tables.gd:26`）。改 `content.json` 数值不生效；改桌名会静默失效 |
| `publicInfo` / `hiddenInfo` | 四张牌桌 | 0 | 未读取 | 规则文案是 `run.gd:524-525` 的硬编码 map |
| `intelBonus: 1`（neon） | `scenes` | 0 | 未读取 | 遗留字段（与上一轮 inventory 判断一致） |
| `forcedExitLossFactor` | 四家酒馆 | 0 | 未读取 | 遗留字段；失败损失实际由 `routes.gd:37` 与 `run.gd:461` 决定 |
| `revealFlag`（各特殊路线） | `routes` | 0 | 未读取 | 实际用的是 `unlockRoute`（`advanced_services.gd:41/53`）；`revealFlag` 是 web 版遗留 |

> 结论：**"参数存在"≠"执行代码确实读取"**，且**"被读取"也≠"参与结算"**（`baseRewardPool` 就是只展示的那种）。
> 上表 6 行"零读取"字段需要在 Phase 2 决定是"接线"还是"清理"，本任务不代为决定。
> **口径警告**：不要把 `firstAggressionDiscount`（`content.json` **字段名**，0 命中）与 `firstAggressionDiscountAvailable`（`Table` 的**运行时状态键**，12 行命中）混成一次 grep——合并搜索会得到"12 命中"，与表里的"0"看起来冲突。两者不是同一个东西。
> 复现（按字段分开搜，结果与上表逐格对应）：

```sh
# 6 个"真·零读取"字段：应 0 命中
grep -rn --include='*.gd' -e signatureReward -e publicInfo -e hiddenInfo \
     -e intelBonus -e forcedExitLossFactor -e revealFlag Godot/three_d

# firstAggressionDiscount 分两步：字段名 0 命中，但同义状态字段有 12 行
grep -rn --include='*.gd' firstAggressionDiscount Godot/three_d         # 12 行，全是 …Available
grep -rn --include='*.gd' -E '10 if .*(iscount|table_id == "cargo-table")' Godot/three_d   # 7 行字面量 10
```

### 2.6 `src/data.js` 与 `content.json` 的差异

对照结果：**数量与字段结构一致**（4 酒馆 / 4 牌桌 / 8 对手 / 19 物品 / 16 路线；`generalExtractionFlatFee` 等 13 个字段在两边都出现 4 次或 1 次）。差异是"**方向性**"的：

- `src/data.js` **有**而 `content.json` **没有**：无（本轮未发现）。
- `content.json` **有**而 `src/data.js` **没有**：`searchActions`、`inventorySlots`、`standardBankroll`、`startingVault` —— 这 4 个是 Godot 侧新增的规则参数（行动力、背包格数、试玩本金、初始金库）。
- 两边都定义但 **Godot 不消费**的字段见 2.5。
- **按任务要求，未擅自同步 `src/data.js`**。web 版与 Godot 版目前是"同一份内容、两套消费逻辑"，`firstAggressionDiscount` 这种"数值可调"的字段在 Godot 侧已退化。

---

## 三、资产实际情况（详见 `asset-gaps.csv`）

| 实体 | 目标 | 现状 | 差距 |
|---|---:|---|---|
| 空间 | 5（藏匿点 + 4 酒馆） | 藏匿点有独立 Blender 资产；**四家酒馆共用同一套灰盒外壳 + 细节包** | 缺 4 套可辨识建筑；Tavern / LedgerCellar / MirrorHall / EmbersRoom 由 `world.gd:206 build_tavern()` **同一函数**生成（`:79-82` 四次调用，offset 10/20/30/40），只是"同一建筑内的不同牌室"，**不是四/五套空间** |
| 人物 | 9（8 对手 + 酒保） | 8 对手 + 酒保的 `.blend` 与 `.glb` 都在（14 骨骼 / 4 段动画 / 已验证骨骼形变）；酒保 **GLB 已接线**（`characters.gd:27`，占位盒体被 `:28-30` 隐藏） | **几何 4 套 × 配色 9 套**（详见下方专表）。缺雕塑级细节、面部/服装差异、个人道具 |
| 道具 | 19 | **9 件可用道具是 `interactive-props.glb` 内的命名部件**（该 GLB 共 12 部件） | **10 件贵重物无独立模型**；藏匿点有 2 件可辨认静物装饰（珍珠项链、金壳怀表）+ 1 件近似（银烟盒）+ 1 件材质级（象牙筹码），但**没有可用道具、没有背包/奖励 3D 表现** |
| 空间参考图 | — | 四店 `bgImage` 均存在（1376×768） | VIP Elevator 图错放在 smoky-den 目录；屋顶无 heliport 专属图（沿用上一轮结论） |

### 人物几何分组（返修核心证据）

对 9 个 GLB 的 **POSITION** 与 **JOINTS_0 / WEIGHTS_0** 取原始字节 `sha256`：

| 组 | 成员 | manifest 顶点 | GLB 顶点合计 | 差异开关（`build_characters.py:9 CAST`） |
|---|---|---:|---:|---|
| **A** | ash-smuggler / dock-braggart / river-shark / smiling-knife | 40282 | 41463 | `hat=True`（多一顶帽） |
| **B** | house-viper / ledger-clerk / velvet-rook | 39558 | 40617 | 无帽、非女性、非站立 |
| **C** | **bartender** | 39558 | 40617 | `standing=True`（`lift=.35`、膝/踝位置、`Sleeve` 材质分支） |
| **D** | **calm-widow** | 38588 | 39708 | `female=True`（`Pinned hair`、`Jacket/Cranium/Jaw/Cheek` 尺寸、`Fitted shirt` 投影） |

- **几何+蒙皮互不相同的组数 = 4**（不是 3）。C 组 `bartender` 与 B 组**顶点数相同而顶点坐标不同**，正是"顶点数相同 ≠ 几何相同"的反例。
- **配色 = 9 套**：9 个 GLB 的材质名完全一致（`Wool/Hair/Brass/Skin/Eye white/Iris/Lips/Ivory cotton/Polished leather`，各 9 个，无贴图），但 `(Wool, Hair, Skin)` 的 `baseColorFactor` **9 人 9 套、无重复**。
- `manifest.json` 的 `vertices` 是 Blender 侧 `len(body.data.vertices)`（`build_characters.py:121`）；GLB 的 POSITION 合计是导出按 UV/法线切分后的数。**两者都对，但不是同一个量**，不可混用。
- 复现：`python3 output/external-handoff/B1/b1_audit.py`

### 道具与贵重物的"存在形式"分级

| 级别 | 可用道具（9） | 贵重物（10） |
|---|---|---|
| 独立可复用模型 | — | **0 件** |
| 同 GLB 内的命名部件 | **9 件全部** | 0 件 |
| 场景内静态装饰 | — | 珍珠项链 / 金壳怀表（可辨认）、银烟盒（近似旧银打火机）、象牙筹码（材质级） |
| 背包或奖励的 3D 表现 | 0 件（文字列表） | **0 件**（纯文字下拉，`table_hud.gd:144-148`） |
| 独立 Blender 源文件 | 无（共用 `interactive-props.blend` + `build_props.py`） | **无**（仅 `stash-noir` 静物场景的一部分） |

> **两条口径纪律**：① 装饰存在 ≠ 可用道具已完成；② 独立道具缺失 ≠ 任何场景都没有相似实体。

---

## 四、需要主 Agent 决定的问题

1. **`specialRoutes` 键与 id 的双名字**：统一成一套，还是在 3D 路线系统里显式保留"dispatch key / display id"两层？现状下 `run.gd` 按键取、`route_name()` 按 id 显示，任何人只改一边都会静默错位。
2. **6 个"零读取"字段**：接线（让数据可调）还是删除（减少双份真相）？建议至少先决定 `firstAggressionDiscount`——它是 Phase 1 难度曲线里写进 `difficulty-curve.md` 的规则。（注：`413dce9` 之后它有 **7 处**字面量 `10`，接线时须同步改生产 2 处 `table.gd:67`、`table_hud.gd:201`，再加桌名门 `table.gd:26`、测试 5 处与断言 2 处——见 §2.5。）
3. **`baseRewardPool` 的双份真相**：让奖励发放改读该字段，还是把它降级为"纯展示"并加注释？
4. **静态 `opponentIds` 的顺序**：是否把 `ledger-cellar / mirror-hall / embers-table` 改成与运行时一致的 `[pressure, value]`？（现在只有 `cargo-table` 一致。）
5. **`bar_display` 的遗留占位盒体与手部 tween**：何时清理？（不影响可见结果，可推迟到 Phase 3。）
6. **10 件贵重物的 3D 呈现**：Phase 3 是否要为占 2 格的 3 件（sealed-bond / obsidian-idol / vault-promissory）做体积差异？抵押选择界面已经能用文字跑通，模型不是 Phase 1 阻塞项。
7. **四店建筑是否要拆成 4 套空间**：`cross-venue-evening.md:25` 已明示"共享灰盒，不能计作四种独特建筑美术完成"。Phase 1 不需要，但 Phase 3 的工作量取决于这个决定。
8. **`src/data.js` 的定位**：web 版是否继续作为规则参考？若 Godot 是唯一权威，`data.js` 里那些 Godot 不读的字段会成为持续误导源。

---

## 五、状态用词（返修后改为两列制）

`content-matrix.csv` **不再只有一列 `状态`**，改为两列，解决"部分实现"和"未单独测试"混用：

| 列 | 取值 | 本轮分布 | 含义 |
|---|---|---:|---|
| `实现状态` | `已实现 / 部分实现 / 未实现` | **已实现 56** | 规则在代码里是否跑得起来 |
| `验证状态` | `已核验 / 部分验证 / 未验证` | **已核验 48 / 部分验证 8** | 是否有可定位到该维度的独立证据 |

- `部分验证` 的 8 行：**信号打火机**（阈值未单列断言）+ **7 件贵重物**（出售路径未单独断言）。每行的 `缺口` 列写明缺什么。
- **本轮无 `部分实现`、无 `未实现`、无 `未验证` 行。**
- 另新增 **`生成脚本 / 导出文件 / 加载函数 / 运行使用点`** 四列，对 **19 物品 + 9 人物共 28 行**填了完整链路；其余 28 行（酒馆 / 牌桌 / 路线 / 通用撤离）是规则与内容实体，无对应美术资产链路，留 `-`。
- 不留无解释的空白：每条 `缺口` 列要么写具体缺口，要么写 `-`。
- **写作纪律**：功能在跑但缺证据 → 写"未单独断言"，**不写"没有该逻辑"**；只有代码里真的没有入口，才写"未实现"。

---

## 六、执行与边界

- 本轮**未运行任何测试**（任务 B 只读代码与既有资料；测试执行由任务 A / A2 独占）。文中所引测试项数均来自既有测试脚本源码，不是本轮执行结果。
- 未修改 `Godot/three_d/rules/`、`scripts/`、任何 `.blend` / `.glb` / 贴图，未修改 `src/`。
- 未执行 build / export，未覆盖资产，未启动编辑器，未生成任何模型、贴图或购买素材。
- 未覆盖旧 `inventory/` 文件，未做重命名或删除。
- 未决定玩法修改；2.5 节列出的字段问题一律只报不改。
- 未 commit / push。

### 计数与字段核对的可复现方式

三项事实已固化成**一键只读脚本**，产出 JSON 快照：

```sh
python3 output/external-handoff/B1/b1_audit.py        # -> output/external-handoff/B1/b1-audit.json
```

它覆盖：9 个角色 GLB 的几何/蒙皮 sha256 与材质基色、`interactive-props.glb` 与 `stash.glb` 的节点名、`content.json` 的四类计数与占 2 格清单、矩阵自身行数、以及 9 个字段在 `.gd` 里的命中点。

另外两条随查随用：

```sh
# 内容数量与路线键/id 对照
python3 -c "
import json,pathlib
c=json.loads(pathlib.Path('Godot/three_d/rules/content.json').read_text())
print('tables',len(c['tables']),'opponents',len(c['opponents']),'scenes',len(c['scenes']),'items',len(c['items']))
for v,d in c['routes'].items():
    print(v,len(d['fixedRoutes']),len(d['specialRoutes']),list(d['specialRoutes'].keys()),[r['id'] for r in d['specialRoutes'].values()])
"
```

```sh
# 6 个零读取字段应只命中测试脚本或 0 处
grep -rn --include='*.gd' -e firstAggressionDiscount -e signatureReward -e publicInfo -e hiddenInfo -e intelBonus -e forcedExitLossFactor -e revealFlag Godot/three_d
```

### 返修痕迹

| 文件 | 改动前副本 |
|---|---|
| `content-matrix.csv` | `output/external-handoff/B1/content-matrix.csv.bak` |
| `asset-gaps.csv` | `output/external-handoff/B1/asset-gaps.csv.bak` |

可逐单元格比对；迁移脚本 `migrate_matrix.py` / `patch_asset_gaps.py` 同目录。
