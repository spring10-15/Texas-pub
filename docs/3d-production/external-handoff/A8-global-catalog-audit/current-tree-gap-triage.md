# A8 当前树可达缺口逐行核验（triage）

> 本文件与 `current-tree-gap-triage.csv` 是 A8 `current-tree-player-path-gaps.csv`（30 行候选）的逐行核验结果。
> 只读审计：**未修改**任何 Godot 代码、测试、`transitions.json`、正式存档或既有 A8 文件，**未新增语义 ID**。
> 本任务书此前未被执行（开工时 `current-tree-gap-triage.csv` / `.md` 在仓库中均不存在），本文件为首次交付。

## 1. 基线与输入（含核验期间的漂移）

任务书声明基线：HEAD `93e7ed6`、目录 385 项。**核验期间 HEAD / 目录 / 输入 CSV 三者都发生了漂移**，按任务书要求「先记录新值，不改写对账基线」，全部记录如下。

| 时刻 | HEAD | 目录 ID 数 | `transitions.json` SHA-256 | 输入 `current-tree-player-path-gaps.csv` | 备注 |
| --- | --- | --- | --- | --- | --- |
| 本次核验开工 | `8246136` | 385 | `825742e9257602bc7cf5dbe3b66dbb914e95928304a4035f412843d3beee0088` | 31 行，SHA-256 `dbbfd18d6423de9d8e2c14e7b1ef075336dbfd008a9881e65d6c609bfcf0a21e` | 工作树含未提交的 `settlement.heat_relief` |
| 任务书 / 对账记录声明 | `93e7ed685c875cd5d91cc15ecce9d0fb8b797839` | 385 | `825742e9…`（同上） | 30 行，SHA-256 `f6afc40dbc586e78fbbcdf6d57cb027f843ef61642d90dac27fd2c8f6822d0f1` | 上游 11:33:43 改写输入与对账并提交 `93e7ed6` |
| **交付物生成时（本次结论所依据的值）** | `93e7ed685c875cd5d91cc15ecce9d0fb8b797839` | **386** | `5a87300ddea8a3ecb03a883e7973bcf930b87312cfc124faa71a08d83b2d5187` | 30 行，SHA-256 `f6afc40dbc586e78fbbcdf6d57cb027f843ef61642d90dac27fd2c8f6822d0f1` | 上游 11:36:40 在工作树追加 `poker.player_raise_pattern`（未提交） |

**漂移 1 — 输入 CSV 31 行 → 30 行。** 上游于 11:33:43 改写输入与对账记录，被移除的唯一一行是 `Godot/three_d/rules/run.gd:205`（`settle_table` 的「胜利热缓释 heat = max(0, heat - winHeatRelief)」）。该行在核验开工版中的正确处置正是「已有目录 ID 承接」——新 ID `settlement.heat_relief` 已入目录（对账记录第 16 行亦明写此归因）。**上游的移除与我的判定互为独立印证**，两者都指向同一结论：该行不构成新增 ID 候选，故不出现在交付表中。本文件保留此记录，不改写上游对账基线。

**漂移 2 — 目录 385 项 → 386 项。** 上游于 11:36:40 在工作树追加 `poker.player_raise_pattern`（`Godot/three_d/rules/table.gd` / `act` / outcome = `accepted updates player raise profile for raise/all-in, not opponent actions`）。该 ID 的语义正中本表 **Row 7（`table.gd:119-120`：`playerPattern.raiseCount` 仅对 `id == "player"` 累加）**，故 Row 7 的归属已直接改记为该 ID。除此之外 386 项与 385 项的差集仅此一项，其余 29 行的判定不受影响。

**后续状态补记（2026-09-25）**：主线为搜索锚点与货架锚点补充了真实射线交互测试，两个模式复用 `world.services_open`，不新增目录 ID；测试和完整回归通过。当前目录为 386 项，当前树对账仍有 27 条可达无 ID 候选、18 条弱证据项。此补记更新现况，不改写本表在原始 30 行输入上的逐行审计结论。

