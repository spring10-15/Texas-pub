# C1 返修记录：验收口径与试玩清单

返修日期：2026-09-22。本轮对应主 Agent《外部交付验收与后续任务（2026-09-21）》第 5 节 C1。

**写法**：每条按「修订前结论 → 新证据 → 修订后结论」记录，并指向被改动的文件。
**边界**：只改本目录内的文档；**未改任何被引用的项目文档，未改代码、规则、资产**；未打开游戏，未测性能，未组织试玩。
**核查脚本**：`output/external-handoff/C1/verify_links.py`（引用可打开性自检，可重跑）。

同时被改动的文件：

| 文件 | 改动 |
|---|---|
| `doc-corrections.md` | 7 条重新归类：DC-04 撤回、DC-07 改写为"历史快照提示"、DC-01/02 标"已处理"、DC-05/06 改"范围/日期补注"、DC-03 收窄作用范围；新增"冲突条数"口径表与路径约定 |
| `gate-matrix.md` | 门槛 1 结算口改为闭合边界（新增 §一之二）；门槛 4 的 `pending_families` 描述重写、登记数改 252；门槛 5/6 与 §四 真人口径改写；§二 第 11/12 项计数带日期；§五 第 7 项条数修正 |
| `walkthrough-checklist.md` | 第 3 步本金逐档写清；第 4 步标为整局起点、第 16 步标为终点；第 15 步补计费公式（取整/条件）；附注 1 重写为"单桌安全路线 ≠ 正常局" |
| `README.md` | 交付文件表补 2 个新文件；新增"文档冲突条数"统一表；§二 P3 行改写；§三 测试计数改带日期的单一口径；§五/§六 边界与路径约定 |
| `real-player-protocol.md` | **新增**（一页待执行真人协议） |
| `corrections.md` | **新增**（本文件） |

---

## 一句话结论

初版 C 的**模板可用**，但有 4 处口径会直接误导读者：① 门槛 1 的守恒等式是**无条件**写法；② 门槛 4 声称 `pending_families` 含 `showdown_winner_allocation`（**从来不在**）；③ 真人状态写成"没有任何数据"（**否定了事实**）；④ 整局起点算在首桌开始。四条都已在返修中改正，并新增了一页可执行的真人协议。

---

## C1-1 撤回 DC-04，并删除 gate-matrix 的错误描述

- **修订前结论**：
  - `doc-corrections.md` DC-04 标题为「`[自相矛盾]` 待办项在文档里有、在机器可读目录里没有」，建议"把 `showdown_winner_allocation` 补进 `transitions.json` 的 `pending_families`"，或改文档。
  - `gate-matrix.md` 门槛 4 的当前证据写：「`pending_families` 仍明确保留 `signal_analysis`、`showdown_winner_allocation`、`short_all_in`/… 等未拆分族」。
- **新证据（两条独立证据）**：
  1. **`pending_families` 里从来没有 `showdown_winner_allocation`**。2026-09-22 复核 `docs/3d-production/phase-1/coverage/transitions.json`，`pending_families` 只有 **3 族**：`poker`（6 项）、`world`（8 项）、`persistence`（7 项）。原建议"补进 `pending_families`"是**分类错误**。
  2. **胜者与边池分配已有独立金额预期**：`docs/3d-production/phase-1/coverage/README.md` 的「胜者与边池独立金额预期（2026-09-14）」小节（当前 `:132-134`）已登记 `payout.*` **六种结果**——单一胜者、三层贡献、最强牌已弃牌、三人公共牌平分、各层边池平分、平分余数；且**预期金额直接写入测试，不调用同一个 evaluator 生成答案**。所以"胜者分配完全未登记"这个前提不成立。
  3. 附带发现：`signal_analysis` 也**已不在** `pending_families`（已在后续批次拆入目录后移出，见 `coverage/README.md:170`）。
