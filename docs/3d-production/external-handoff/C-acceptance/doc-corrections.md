# 文档冲突与替换建议（C1 返修后）

初版执行日期：2026-09-21（基线 `b158491`）。**返修日期：2026-09-22（基线 `413dce9`）。**

**规则：本文件只列有证据的冲突，并给出原位置、当前代码证据、建议替换文本。原文档一个字都没有被改动**（DC-01/DC-02 的两处已由**主 Agent** 自行修正，见下）。

**路径约定**（与 `README.md` §六 一致）：Markdown 链接相对**文档所在目录**；反引号里的文件路径相对**项目根目录** `~/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/`。可重跑自检：`output/external-handoff/C1/verify_links.py`。

**版本与行号（C2 二次修订后）**：原 C 交付基于 `b158491`；C1 返修按 `413dce9` 取行号；**C2 二次修订已把 `world.gd` 的行号全部换到当前 HEAD `8382b7b`**（`9dd7848` 新增固定种子入口后 `world.gd` 由 1008 行变为 1028 行，偏移 +20）。跨版本对照：原 `world.gd:94-99 → 99-104`、`:580-586 → 598-604`。`run.gd` / `routes.gd` / `table.gd` / `content.json` 的行号**未变**。完整映射表见 `C2-corrections.md`（可重跑 `output/external-handoff/C2/map_world_lines.py`）。

标注方式：

| 标记 | 含义 |
|---|---|
| `[已处理]` | 主 Agent 已按建议（或等价写法）修正原文，本文件保留记录备查 |
| `[撤回]` | 经复核**不构成冲突**，本条从待办中撤回；保留理由以便后人不再重复提 |
| `[待处理]` | 冲突仍存在，替换文本可直接用 |
| `[范围/日期补注]` | 原文在其**当时的范围/日期**下成立，只是缺限定词，不是"写错" |
| `[历史快照提示]` | 同文件内多个数字是**不同批次的快照**，非同时成立的计数冲突 |

## 冲突条数（返修后口径）

| 项 | 数 |
|---|---:|
| 累计提出 | 7 条（DC-01 … DC-07） |
| 主 Agent 已处理 | **3 条**（DC-01、DC-02、DC-03） |
| 已撤回 | **1 条**（DC-04） |
| 仍待处理 | **0 条** |
| 仅需补注（非错误） | **3 条**（DC-05、DC-06、DC-07） |

> **一致性说明**：C 目录 `README.md` 初版写"6 处文档冲突"，与本文件的 7 条不符；DC-04 撤回后**有效条数恰为 6**。返修后 README 与本文件统一按上表表述。

---

## DC-01 `[已处理]` 跨酒馆已接通，但难度曲线仍写"尚未接通"

- **原位置**：`docs/3d-production/phase-1/difficulty-curve.md:26`
  原文：`- 当前一局只在一酒馆；"一晚几个酒馆"尚未接通，几酒馆难度曲线不能编造。有限池版本须明确跨酒馆转移、费用、行动力、路线清理与解锁规则。`
- **当时反证**：同文件 `:36`（2026-09-14 追加）已写"跨酒馆已使用整晚四桌共享进度接入"，并指向 `cross-venue-evening.md`。
- **当前代码证据**：
  - `Godot/three_d/rules/run.gd:88-98 transfer_quote()`：出口费 + 15 车费 + 1 行动力，校验本晚未去过、已完成本店 ≥1 桌、还有未完成桌、现金与行动力。
  - `Godot/three_d/rules/run.gd:100-128 transfer_venue()`：写 `venue_history` / `arrival_completed` / `transfer_log`，清 `public_exit`、`route_flags`、`reservation`。
- **处理结果（2026-09-22 复核）**：**主 Agent 已修正**。`difficulty-curve.md` 现文（"尚未完成的节奏验收"小节）已改为：
  > - 跨酒馆首版已接通，转移费用、行动力、路线清理与解锁规则见《一晚跨酒馆》。访问顺序与多店经济压力尚未完成难度采样，不能据此宣布平衡通过。

  （原文里的相对链接目标是 `cross-venue-evening.md`，**相对于 `difficulty-curve.md` 所在目录**；本文件是引用而非原始位置，故此处不再渲染成链接，以免从 `C-acceptance/` 打开时指向不存在的路径。）
  
  并且保留了"不能编造几酒馆难度曲线"的实质约束（写成"尚未完成难度采样"）。**本条不再需要外部动作。**