- 输入行数：**30**（以核验期间实际 CSV 为准；任务书第 10 行亦已同步为 30 行）
- 输入 CSV SHA-256：`f6afc40dbc586e78fbbcdf6d57cb027f843ef61642d90dac27fd2c8f6822d0f1`
- 目录：386 个唯一 ID，SHA-256 `5a87300ddea8a3ecb03a883e7973bcf930b87312cfc124faa71a08d83b2d5187`
- 被核验的 5 个源文件 SHA-256（开工与交付生成时一致，未改动）：
  - `Godot/three_d/rules/run.gd` — `f6d61934d399eea05728c7f81780744ae8594a23afed8ca4e31a64cb8ffd0308`
  - `Godot/three_d/rules/run_variants.gd` — `a65634653c6c59dd29d85721408af477f5d0958990948d616ec7303bc4cae623`
  - `Godot/three_d/rules/table.gd` — `d248b457389321750dab5366c13da7b6ce346f933516ea2fd0dd6b3aed56217e`
  - `Godot/three_d/scripts/player.gd` — `59c5b988f3305adeac4c90c52ab4311182b760407b1b78422f1a17302dff2882`
  - `Godot/three_d/scripts/world.gd` — `c033e6ea27543499fb2b06a50534dd89f97f457e10178e09763774d0a639265c`

注：原始 A8 的 382 项审计是**已冻结的历史锚点**，本文件的任何结论都不以它为依据；本结论只依据上表中的 386 项目录与上列源文件哈希。

## 2. 分类计数

| 分类 | 行数 |
| --- | --- |
| `confirmed_distinct_gap` | 7 |
| `existing_id_needs_evidence` | 11 |
| `same_outcome_merge` | 12 |
| `not_state_transition` | 0 |
| `not_player_reachable` | 0 |
| `unknown` | 0 |
| 合计 | 30 |

建议动作对应关系（`recommended_action` 列）：`new_id_candidate` 7 行 / `map_to_existing_add_test` 11 行 / `merge_no_new_id` 12 行。

### 为什么 `not_state_transition` / `not_player_reachable` / `unknown` 都是 0

不是「没查」，是三者都能被逐行排除：

- **`not_player_reachable` = 0**：输入表是上游从 16 个源码文件的 667 条分支里预筛过的「玩家可达且尚无 ID」子集（对账记录：`unreachable_or_not_transition` 140 条已被剔除）。我对每行都独立走了一遍触发链并写进 `reachability_evidence` 列，没有一行的前置只能靠篡改内部状态构造。**特别记录一个可达性口径**：`player.gd` 的鼠标视角（`:45-47`）与交互（`:48-51`）两行要求 `Input.mouse_mode == MOUSE_MODE_CAPTURED`，而该模式只在非 `--test` 时由 `world.gd:101` 设置 —— 因此它们在 headless/`--test` 下不可达、在真实窗口下可达；而 Esc 暂停分支（`:38-42`）**不受**鼠标模式限制，`--test` 下同样可达。这三行的差异已分别写入 CSV。
- **`not_state_transition` = 0**：本目录把「玩家发起的动作被拒」本身计为一种 outcome（`entry.*` 12 条 rejected、`route_guard.*` 24 条、`poker_guard.*` 15 条、`world.*` 拒绝族 15 条）。因此「被拒且无状态改变」不构成本分类；本分类只留给「后继既无权威状态改变、又不是任何已登记拒绝语义的输入用例」的行 —— 逐行核对后没有这样的行（所有拒绝行的原因都能找到既有 ID 归属，见下）。
- **`unknown` = 0**：30 行的触发入口、前置来源与后继状态都能从源码直读并在 CSV 中给出逐行坐标；没有一行只剩「函数有分支」这种弱依据。

## 3. 只有 `confirmed_distinct_gap` 能作为新增 ID 候选（7 行）