- **修订后结论**：
  - **撤回 DC-04**（在 `doc-corrections.md` 中改为 `[撤回]` 并保留理由，避免后人重复提）。
  - `gate-matrix.md` 门槛 4 的 `pending_families` 描述**整段重写**为当前 3 族并逐项列出，且加一句「族名会随批次增减（`signal_analysis` 已移出），引用时必须带日期」。
  - `gate-matrix.md` §四 第 8 项改写为：`payout.*` 已有六种独立金额预期，**仍未穷尽全部牌型与下注路径**（这才是真实局限）；并明确写下「不要再把 `showdown_winner_allocation` 写成 `pending_families` 的待办族」。
- **顺带修正一个计数**：`transitions.json` 的登记条目当前为 **252**（不是初版引用的 239），见 C1-2。

---

## C1-2 DC-07 改为"历史快照阅读提示"

- **修订前结论**：DC-07 标题为「`[自相矛盾]` 同一份覆盖说明里，登记结果数前后不一致（226 vs 239）」，把它当成**同时成立的计数冲突**。
- **新证据**：
  - `docs/3d-production/phase-1/coverage/README.md` 当前 `:3` 已由主 Agent 加上**阅读口径横幅**：「下文按实现批次保留历史快照，226、232、239、247、252 等数字各对应当时状态。最新登记数为 252……」
  - 数值序列是**实现批次的演进**：226（poker_progress 批次）→ 232（payout 批次）→ 239（transfer/endgame 批次）→ 247 → **252**（`signal_analysis` 拆入目录后）。
  - 同理"十二个 / 十五个覆盖套件"是当时的套件数，当前为 **17 个**（`Godot/three_d/tests/collect_coverage.py` 的 `SUITES` 字典实数）。
- **修订后结论**：
  - DC-07 标记改为 `[历史快照提示]`，重写为「这些数字**不是计数冲突，而是批次演进**；**保留历史叙述**（这正是可追溯的实现记录），只要求当前状态指向最新汇总」。
  - 明确写出**当前权威值**（`status=incomplete_catalog`、252 条、3 族、`overall_state_transition_coverage=null`）与**基线**（`413dce9`）。
  - `gate-matrix.md` 门槛 4 的 239 → **252（带日期与历史序列）**；"未发现冲突"表同步更新。
  - 本条**不再需要外部动作**（主 Agent 已加横幅）。

---

## C1-3 DC-01/02 标"已处理"；DC-05/06 改"范围/日期补注"

- **修订前结论**：DC-01/02/05/06 都以 `[过时]` 标注，读起来像"当时写错了"。
- **新证据（2026-09-22 逐字复核）**：

  | 条 | 目标 | 现状 |
  |---|---|---|
  | DC-01 | `docs/3d-production/phase-1/difficulty-curve.md` | **已改**：原"尚未接通"句已换成"跨酒馆首版已接通……访问顺序与多店经济压力尚未完成难度采样"，实质约束保留 |
  | DC-02 | `docs/3d-production/phase-1/seeded-pools.md:3` | **已按建议原文改**："跨酒馆流转已于 2026-09-14 接入首版（见文末及 cross-venue-evening.md）" |
  | DC-03 | `docs/3d-production/checkpoint-progress.md:14` | **未改**（仍缺 `-- --test`） |
  | DC-05 | `design-baseline.md:226 / :287-290` | **未改**；但 `:227` 原文自己就写着"两张桌是模板，不证明最终只有两张固定牌桌" |
  | DC-06 | `docs/3d-production/implementation-progress.md:3` | **未改**；该分工边界在 **2026-09-08** 写作时是正确的，第二轮协作是之后才开的 |

- **修订后结论**：
  - DC-01 / DC-02 → 标 `[已处理]`，保留原文与现文对照，写明"**本条不再需要外部动作**"。
  - DC-05 / DC-06 → 标 `[范围/日期补注]`，改写为「原文在**当时的范围/日期**下成立，缺的只是限定词，**不是"写错"**」；建议做法改为"**只在文件开头加一行状态横幅**（不改原句）"。
  - DC-05 的横幅明确把 all-in / 边池 / 平分三项写成"**该阶段范围**……**不代表本文写作时写错**"。
  - DC-06 的补注只加一个括号：「（2026-09-21 补注）……外部协作分两轮：第一轮为 `inventory/` 资料清单（即本句所描述的范围）……」。