---

## DC-02 `[已处理]` 种子池文件开头仍写"跨酒馆流转待实现"

- **原位置**：`docs/3d-production/phase-1/seeded-pools.md:3`
  原文：`2026-09-13。已实现每局固定货架计划、初始预约接应方案和四桌发牌种子；跨酒馆流转仍待实现，不计作 Roguelike 最小版完成。`
- **当时反证**：`:41` 已写"2026-09-14：跨酒馆首版已接入……"。
- **处理结果（2026-09-22 复核）**：**主 Agent 已按建议原文修正**。`seeded-pools.md:3` 现文：
  > 2026-09-13（2026-09-21 校订）。已实现每局固定货架计划、初始预约接应方案和四桌发牌种子；跨酒馆流转已于 2026-09-14 接入首版（见文末及 cross-venue-evening.md），全面组合与真人节奏验证仍待完成。
  
  **本条不再需要外部动作。**

---

## DC-03 `[已处理]` 回归命令缺 `-- --test`（作用范围已按契约收窄）

- **原位置**：`docs/3d-production/checkpoint-progress.md:14`
  原文（2026-09-22 复核仍未改）：
  > 运行：在项目根目录执行 Godot 的 --headless --path Godot --script 参数，分别指定 res://three_d/tests/save_store_test.gd 和 res://three_d/tests/table_checkpoint_test.gd。
- **同类对比**：`docs/3d-production/phase-1/coverage/README.md` 给多条 `Godot --headless --path Godot --script ... -- --test` 已经**带**了 `-- --test`（正确示范）。

### 作用范围（本轮回修的关键）

**`-- --test` 是世界交互测试的标准命令，不是所有测试的必需参数。** 判据是"该测试是否实例化 `main.tscn`"：

- **需要 `-- --test`**：`Godot/three_d/tests/` 下**实例化 `main.tscn` 的 19 个文件**——`four_tables_test / venue_transfer_test / capture / scene_rules_test / smoke / opponent_pool_test / capture_table / routes_items_test / search_events_test / two_tables / art_integration_test / room_pool_test / characters_test / spatial_interaction_test / services_save_test / world_restore_atomic_test / table_integration / run_variants_test / **playtest_seed_test**`（末一个是 `9dd7848` 新增的固定种子入口测试，`playtest_seed_test.gd:10` 直接 `load("res://three_d/scenes/main.tscn").instantiate()`）。`Godot/three_d/tests/*.gd` 总数现为 **53**。
- **不需要 `-- --test`**：只直接构造 `Table` / `Run` / `Checkpoint` 等规则对象的**纯规则测试**（例如 `poker_test`、`table_test`、`payout_coverage_test`、`run_restore_bounds_test`）。**它们缺该参数不会失败**，不加也不影响结论。
- **`save_store_test.gd` 属后者**：它用 `user://checkpoint-test-<pid>.save` 做隔离（`save_store_test.gd:11`），不实例化 `main.tscn`，因此原句把它与 `table_checkpoint_test.gd` 并列要求 `-- --test`，**理由不适用于它**（加上无害，但不能说"漏了就假失败"）。

### 两条理由（比"假失败"更重要的一条是数据安全）

**理由 1 · 假失败（交互类）**：`Godot/three_d/scripts/world.gd:598-604`（**行号基线：当前 HEAD `8382b7b`**；旧基线 `413dce9` 为 `:580-586`，漂移见 `C2-corrections.md`）

```gdscript
if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and readiness and not run_panel.visible and not OS.get_cmdline_user_args().has("--test"):
    if saving_enabled:
        save_checkpoint()
    if services_panel.visible:
        close_services()
    if not paused:
        pause_game()
```

无渲染的 headless 运行会触发 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` → `pause_game()`（`:604`）→ `paused = true`、`player.controls_enabled = false`、`run_panel` 保持可见。**经过 `main.tscn` 的物理/UI 交互断言**因此会假失败（纯规则断言不受影响）。

**理由 2 · 不碰玩家真实存档（数据安全）**：`world.gd:99-104`（旧基线 `:94-99`）

```gdscript
if not OS.get_cmdline_user_args().has("--test"):
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
readiness = true
if not OS.get_cmdline_user_args().has("--test"):
    get_tree().auto_accept_quit = false
    if playtest_seed == 0: load_checkpoint()
if playtest_seed > 0:
    save_notice.text = "对照试玩 · 编号 %d · 本次不读写正式存档" % playtest_seed