| 行 | 源码坐标 | 结果（后继改变什么权威状态） |
| --- | --- | --- |
| Row 3 | `run_variants.gd:36` | 抽取 `variant_plan.room_layout`（`linear`/`fork`）—— 持久化的权威 Run 字段，经 `run.gd:147-149` 决定房间锁拓扑 |
| Row 4 | `table.gd:44-46` | 盲注封顶：`commit` 金额被 `mini(stack, blind)` 限为实际筹码（`:45` 为同语义的大盲实例），筹码/底池按实际额变动 |
| Row 9 | `player.gd:45-47` | 鼠标视角写入 `checkpoint_state()` 的 look / player 字段（含 `camera.rotation.x` 被 clamp 到 ±1.25） |
| Row 12 | `player.gd:56-60` | WASD 移动写入 `checkpoint_state()` 的 player 字段 |
| Row 16 | `world.gd:622-625` | `WM_CLOSE_REQUEST` 生命周期入口：退出前写盘（`save_checkpoint`）后 `quit()` |
| Row 17 | `world.gd:626-632` | `WM_WINDOW_FOCUS_OUT` 生命周期入口：写盘 + 关服务面板 + `pause_game()` 的复合效应 |
| Row 23 | `world.gd:665-669` | 时间驱动的自动存档：`save_clock >= 0.5` 时写盘 |

这 7 行的共性是：**该入口/该结果在 386 项目录里完全没有对应 ID**（CSV 的 `existing_id_check` 以 `no_synonym` 开头，并且 `target` 字段为空）。其中 Row 3/23 我在 `review_notes` 里标注了「备选读数（可降级为并入既有 ID）」，供主 Agent 定夺；Row 4/9/12/16/17 我认为没有合理的归并对象。

**给主 Agent 的一句话**：这 7 行是本次审计唯一的「新增 ID 候选」全集；我没有直接改目录或代码。

## 4. `existing_id_needs_evidence`（11 行）—— 应映射既有 ID 并补断言，不新增 ID

| 行 | 源码坐标 | 归属 ID（`target`） | 缺的是什么 |
| --- | --- | --- | --- |
| Row 5 | `table.gd:47-50` | `poker_progress.next_hand_heads_up`、`poker_progress.next_hand` | 发牌的确定性断言（现只有 `rng.value` 变化、`deck.size()==46` 的间接证据） |
| Row 6 | `table.gd:102-102` | `poker_action.open`、`poker_guard.raise_used` | 「开注后本街仍可加注」的后置断言（属断言缺口，非分支缺口） |
| Row 7 | `table.gd:119-120` | `poker.player_raise_pattern` | 该字段的增量断言 + capture/restore 往返（现只当前置条件用） |
| Row 8 | `player.gd:38-42` | `world.toggle_pause_run_panel` 等 4 条 | Esc 信号绑定链的端到端断言（既有测试均直接调 `world.toggle_pause`） |
| Row 10 | `player.gd:48-51` | `world.raycast_unfocused`、`world.seat`、`world.prop_on`、`world.services_open`、`world.room_graph_entry` | E 键信号链的端到端断言（既有测试均直接调 `world.request_action`） |
| Row 14 | `world.gd:482-484` | `world.services_open` | 世界侧 `search:` 锚点入口的后置断言（`search_coverage_test.gd` 属规则层） |
| Row 22 | `world.gd:658-662` | `poker_progress.next_hand`、`next_hand_heads_up`、`ending.continue_hand` | `continue_hand` 成功侧与四个守卫否定侧的具名断言 |
| Row 26 | `world.gd:681-681` | `poker_progress.*`、`poker_action.*` | 「推进后状态」断言（world 侧定时入口无覆盖） |
| Row 28 | `world.gd:687-688` | `poker_progress.flop/turn/river/showdown` | 四条街推进的具名断言 |
| Row 29 | `world.gd:690-692` | `poker_action.fold/call/check/raise/all_in` | 固定 seed 下对手 beat 的可复现断言 |
| Row 30 | `world.gd:1047-1051` | `world.leave_forced_pressure_exit`、`world.travel_landing`、`world.services_close` | 「关服务面板 + travel」这一组合的断言 |