- **新增冲突条数口径表**（解决初版 `README.md` 写"6 处"、`doc-corrections.md` 有 7 条的矛盾）：

  | 项 | 数 |
  |---|---:|
  | 累计提出 | 7 |
  | 主 Agent 已处理 | 2 |
  | 已撤回 | 1 |
  | **仍待处理** | **1（DC-03）** |
  | 仅需补注 | 3 |

  即 **7 条提出 → 有效 6 条 → 待办 1 条**，两处文档现已一致。

---

## C1-4 `-- --test` 的作用范围收窄

- **修订前结论**：DC-03 以"回归命令缺 `-- --test`，照抄会得到'假失败'"为题，建议给 `save_store_test.gd` 与 `table_checkpoint_test.gd` **两条**都加上 `-- --test`，理由统一写成"漏掉会让所有经 `main.tscn` 的交互断言假失败"。读起来像是"所有测试都必需"。
- **新证据（按"是否实例化 `main.tscn`"分类）**：
  - 实例化 `main.tscn` 的测试共 **19 个**（`grep -rl "main.tscn" Godot/three_d/tests/`；C1 时为 18 个，`9dd7848` 新增了 `playtest_seed_test`）：`four_tables_test / venue_transfer_test / capture / scene_rules_test / smoke / opponent_pool_test / capture_table / routes_items_test / search_events_test / two_tables / art_integration_test / room_pool_test / characters_test / spatial_interaction_test / services_save_test / world_restore_atomic_test / table_integration / run_variants_test / playtest_seed_test`。`Godot/three_d/tests/*.gd` 总数现为 **53**。
  - **`save_store_test.gd` 不在其中**：它用 `user://checkpoint-test-<pid>.save` 做隔离（`save_store_test.gd:11`），属纯文件/规则测试 → **漏 `--test` 也不会失败**。原句把它与 `table_checkpoint_test.gd` 并列要求，理由不适用于它。
  - **新的、更强的理由**：`world.gd:99-104`（旧基线 `:94-99`）—— **不带 `--test` 启动 `main.tscn` 会 `load_checkpoint()`（`:104`）**，并在失焦（`:599-600`）与退出请求（`:594-597`）时写回。自动化测试忘了带 `--test`，最坏情况是**读到并覆盖玩家真实存档**。
- **修订后结论**：DC-03 重写，明确三条：
  1. **`-- --test` 是世界交互测试的标准命令**（判据：是否实例化 `main.tscn`），并列出这 19 个文件。
  2. **纯规则测试不需要该参数，缺了也不会失败**——不得用它当"测试好坏"的标准。
  3. **两条理由的次序调换**：把"不碰玩家真实存档（数据安全）"放在**前面**，"假失败"放后面。
  - 建议替换文本同步改写，并加一句「不要用它作为判断测试好坏的标准」。
  - 保留 DC-03 为**仍待处理**（`checkpoint-progress.md:14` 尚未修改）。

---

## C1-5 walkthrough 的整局起点与"单桌 ≠ 正常局"

- **修订前结论**：
  - 附注 1：「第 **10** 步记 `T_start`……**一局总时长 = `T_extract − T_start`**，目标 20–30 分钟（gate 6）」。即把整局起点算在**首桌开始**。
  - 单桌安全路线与正常局混在一段里，只用一句"通常短于完整局"带过。
- **新证据**：`run.gd:51-63 start()` 在**确认出发**时就完成了金库扣款（`:61 bankroll = mini(standardBankroll, vault)`、`:62 vault -= bankroll`）并把场景切到酒馆；时间与金钱的"局"从这一刻开始，首桌只是局内的一步。
- **修订后结论**：
  - 附注 1 重写为**四个时刻表**：`T_start` = **第 4 步（确认出发）**、`T_table_start` = 第 10 步（**另记一栏**）、`T_hand_end` = 第 13 步、`T_extract` = **第 16 步（撤离完成）**。
  - 新增"必须把两类局分开"表：**单桌安全路线 ✅覆盖 / ❌不能用于 gate 6**；**正常局 ❌未覆盖 / ✅用它计时**。并写明"不要用单桌路线的耗时直接判断 20–30 分钟门槛"。
  - 第 4 步的"玩家动作"栏直接写入「**记下开始时刻 `T_start`**」，A 段表格下方加一行"整局时间口径"提示。