```

即**不带 `--test` 启动 `main.tscn` 会加载真实存档**（`:104`，且自 `9dd7848` 起已加 `playtest_seed == 0` 前置条件——固定种子模式下即使漏掉 `--test` 也不读存档），并在失焦时（`:599-600`）与退出请求时（`:594-597`）写回。自动化测试若忘了带 `--test`，最坏情况是**读到并覆盖玩家的真实存档**。这是"世界交互测试必须带 `--test`"的首要理由，比"断言假失败"更该写在前面。

- **本轮实测证据**（沿用 A 轮）：
  - 不带 `--test`：`routes_items_test` 54 项中 3 项失败（`Special route entrance reachable by actual ray` 等）；`venue_transfer_test` 923 项中 2 项失败。
  - 带 `--test`：两者全部通过（见 `../A-regression/test-results.csv`）。
  - 诊断输出 `output/external-handoff/A/repro/diag_route_ray.gd`：不带时射线其实**命中**锚点（1.15 m，在 `REACH=2.0` 内），但 `paused=true`、`run_panel_visible=true`、`controls_enabled=false` → `request_action=false`；带时 `paused=false` / `controls_enabled=true` → `request_action=true`。
- **建议替换文本**（替换 `checkpoint-progress.md:14`）：

  > 运行方式：在项目根目录执行
  > `Godot 可执行文件 --headless --path Godot --script res://three_d/tests/save_store_test.gd -- --test`
  > 与
  > `Godot 可执行文件 --headless --path Godot --script res://three_d/tests/table_checkpoint_test.gd -- --test`。
  >
  > **`-- --test` 是世界交互测试的标准命令**：凡实例化 `main.tscn` 的测试，漏掉它会有两个后果——① `world.gd:598-604` 在窗口失焦时自动 `pause_game()`，使**经过 `main.tscn` 的交互断言假失败**；② `world.gd:102-104` 会**加载真实存档**并在 `:594-597`（关窗请求）与 `:599-600`（失焦）写回，可能动到玩家数据。
  > **纯规则测试（只构造 Table/Run/Checkpoint，不经 `main.tscn`）不需要该参数**，漏掉也不会失败，不要用它作为判断测试好坏的标准。

- **处理结果（2026-09-24）**：`checkpoint-progress.md` 已补上两条可复制命令，并说明两者为纯规则/文件测试，`-- --test` 并非必需；另明确实例化 `main.tscn` 的测试必须带该参数，以隔离正式存档。

---

## DC-04 `[撤回]` 原"待办项在文档里有、在机器可读目录里没有"

- **撤回日期**：2026-09-22。**主 Agent 判定本条不成立**，本条从待办中撤回。
- **原主张**：`docs/3d-production/phase-1/coverage/README.md` 提到 `showdown_winner_allocation` 继续待办，但 `transitions.json` 的 `pending_families` 里没有它 → 建议"补进目录"或"改文档"。
- **撤回理由（两条独立证据）**：
  1. **`pending_families` 从来没有 `showdown_winner_allocation`**（2026-09-22 复核：只有 `poker` / `world` / `persistence` 三族）。它出现在 README 的**实现批次叙述**里，本来就不是族名，"补进 `pending_families`"这个建议本身分类错了。
  2. **胜者与边池分配已有独立金额预期**：`docs/3d-production/phase-1/coverage/README.md` 的「胜者与边池独立金额预期（2026-09-14）」小节（当前 `:132-134`）已登记 `payout.*` **六种结果**——单一胜者、三层贡献、最强牌已弃牌、三人公共牌平分、各层边池平分、平分余数；且**预期金额直接写进测试，不调用同一个 evaluator 生成答案**。