这 11 行的共同特征：**后继的接受/拒绝结果已经由某个 ID 声明（`id_owns_successor`），新出现的是「调用方 / 输入绑定链 / 世界侧定时入口」这一层，缺的是断言或覆盖报告**。

这与上游既有口径一致：`current-tree-weak-evidence.csv` 里已用同样方式处理过同型行，例如 `world.gd:879-885`（`inventory = KEY_B` 输入绑定链）标注为 `catalog_id = world.services_open / world.services_close`、`world.gd:511-512`（BarService 锚点）标注为 `world.services_open`。**建议把这 11 行移入弱证据表并回填 `catalog_id`**，而不是留在缺口表里等新增 ID。

## 5. `same_outcome_merge`（12 行）—— 不新增 ID，归并到既有结果

| 行 | 源码坐标 | 归并到 | 理由 |
| --- | --- | --- | --- |
| Row 1、2 | `run.gd:147-148`、`:149` | `entry.locked` | fork 只改变「需要哪几间房」（输入条件），不改变「`enter_table` 被拒」这一结果 |
| Row 11 | `player.gd:50-51` | `world.raycast_unfocused` | 「无有效目标时不产生请求」与 world 侧守卫同一可见结果，只是提前到信号层 |
| Row 13 | `player.gd:67-69` | `world.focus_acquired` | 焦点未变化时的幂等重复分支，属「同一语义结果的重复分支」 |
| Row 15 | `world.gd:485-487` | `world.services_open` | 与 Row 14 同结果同 ID，且本行已有强断言（`spatial_interaction_test.gd:84-85`） |
| Row 18 | `world.gd:635-636` | `entry.table_active`、`world.pause_guard` | 拒绝原因（重复开局 / 暂停）均已在其他入口登记 |
| Row 19 | `world.gd:642-645` | `entry.success`、`entry.collateral`、`entry.heat_cap` | 后继就是 `enter_table` 的接受结果族，world 侧只是触发者 |
| Row 20 | `world.gd:648-649` | `world.pause_guard`、`world.modal_guard`、`world.busy_guard` | 四个拒绝原因均已在 `request_action` 入口登记同义 ID |
| Row 21 | `world.gd:653-656` | `poker_action.*`（8 条） | 后继就是牌桌动作接受族 |
| Row 24 | `world.gd:670-671` | `world.modal_guard` | 「面板打开时不推进 / 不交互」同一原因 |
| Row 25 | `world.gd:672-673` | `world.pause_guard`、`world.leave_unseated` | 同上 |
| Row 27 | `world.gd:684-685` | `poker_progress.actor_pending`、`world.modal_guard`、`world.pause_guard` | 同上 |

判定依据是目录自身的 `counting_rule`：「One semantic accepted/rejected outcome per ID. **Multiple input cases may exercise one ID.**」—— 上述行都是同一结果的另一个输入用例或另一层调用者，不是新结果。

### 主要重复/归并建议（按可操作顺序）

1. **先做 Row 14/15 的锚点回填**：`search:` / `shop:` 两个入口都应记 `world.services_open`，与弱证据表已有的 `world.gd:511-512` 口径统一（现在同一模式在两处口径不一致）。
2. **Row 24/25/27 合并处理**：三者是 `_process` / `advance_table_beat` 的同一守卫族，建议一次性把「拒绝原因 → 既有 ID」的映射写清，而不是逐行开新条目。
3. **Row 18/19/20 是 `world.start_table` / `world.play_action` 的守卫-后继对**：其规则层结果都已有 ID，建议成对归并。
4. **Row 1/2/3 是同一变化源的三处体现**（`room_layout` 抽取 + 两处拒绝）：若接受 Row 3 为 `confirmed_distinct_gap`，请一并说明 Row 1/2 归并到 `entry.locked` 的口径。
5. **Row 11/13** 是最容易被误判为缺口的两行（分层不同、且目录确实登记过重复调用 `world.pause_repeated`/`world.resume_repeated`）；两行的备选读数已写在 `review_notes` 里。