---

## C1-6 本金与计费公式

- **修订前结论**：第 3 步写「应为 300，或**金库不足 1200** 时的实际余额」→ 会把"下限 120、上限 300"误读成"金库不到 1200 就带不满 300"。第 15 步只写「与"现金 × 费率 + 平费"一致」，**没写取整与条件**。
- **新证据（代码级）**：
  - 本金：`run.gd:61 bankroll = mini(int(content.standardBankroll), vault)`，`content.standardBankroll = 300`；出发门槛是 `run.gd:52` 的 `vault < 120`。所以实际是 **`min(300, 金库)`，且金库必须 ≥120**：金库 ≥300 带 300；300 > 金库 ≥ 120 带全部金库；金库 <120 直接拒绝出发。**与 1200 无关**（1200 是 `startingVault`，初始金库）。
  - 手续费：`routes.gd:11`
    `fee = 平费 + floor(现金 × 费率) + (风声 == 5 ? 封锁附加 : 0)`
    —— `floor` 为**向下取整**；封锁附加**只在风声恰好等于 5 时加**；风声 ≥6 普通出口直接封锁，不出报价（`routes.gd:14-15`）。
  - 到账：`routes.gd:51 net = maxi(0, 现金 − 费用 − 舍弃现金) + 贵重物价值`（`maxi(0, …)` 是下限截断）。
  - 舍弃现金（仅 `dropbag-cash`）：`routes.gd:37 lost_cash = mini(floor(现金 × 40%), maxi(0, 现金 − 10))`。
- **修订后结论**：
  - 第 3 步改写为**逐档**："金库 ≥300 → 固定带 300；300 > 金库 ≥ 120 → 带全部金库（不足 300）；金库 <120 → 不能出发"，并明确"**不是"金库低于 1200 就带不满 300"**"，同时给出 `run.gd:52` 与 `:61` 的分工。
  - 第 15 步写出**完整公式（含取整与条件）**、`floor` 语义、封锁附加的触发条件、以及舍弃/尾款等其它修正项。
  - 加一句口径纪律：**"以界面上的实际报价为核对主据，公式只用来判断是否算错"**。

---

## C1-7 gate-matrix 的资金守恒改为闭合边界

- **修订前结论**：门槛 1 的"通过条件"写成 **`金库变化 + 随身变化 + 损失 = 0`**，是一条**无条件等式**。
- **新证据**：玩家侧财富有**六个载体**，且这个等式漏了其中三个：
  - `run.vault`（金库）、`run.cash`（随身）——原式有；
  - **`table.state.players[0].stack`（桌上筹码）**——买入后、离桌前，钱不在 `cash` 里；
  - **`table.state.pot`（未分配底池）**——`finish_hand()` 之后、下一次 `start_hand()` 之前 **pot 尚未清零**，这是最易漏算的一处；
  - **`run.valuable_total()`（物品价值）**、**`run.collateral`（抵押托管，是转移不是销毁）**。
  另外还有两类**非玩家侧**流动与两类显式收支，不能并入玩家侧等式要求为 0：**对手转移**、**奖励**（显式来源）、**费用**（汇）、**舍弃**（汇）。
  `state-machine.md` §守恒等式 早已给出**逐阶段**的正确写法；`venue_transfer_test.gd:69 / :75` 用的 `night.vault + night.cash + night.valuable_total() == expected_total` **只在"不在手牌中、也没有抵押"的检查点成立**。