- **连带修正**：`gate-matrix.md` 里"`pending_families` 仍明确保留 …… `showdown_winner_allocation` ……"这句描述**已删除**（它同时错在两处：`signal_analysis` 已于后续批次移出、`showdown_winner_allocation` 从未在内）。
- **保留的真实局限**：`payout` 的六个用例固定了河牌夹具，**不穷尽全部牌型与下注路径**。这一条仍成立，已写进 `gate-matrix.md` §四 第 8 项。
- **⚠️ 二次修订（2026-09-22 晚，按主 Agent《复验与任务续接》"对新审查报告的限定"）**：
  前一轮对抗性复查把 `coverage/README.md:130` 那句**旧批次待办句**当成了"**当前总状态**"，结论过强。主 Agent 已**在原覆盖文档给该句补上历史限定**，现在的现文（`:130`，属前一小节「`## 街道推进与下一手（2026-09-14）`」）是：
  > 摊牌测试比较实际 awards 与筹码增量并验证总额，不用它证明胜者分配正确；`showdown_winner_allocation` **在本批次仍待办（历史状态；随后 payout 小节新增六种独立预期，不代表所有牌型组合已穷尽）**。单挑下一手、牌桌彻底结束后禁止下一手也另列待办。

  据此把口径定死为**三点，不许再往外扩**：
  - **撤回成立的**：只撤回"**建议把它补进 `pending_families`**"这个**分类错误**（该数组实测只有 `poker` / `world` / `persistence` 三族，从未含它）。**不重开已经枚举的同名待办**。
  - **不要读成"完全没验胜者"**：`payout` 六例**直接使用已知牌力排序与预期获奖人/金额**，是**实打实的胜者分配验证**。
  - **也不要读成"所有牌型比较都通过"**：六例用的是固定河牌夹具，**不代表全部牌型与下注路径已穷尽**。真实边界就在这两句话**之间**。
  - `README.md` 提到的"226 个已登记结果"与这句同属**历史批次数值**，同样按快照读，不要当当前计数。

---

## DC-05 `[范围/日期补注]` 设计基线只描述了 2 张牌桌，且称不支持 all-in / 边池 / 平分

- **原位置**：`design-baseline.md:226`、`design-baseline.md:287-290`
  原文（逐字，2026-09-22 复核未改）：
  - `:226` `- Cargo Table and Mirror Hall are the current demo rooms`
  - `:227` `- They should be treated as authored room templates, not proof that the final game only contains two fixed tables`
  - `:287` `- Vertical slice does not support:`
  - `:288` `  - all-in actions`
  - `:289` `  - side pots`
  - `:290` `  - split pots beyond a simple tied showdown`
- **范围补注（本轮回修要点）**：这不是"当时写错了"。`design-baseline.md` 描述的是**网页版 Vertical Slice 阶段的范围**，而且 `:227` **自己就写明**"当前两张桌是模板，不证明最终只有两张固定牌桌"。所以它与 Godot 迁移后的现状**不冲突**，缺的只是**文件级别的范围/日期限定词**。
- **现状参考（Godot 侧，仅作时代对照，不构成对原文件的否定）**：
  - 四张牌桌：`content.json` 的 `cargo-table / ledger-cellar / mirror-hall / embers-table`。
  - all-in 已实现：`table.gd` 的 `legal_actions` / `act` 支持 `all-in`。
  - 边池与平分：`poker_test.gd:44`「Short-stack winner cannot take side pot」；`payout_coverage_test.gd` 的 `tied_side_pots`、`settlement_coverage_test.gd:28` 的 `side_pot_only`；`coverage/README.md:132-134` 的 payout 六种独立金额预期。
- **建议做法**（不改原句，只在文件开头加一行状态横幅）：

  > ℹ️ **范围说明**：本文件是**网页版 Vertical Slice 阶段**的设计基线（该阶段范围）。项目已于其后迁移到 Godot 4.7 实现，当前权威内容定义见 `Godot/three_d/rules/content.json`（4 张牌桌）。文中 `:287-290` 的"不支持清单"描述的是**该阶段范围**，其中 all-in / side pots / split pots 三项在 Godot 侧已实现并有测试覆盖，**不代表本文写作时写错**；`:227` 也已预先声明"两张桌是模板"。

---

## DC-06 `[范围/日期补注]` 实施记录仍把外部协作范围限定为 `inventory/`

- **原位置**：`docs/3d-production/implementation-progress.md:3`
  原文（2026-09-22 复核未改）：`更新：2026-09-08。主 Agent 负责代码、规则、建模与集成；外部协作 Agent 仅负责 inventory/ 下的资料清单。本记录不修改协作 Agent 的交付。`
- **范围补注（本轮回修要点）**：这句话在 **2026-09-08** 写作时**是正确的分工边界**；第二轮外部协作（`external-handoff/{A-regression,A2-boundaries,B-content-assets,C-acceptance}/`）是**之后**才开的，属于历史演进，**不是"当时写错"**。缺的只是日期/轮次限定词。
- **建议做法**（只在日期后补一个括号，不改原句）：

  > 更新：2026-09-08（2026-09-21 补注）。主 Agent 负责代码、规则、建模与集成。外部协作分两轮：第一轮为 `inventory/` 资料清单（即本句所描述的范围）；第二轮为 `external-handoff/{A-regression,A2-boundaries,B-content-assets,C-acceptance}/`，任务书见 `docs/3d-production/并行开发分工.md`。本记录不修改协作 Agent 的交付。