## 6. 不属于本次结论的区块（留待主 Agent 决策，不由本审计代答）

**世界会话与牌桌半区（`world.gd` ≈ 620–720）在 386 项目录里完全没有 `world.*` ID**：`start_table`、`play_action`、`continue_hand`、`_process`、`advance_table_beat`、`_notification` 六个入口一条 ID 都没有，而交互半区（`request_action`/`open_services`/`service_action`）与规则层是密集登记的。上表中 Row 18–29 共 12 行全部落在这个半区。

我按「后继语义是否已有归属」逐行给了分类，**但这属于目录政策问题而非逐行事实问题**：若主 Agent 希望世界侧按住/拒绝入口细分粒度登记（即认为「`start_table` 被暂停拒绝」与「`request_action` 被暂停拒绝」是不同 outcome），那么这 12 行里除 Row 26/28/29（后继由 `poker_progress.*` 承接）之外的守卫行都应改判为 `confirmed_distinct_gap`，应作为**整半区的一次性决策**处理。本审计不代答该决策，只在 CSV 的 `review_notes` 中逐行标注了备选读数。

## 7. 未知项

`unknown` 为 0（理由见 §2）。仍需注意的两处**非未知但需主 Agent 确认的口径分歧**：

- Row 3（`room_layout` 抽取）与 Row 23（定时自动存档）：我判为 `confirmed_distinct_gap`，但如果团队认为「抽取/写盘结果已被既有 ID 承接」，可分别降级为并入——两行均已在 `review_notes` 标注备选读数，未替主 Agent 定夺。
- Row 9/12（连续输入写快照字段）：如果目录的既定政策是**排除连续输入**，那么正确做法是在排除清单里显式记录并给出理由，而不是留白。现状（386 项里既无 ID、也无排除声明）本身是一处口径缺口。

## 8. 复验方式

在仓库根目录执行：

```sh
python3 output/external-handoff/A8/build_triage.py     # 由输入 CSV 重新生成交付表
python3 output/external-handoff/A8/verify_triage.py    # 从输入/源码/目录重新推导，CONFIRM/REFUTE
```

`verify_triage.py` 独立于生成脚本，只从**输入 CSV、输出 CSV、`transitions.json`、源码文件与本文档**重新推导，覆盖：

- 输出恰有一行对应每个输入候选（无遗漏、重复、臆造），输入 14 列逐字保留未被改写；
- 分类值、建议动作、`existing_id_check` 判定前缀三者互相一致；分类计数之和等于输入行数；
- **`new_id_candidate` 与 `confirmed_distinct_gap` 完全等价**（即「只有 `confirmed_distinct_gap` 能作为新增 ID 候选」是机器强制的）；
- `existing_id_check` 里引用的每个 target ID 都真实存在于当前 `transitions.json`；
- CSV 全表扫描所有 `路径:行号`（含输入列里的引用）：路径存在、行号在文件行数内且不指向空行；basename 歧义导致的跳过会显式打印，不静默放过；
- 本文档内的基线哈希、目录条数、分类计数表与 CSV 实测值一致；
- 输入 CSV / `transitions.json` / 5 个源文件自生成以来哈希未变（能捕捉交付期间的再次漂移）。

判定只认退出码 0 且 `REFUTE = 0`；结果同时写入 `output/external-handoff/A8/verify-triage.json`。

## 9. 声明

- 本审计**不等于全局目录完备**：它只逐行复核了输入表里的 30 条候选，没有重新审计 16 个源码文件的全部 667 条分支，也没有为「哪些结果应被排除」给出全局面分母。目录 `status` 仍是 `incomplete_catalog`。
- 本审计**不等于 Phase 1 通过**：它没有改动代码、测试、目录或存档，也没有运行回归套件；任何「阶段通过」的结论都必须另立。
- 本审计**未新增任何语义 ID**，7 条 `confirmed_distinct_gap` 只是候选，是否增补由主 Agent 决定。