- **修订后结论**：
  - 门槛 1 的通过条件改为「以 `state-machine.md` §守恒等式 的**分阶段闭合式**为准……在每个**阶段边界**上等式差额均为 0」，并在"证据局限"里加第 ④ 条点明 `venue_transfer_test` 的等式**只在牌桌之间/撤离之后成立**。
  - **新增 §一之二「资金守恒的闭合边界」**：给出六载体表、四类来源/汇项、逐阶段闭合式表、以及 `venue_transfer_test.gd:69/:75` 的前提说明。
  - 加一条纪律：宣布"资金守恒通过"必须同时给出 **① 阶段边界 ② 等式全文（含六载体与来源/汇项）③ 该检查点是否在牌桌/抵押中**。
  - §五 第 3 项（端到端守恒动作）的通过条件同步改为"按 §一之二 的闭合边界……差额为 0"。

---

## C1-8 真人口径与建议协议

- **修订前结论**：
  - 门槛 5 的局限写「**没有任何真人数据**」；§四 第 1 项写「真人试玩：**0 人次**。Phase 4 要求的 5 位外部玩家首局通关尚未发生。」
  - 门槛 5/6 的"下一步"直接给人数（"两位新手 + 两位老手""5 局"），读起来像**已确认门槛**。
- **新证据**：本轮确实没有组织试玩、没有记录表、没有截图；但**没有本轮记录 ≠ 此前从未发生**。把写法定成"0 人次""没有任何数据"，等于**否认了用户此前已发生的试玩**，既不准确也会在复验时被推翻。
- **修订后结论**：
  - 门槛 5 的局限改为「**本轮没有正式记录可供验收**（不是"从来没有真人玩过"）」；§四 第 1 项同样改为「**本轮没有正式记录可供验收**……**这不等于"从来没有真人玩过"**」。
  - `README.md` 开头与 §二 P1-B 行的"0 人次 / 0"改为"**本轮 0 条正式记录**"。
  - 门槛 5/6 的下一步与 §五 第 5/6 项统一标注为「**建议**协议，不是已确认门槛」，并指向新增的 `real-player-protocol.md`。
  - 通用限制新增第 5 条：「**"本轮没有正式记录" ≠ "从未发生"**」。
  - **新增 `real-player-protocol.md`（一页待执行协议）**：参与者分类（建议 3 新 + 2 老，至少 1 对同种子同路径）、相同种子/路径设置表、决策差异计数四项指标（决策机会数 / 实际动作数 / 选项分歧数 / 差异值-**口径待定**）、正常局起止时间表、记录表填写示例。**所有示例都显式标注"（示例）"，并与真人数据分开**；末节给出"本轮状态：未执行 / 正式记录 0 条 / 可核对截图 0 张"。
- **统一冲突条数**：见 C1-3 末尾的口径表（7 提出 / 6 有效 / 1 待办），`README.md` 与 `doc-corrections.md` 已一致。

---

## 链接可打开性自检

主 Agent 要求"所有相对文件链接须验证能从文档所在目录打开"。本轮为此写了脚本 `output/external-handoff/C1/verify_links.py`（可重跑）：

**先把约定写清楚**（写进 `README.md` §六）：

| 引用形式 | 解析基准 |
|---|---|
| Markdown 链接 `[文本](目标)` | **相对文档所在目录**（必须可直接打开） |
| 反引号里的文件路径 | **相对项目根目录** |

**自检发现并修掉的两类断链：**

1. **相对 `docs/3d-production/` 的简写被当成通用路径**：初版误写为 phase-1/state-machine.md、phase-1/difficulty-curve.md、phase-1/seeded-pools.md、phase-1/opponent-profiles.md、phase-1/first-run-walkthrough.md（含 ../phase-1/first-run-walkthrough.md 形式）、phase-1/coverage/README.md、phase-1/coverage/transitions.json、tests/raise_preview_test.gd 等几类简写 —— 已统一改写为**相对项目根**的完整路径（如 `docs/3d-production/phase-1/coverage/README.md`、`Godot/three_d/tests/raise_preview_test.gd`）。**重跑检测：本目录交付物中已无残留简写**；唯一剩下 1 处在主 Agent 自己的 `主Agent验收与返修任务-2026-09-21.md`（行文为 phase-1/production-gates.md），不在本次交付范围，**未改动**，仅在此报备。
   > 注：上面这些"误写形式"**刻意不加反引号**——它们不是引用，若加反引号会被自检脚本按"仓库根相对路径"计数，进而误报为断链。