---

## DC-07 `[历史快照提示]` 同一份覆盖说明里，登记结果数前后不一致（226 → 232 → 239 → 247 → 252）

- **原位置**：`docs/3d-production/phase-1/coverage/README.md`
  - 初版 `:128`（现 `:130`）含 `226 个`已登记结果具备当前证据，并写"十二个原覆盖套件"。
  - 初版 `:146`（现 `:148`）含 `239 个`登记结果证据有效，并写"十五个覆盖套件"。
- **本轮回修要点（由"冲突"改为"历史快照"）**：
  这些数字**不是同时成立的当前计数冲突，而是实现批次的演进序列**：`226`（poker_progress 批次）→ `232`（payout 批次）→ `239`（transfer/endgame 批次）→ `247` → **`252`**（signal_analysis 拆入目录后，当前值）。同理"十二个 / 十五个覆盖套件"也是当时的套件数，当前为 **17 个**（`Godot/three_d/tests/collect_coverage.py` 的 `SUITES` 字典实数）。
- **处理结果（2026-09-22 复核）**：**主 Agent 已在文件开头加阅读口径横幅**（当前 `:3`）：
  > 阅读口径（2026-09-21）：下文按实现批次保留历史快照，226、232、239、247、252 等数字各对应当时状态。最新登记数为 252，全局目录仍未完成，整体覆盖率为空。胜者与边池分配已有下文 payout 六种结果的独立金额测试；这不代表穷尽所有牌型和下注路径。
  
  **历史叙述一律保留**（这正是可追溯的实现记录），只需"当前状态指向最新汇总"。**本条不再需要外部动作**；本文件保留它，是为了让后续读者知道"看到 226 不要以为当前是 226"。
- **当前权威值（2026-09-22，基线 `413dce9`）**：`transitions.json` 的 `status = incomplete_catalog`，`transitions` 条目 **252** 条，`pending_families` **3 族**（`poker` / `world` / `persistence`）；`overall_state_transition_coverage` 仍为 `null`。

---

## 未发现冲突的部分（已核对，供后续引用）

以下内容本轮对照过代码，**一致**，不需要修改：

| 文档 | 声明 | 核对结果 |
|---|---|---|
| `docs/3d-production/phase-1/coverage/README.md` 开头阅读口径（`:3`） | "最新登记数为 252……胜者与边池分配已有 payout 六种结果的独立金额测试" | **一致**：`transitions.json` 实为 252 条；「胜者与边池独立金额预期」小节存在 |
| `docs/3d-production/phase-1/coverage/README.md` | `overall_state_transition_coverage` 为 `null`、`status=incomplete_catalog` | `transitions.json` 首行即 `status: incomplete_catalog`；`collect_coverage.py` 输出 `'overall_state_transition_coverage': None` |
| `cross-venue-evening.md` §转场的明确代价 | 出口费 + 15 车费 + 1 行动力、预约不退、特殊路线不可接续 | 与 `run.gd:88-128` 逐条一致 |
| `difficulty-curve.md` 桌序表 | 买入 60/90/120/160、盲注 10/20、15/30、20/40、25/50、手数 2/2/3/3 | 与 `content.json` 的 `tables` 完全一致 |
| `difficulty-curve.md` 酒馆表 | 四店普通费率与预约宽限轮数 | 与 `content.json` 的 `scenes` 一致（烟雾 24+12%/2、高层 42+18%/3、屋顶 28+13%/1、霓虹 34+14%/2） |
| `first-run-walkthrough.md:5` | "双击 `Godot/three_d/启动3D原型.command`" | 文件存在（可执行位已设） |
| `phase-1/production-gates.md:9` | "进行中；没有任何整体通过声明" | 与文件现文一致，未被本轮任何交付推翻 |
| `docs/3d-production/phase-1/state-machine.md` §守恒等式 | 分阶段等式（出发/入桌/单手/离桌/商店搜索/成功撤离/失败） | 与 `routes.gd` / `run.gd` / `table.gd` 一致；**这是 gate-matrix 资金守恒口应该引用的权威段落** |