2. **Markdown 链接指向不存在的位置**：`doc-corrections.md` 里引用 `difficulty-curve.md` 原文时保留了 `[一晚跨酒馆](cross-venue-evening.md)`，该链接**相对 `difficulty-curve.md`** 才成立，从 `C-acceptance/` 打开必断。已改为纯文本《一晚跨酒馆》并注明原目标与基准，**保持引用不失真**。

**判定标准（与条数无关，就看这两行）**：

```
✅ 全部 Markdown 链接均可从文档所在目录打开
✅ 无两级解析都失败的引用
```

**快照（2026-09-22 重跑的原样输出；**条数行刻意省略**，因为它每次编辑都会变，不构成验收指标）**：

```
检查目录： ['docs/3d-production/external-handoff/C-acceptance', 'docs/3d-production/external-handoff/B-content-assets']
Markdown 链接：0 条（文档相对可解析 0，不可解析 0）
✅ 全部 Markdown 链接均可从文档所在目录打开
✅ 无两级解析都失败的引用
结论：所有引用均可打开
```

> 为什么要把条数降级为"快照"：本轮从写第一版到审查结束，反引号条数走过了 65 → 66 → 54 → 56 → 59 → 60——**每次编辑文档都会变**。把它当验收数字会被自己坑，所以本轮明确**只认"0 条断链"**。

**一条写作约束（本轮踩过）**：自检脚本会**刻意跳过**两类非引用文本——反引号里的"链接写法示例"、含空格的命令行。因此**描述"错误写法"的反例不能再加反引号**，否则会被计成断链（本轮一度被自己的反例制造出 11 条假断链）。两处文档已按此改。

---

## 需要主 Agent 决定 / 后续

> **⏱ 本节是 C1 轮（`413dce9` 时期）的历史快照，不是当前总状态。** 主 Agent 在复验后已答复其中第 1、2 条，C2 轮据此落地——**最新状态一律以 `C2-corrections.md` 与 `real-player-protocol.md` 为准**，本节只保留「当时留了什么」以备追溯。

1. ~~**"决策差异"的可计数口径**：门槛用**分歧次数**还是**分歧率**？~~ **已于 C2 关闭**：主 Agent 定死为**实际决策事件数绝对差 `abs(N_new − N_experienced) > 3`**（分歧只作辅指标）。见 `C2-corrections.md` C2-1、`real-player-protocol.md` §3.1。
2. **样本量与"5 局"是否升级为门槛**：当时的 3 新 + 2 老、5 局中位数都是**建议协议**。**C2 仍维持"建议协议"**，未升级为门槛。
3. **DC-03 是否照建议文本改**（`checkpoint-progress.md:14`）——本轮未动原文。
4. **DC-05/DC-06 是否接受"加横幅/加括号"的轻量做法**（不改原句）。
5. **门槛 4 的 `pending_families` 引用方式**：是否统一为"引用时必须带日期"（本轮已按此写入）。

---

## 本轮边界声明

- 未修改 `Godot/three_d/rules/`、`scripts/`、任何 `.blend` / `.glb` / 贴图、`src/`。
- 未打开游戏、未组织试玩、未计时、未做性能测试、未读写玩家真实存档。
- 未修改任何**被引用**的项目文档（`difficulty-curve.md` / `seeded-pools.md` / `checkpoint-progress.md` / `design-baseline.md` / `implementation-progress.md` / `docs/3d-production/phase-1/coverage/README.md` 全部原样保留）。
- 未 commit / push。
- 本目录 `README.md` 与 `doc-corrections.md` 的**冲突条数**已统一为"7 提出 / 6 有效 / 1 待办"。
