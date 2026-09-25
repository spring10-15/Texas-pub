# A8 全局状态转移目录完备性审计

任务书：`执行任务A8-全局状态转移目录完备性复核-2026-09-25.md`。
**只读源码审计**：本轮未改游戏代码、资产、覆盖目录、测试或存档格式。

## 0. 一句话结论

**当前目录不能用来冻结分母。** 已登记的 382 个 ID 确实都有当时证据（382/382），但源码驱动审计另标出 **40 条没有目录 ID 的候选状态变化**；其中只有 34 条标为 `player_reachable=yes`，另 6 条在同一张表里标为 `no`，不能把 40 条整体表述成玩家可达缺口。目录自身还带有若干**重复开 ID / 声明错误**的问题。因此 `status: incomplete_catalog` 与三个空的 `pending_families` 数组**共同给出的「已收口」印象是误导性的**。

> **读这句话必须先看锚点**：`382/382` 与 `40 条未登记` 都是 **HEAD `8d8464e1` / 目录 `087971c9…` / 382 个 ID** 这一组基线上的结论。交付后工作区已增至 **383** 个 ID（未提交），详见 §2.1 —— 那 40 条里已有一条被主线采纳。

**当前树复核**：后续又登记了 `entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts` 与 `poker_progress.seeded_deal`，目录现为 389 个 ID；搜索与货架入口证据归入既有 `world.services_open`，房间图锁门拒绝证据归入既有 `entry.locked`，均未新增 ID。请使用 [当前树对账记录](current-tree-reconciliation.md) 与 `current-tree-branch-inventory.csv`；当前 389/389 个 ID 均可归因，另有 22 条可达无 ID 候选和 18 条弱证据项尚待逐条审查。下文的原始报告、CSV 与 `build_a8.py --check` 仍用于复现 382 项冻结锚点，不代表当前分母闭合。

## 1. 与主 Agent 底稿的关系

同目录下的 `source-audit-notes.md` 是**主 Agent 的入场初查底稿**，它自己声明「它不是 A8 最终报告」且「供后续完整审计复用」。本轮把它当作**输入线索**，所有结论都回到当前源码重新推导。

本目录另有三份由主 Agent 在审计期间并发产出的 `world-*-review.csv`。它们**不是**本报告的输入，见 §8。

## 2. 基线

| 项 | 值 |
|---|---|
| 开工 HEAD | `5178244b46c27a877394d618abab648bc51470da` |
| 收工 HEAD | `8d8464e199c0705510c247ed46c218af9ac2a180`（期间主 Agent 并发提交 7 次） |
| 目录 `docs/3d-production/phase-1/coverage/transitions.json` | sha256 `087971c97f58d22c36f28f1c7b234694c188dd967485a34a071ddbd37111aa28`，382 个 ID，`status: incomplete_catalog`，三个 `pending_families` 数组均为空 |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| 正式存档 | sha256 `773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a`、mtime `2026-09-09 15:31:13`，**审计期间未触碰** |

### 基线漂移的逐文件核验

审计期间 HEAD 前移 7 个提交，因此对**被引用的 15 个源文件**做了逐文件核对：

```sh
git diff --numstat 5178244..8d8464e -- Godot/three_d/rules/{run,table,poker,opponent,advanced_services,routes,search_events,run_variants,run_checkpoint,table_checkpoint,save_store}.gd Godot/three_d/scripts/{world,player,scene_props,interactable}.gd
```

**输出为空** —— 这 15 个文件在整个区间内字节未变，行号锚点与判定对开工、收工两个时刻同时有效。

同一区间内 `transitions.json` 变了 2 行：`world.interactable_disabled` 的 `source`/`entry` 由 `interactable.gd/prompt` 改挂 `player.gd/can_interact`。**ID 总量与集合未变**，且改动方向与本审计的独立判断一致（见 §5）。

### 2.1 交付之后的复核：目录又漂移了一次（这次未提交）

本清单的"分母"结论**只在上面这组锚点上成立**。交付后复核发现工作区又动了一次：

| 项 | 交付锚点 | 复核时的工作区 |
|---|---|---|
| HEAD | `8d8464e1` | `8d8464e1`（未变） |
| `transitions.json` | sha256 `087971c9…`，**382** 个 ID | sha256 `0a3d8fe3…`，**383** 个 ID（`git status` 显示已修改，**尚未提交**） |
| 新增 ID | — | `start.partial_bankroll`（`Godot/three_d/rules/run.gd` / `start`，outcome `accepted with bankroll capped by available vault`） |

**这条新增 ID 恰好独立印证了本审计 §7 的一条判断。** 本清单里早就有这一行（`unmapped-reachable.csv` 的 40 条之一）：

| source_line | catalog_id | disposition |
|---|---|---|
| `Godot/three_d/rules/run.gd:61-62` | `-` | `reachable_unmapped` |

`run.gd:61` 即 `bankroll = mini(int(content.standardBankroll), vault)`，也就是"本金被现有金库封顶"这条分支——与主 Agent 新登记的 `start.partial_bankroll` 是同一条。

- **对清单有利的一面**：本审计把它判为"未登记但可达"，主线随后为它补了 ID。这说明那 40 条不是凑数的噪声，而是可被采纳的缺口。
- **需要小心的一面**：纳入之后，这一行本应翻成 `catalogued_strong(start.partial_bankroll)`——但补 ID 是**主线**的动作，本审计不代改，故本清单一律保持锚点上的原样。
- **结论**：引用"382/382 全归因"或"40 条未登记"时，**必须同时给出锚点哈希**，否则会被误读成当前树的完备性结论。

### 2.2 核验器已能区分"漂移"与"漏采"

这两种情况含义相反，输出必须可辨：

| 情况 | 含义 | 核验器输出 |
|---|---|---|
| 目录在审计**之后**新增了 ID | 锚点漂移，本清单按锚点冻结 | `锚点漂移：… 这是目录在审计之后长大了，**不是本清单缺漏**` |
| 目录里有 ID，且该 ID **在锚点里就已存在**却无归因 | 本交付的**缺陷** | `分支遗漏风险：… 没有任何审计行归因` |
| 锚点里存在的 ID 被删 | 清单相关行可能整行失效 | 直接 **REFUTE** |
| git / 锚点提交不可用 | 无法判定漂移 | 直接 **REFUTE**（不静默跳过） |

锚点 ID 集合由 `git show 8d8464e1:docs/3d-production/phase-1/coverage/transitions.json` **读回**，而非在脚本里硬编码 382 个 ID。这四条分支已用合成数据做过正反测试（无漂移不误报 / 漂移不误判为缺漏 / 真漏采仍报漏采 / 删 ID 硬报错）。

### 2.3 交付内容可复现性（已交叉验证）

| 实验 | 结果 |
|---|---|
| 同环境连跑 2 次 | 三份 CSV 字节一致 |
| 改 `PYTHONHASHSEED=1` 重跑 | 字节一致（**集合迭代序没有泄漏进输出**） |
| 换成 382 个 ID 的锚点版目录重跑 | 字节一致（输出与目录版本无关） |
| 关闭锚点判定逻辑重跑 | 字节一致（本轮新增的锚点代码**不改变交付内容**） |

三份交付 CSV 的 sha256（已写入 `output/external-handoff/A8/source-hashes.txt`，连同 5 份分片哈希）：

| 文件 | sha256 |
|---|---|
| `branch-inventory.csv` | `16a432a2a59765c0b2bd23f10236ac87b38ff965cbc08ed6cbd1c4ea3ac7e0a5` |
| `unmapped-reachable.csv` | `b6e6bc137c55b904c49e403bf67142a5ad5a9ae0cfaef791c811502d0d52db87` |
| `unverified-or-unreachable.csv` | `75a44784452db86c9f517c62582a716acb99b8903abca8c97d060db723896146` |

> **一处未能归因的观测，如实记录。** 复核过程中有一次读到的两份 CSV 哈希与上述值不同（`branch-inventory.csv` `4521cfec…`、`unmapped-reachable.csv` `6c4fd87f…`，同一时刻 `unverified-or-unreachable.csv` 则一致）。随后四种交叉实验都只能复现上表的值，且与原始构建的 stdout 逐字一致，故**当前交付内容就是标准值**。该次读数未能定位到原因（已排除：分片改动、目录版本、脚本改动、哈希随机化、未排序首版），已按"可疑"记录，供后续轮次留意——**这不影响本审计的任何结论**，但提醒：本仓库交付目录存在并发写入，跨命令读同一文件时留个心眼。

## 3. 审计范围与纳入 / 排除判据

**范围**（16 份文件）：`run.gd`、`table.gd`、`poker.gd`、`opponent.gd`、`advanced_services.gd`、`routes.gd`、`search_events.gd`、`run_variants.gd`、`run_checkpoint.gd`、`table_checkpoint.gd`、`save_store.gd`、`world.gd`、`player.gd`、`scene_props.gd`、`interactable.gd`。

**纳入**：可由玩家输入或游戏调度触发、且可能改变权威 Run / Table / World / 存档状态的入口。
**排除**：纯查询、报价与预览、展示与格式化、纯计算、组装 helper。每条排除都写明理由，见各分片说明（`output/external-handoff/A8/fragments/*-notes.md`）。

**没有用 `grep func` 当状态转移全集**——先通读文件识别公开入口，再逐个体读完整函数体拆分支。

## 4. 交付物

| 文件 | 内容 |
|---|---|
| `branch-inventory.csv` | 667 行逐分支清单，14 列（唯一权威表，按 module / 文件 / 行号排序） |
| `unmapped-reachable.csv` | 40 行候选；其中 34 行标为玩家可达、6 行标为 `player_reachable=no`，需按列值拆开解读 |
| `unverified-or-unreachable.csv` | 151 行 —— `catalogued_weak`（有 ID 但证据弱）18 行 + `unreachable_or_not_transition` 133 行 |
| `a8-verify.json` | 机检结论、计数、逐条 CONFIRM / REFUTE / note |
| 支撑（在 `output/external-handoff/A8/`） | `build_a8.py`（构建 + 独立核验）、`fragments/`（五路审计原始分片与说明）、`source-hashes.txt`、`a8-verify.json` |

**表格粒度**：`branch-inventory.csv` 的每一行 = **一个源码分支 × 一条目录映射**。同一分支完成多个已登记结果时展开为多行；没有目录 ID 的分支保留为单行（**绝不因 `catalog_id` 为空而丢弃**）。

### 计数

| disposition | 行数 |
|---|---|
| `catalogued_strong` | 476 |
| `unreachable_or_not_transition` | 133 |
| `reachable_unmapped` | **40** |
| `catalogued_weak` | 18 |

目录归因（**仅在这组锚点上成立**：HEAD `8d8464e1` / 目录 `087971c9…` / 382 个 ID）：**382 / 382 个 ID 至少被一行归因**，其中 380 个有 `catalogued_strong` 行；2 个只有弱证据（`persistence_replay.rng_negative_control`、`persistence_restore.playtest_save_blocked`）。**该比例不适用于当前工作区**（已增至 383 个 ID，见 §2.1）。

按模块（与 `a8-verify.json` 的 `module_counts` 逐项一致，合计 667）：world 189、run 146、table 70、advanced_services 46、run_checkpoint 38、routes 26、scene_props 24、search_events 23、opponent 20、table_checkpoint 19、player 19、save_store 17、poker 16、run_variants 12、interactable 2。

## 5. 目录自身暴露的问题

这些**不是**「缺证据」，而是**ID 划分与声明本身的问题**，会直接影响分母口径。

1. **6 个 ID 共用同一后继**。`route_guard.cash_general` 与 `route_guard.cash_{fixed,river-launch,service-stairs,dropbag-cash,dropbag-valuables}` 六条，全部由 `Godot/three_d/rules/routes.gd:49-50` 的同一分支 `elif reason.is_empty() and run.cash < fee:` 产生，路线名只是参数；`Godot/three_d/tests/route_guard_coverage_test.gd` 也用同一段代码生成这六条、期望文案逐字相同。这违反目录自己的 `counting_rule`（「一个 ID 表示一次语义结果，多输入命中同一结果只计一次」），建议合并为单条、路线名降为用例参数。
2. **`reservation.*` 与 `advanced.*` 在同一源码行重复开 ID**。`reservation.{inactive,no_actions,table_active,wrong_item,stale_revision}` 与已登记的 `advanced.*` 兄弟分支落在完全相同的源码行，仅 `kind` 不同。
3. **`signal.*` 五条共用同一后继形状**，只有提示文案的强 / 中 / 弱标签不同。
4. **`persistence_replay.rng_negative_control` 声明 `outcome: rejected`，但源码里没有对应分支**，它只是 `world_rng_resume` 的测试侧负对照；其断言只覆盖「发散发生了」这个布尔量，不含任何权威后继值。
5. **两条 `source` 声明错误**：`advanced.stale_revision` 与 `reservation.stale_revision` 实际由 `Godot/three_d/rules/run.gd` 的通用 revision 守卫产生，目录却挂在 `advanced_services.gd`。
6. **12 条 `entry` 名不存在**：`advanced_services.gd` 只有 `reason()` 与 `apply()`，没有 `service_action()`；这些 ID 的分派入口是 `Run.service_action → Run.service_reason → Advanced.reason`。
7. **一条 entry 不完整**：`persistence_replay.world_rng_resume` 的 `entry: load_checkpoint` 是对的，但漏写了真正决定 RNG 的 `restore_checkpoint` → `table_checkpoint.gd` 链路。
8. **口径本身**：`382/382` 只说明**已登记的 ID 都有当前证据**，完全不说明**没有尚未枚举的 ID**。把它当成分母完整是任务书明确禁止的读法。

## 6. 五个权威状态类别的核验

`docs/3d-production/phase-1/state-machine.md` 给出的权威状态是**按三个主体划分**的：Run（资金、库存、抵押、风声、行动力、已完成牌桌、酒馆、搜索结果）、Table（牌堆、底牌、公共牌、筹码、行动队列、种子 RNG）、World（位置/房间、视线、入座、暂停、交互动画）。任务书把它概括成「资金、库存/道具、风声、位置、RNG」五类——**两套划分的口径并不完全一致**，以下按任务书的五类给出粗映射（按 ID family 归入，**属判断而非机器判定**）：

| 任务书类别 | 主要 family | 覆盖情况 |
|---|---|---|
| 资金 | `transfer`、`entry`、`settlement`、`payout`、`extract`、`route_guard`、`abandon`、`pressure`、`service`(购买/出售)、`tool`、`search`(现金)、`reservation`(费用) | 已有分支清单；但 `route_guard.cash_*` 六条同一后继 |
| 库存 / 道具 | `service`(物品增减)、`search`(物品)、`advanced`、`reservation`(物品)、`world.prop*`、`world.services_sell` | 已有分支清单 |
| 风声 | `pressure`、`route_guard`、`service`(降风声)、`search`(降风声)、`world.leave_forced_pressure_exit`、`settlement`(胜局缓释) | **`enter_table` 入座风声钳位无任何断言，见 §7** |
| 位置 | `world.room*`、`world.seat*`、`world.leave*`、`world.travel` | 已有分支清单；`world.room_entry` 一个 ID 对应两个入口 |
| RNG | `persistence_replay`、`persistence_table.rng_replay`、`poker` 洗牌点、`table.start_hand` / `next_hand` | 已有分支清单；洗牌与发牌只有间接断言（见 §7） |

**没有交付按状态类别索引的分支清单。** 本表的粒度是 `分支 × 目录结果`，不含 `state_category` 列。若主 Agent 需要按五类分别冻结分母，建议下一轮给 CSV 增加一列 `state_category`，而不是从 family 名反推。

**夹具与真实玩家路径的差别**：`branch-inventory.csv` 的 `player_reachable` 列与各分片说明记录了这一点。多处短筹码 / 满背包 / 高风声前置是靠**直接改写内部字段**构造的，只能证明规则引擎在该状态下正确，**不证明该状态在真实玩法中可达**。

## 7. 40 条未登记候选（其中 34 条标为可达）+ 最有价值的缺口

清单见 `unmapped-reachable.csv`（40 行；`player_reachable=yes` 为 34 行，`no` 为 6 行）。这六条需从玩家可达缺口计数中剔出或另行论证系统加载场景是否纳入分母。若只能看五条，看以下高价值候选：

| 源码位置 | 缺口 |
|---|---|
| `Godot/three_d/scripts/world.gd` `_notification` 焦点丢失自动暂停 | Alt-Tab 可达，会**写盘 + 关闭服务面板 + 暂停**，既无 ID 也无任何测试 |
| `Godot/three_d/scripts/world.gd` `_process` 自动存档 | `saving_enabled` 时每 0.5 秒写盘一次，无 ID |
| `Godot/three_d/scripts/world.gd` `_process` / `advance_table_beat` 定时牌桌推进 | 世界侧节拍驱动无 ID（规则层由 `poker_progress` / `ending` 覆盖） |
| `Godot/three_d/rules/run.gd:175` `enter_table` 入座风声钳位 `heat = mini(6, ...)` | **证据强度 `none`**：现有测试只用 `entryHeatBonus:0` 的场景，从未触达钳位 |
| `Godot/three_d/rules/table.gd:47-50` 开局洗牌与发牌 | 只有「RNG 变了」「牌堆剩 46 张」的间接断言，无牌序断言 |

另有两条**有 ID 但证据弱**的必须点出：`persistence_replay.rng_negative_control`（无源码分支，仅布尔断言）与 `persistence_restore.playtest_save_blocked`。

## 8. 与主 Agent 并发产物的关系（**需要人工合并决策**）

审计期间主 Agent 在同一目录并发产出三份 CSV，**表头与本报告逐字相同**（14 列），但：

- **`disposition` 取值体系不同**：主 Agent 用的是 `catalogued`、`catalogued; branch mapped, reachability assessed`、`catalogued_pending_reachability`、`unmapped_defensive_branch`；本报告用的是 `catalogued_strong` / `catalogued_weak` / `reachable_unmapped` / `unreachable_or_not_transition`。**两者无法直接合并，必须先做取值映射。**
- **`source_line` 格式不同**：主 Agent 写 `476-478`（文件另列），本报告写 `world.gd:476-478`（文件自含）。本报告的格式可独立解析，主 Agent 的格式需配合 `source_file` 列。
- **覆盖面**：主 Agent 的 World 部分覆盖 6 个入口、40 个 `world.*` ID；本报告覆盖 74 个 `world.*` ID。**40 个 ID 全部是本报告 ID 集合的子集**，未发现相互矛盾的判定。
- 本报告的构建脚本**只读 `output/external-handoff/A8/fragments/*.csv`**，主 Agent 的三份文件从未进入本报告的输入，也没有被本报告或构建脚本修改。

建议由主 Agent 决定：以哪一份作为权威 `branch-inventory.csv`，或先统一 `disposition` 取值再合并。**本报告不替主 Agent 做这个产品判断。**

## 9. 附带发现（超出本任务范围，仅记录）

### 9.1 本目录曾有 3 条断链，已于 2026-09-25 修复

早期 `python3 output/external-handoff/C1/verify_links.py` 曾在 `source-audit-notes.md` 报出 3 条**两级解析都失败**的引用：

| 位置 | 引用 | 问题 |
|---|---|---|
| `source-audit-notes.md:69` | 「persistence-capture/run/restore-coverage.json」 | 把三份报告压成一个斜杠串，无法打开 |
| `source-audit-notes.md:70` | 「persistence-capture/table-coverage.json」 | 同上 |
| `source-audit-notes.md:72` | 「persistence-capture/restore/replay-coverage.json」 | 同上 |

原因是把多份报告压成斜杠串。主 Agent 已将其改为各自真实的 `output/3d/*.json` 路径；本次重跑 `verify_links.py` 后，Markdown 链接不可解析数与两级解析失败数均为 0。

> **本报告自身的纠错记录（2026-09-25 复核）：** 本表初版把上面三个坏引用写成了反引号路径。按本项目惯例反引号 = 「可打开的引用」，那等于把主 Agent 的 3 条断链复制成了本报告的 3 条，且与本表上文"故意不加反引号"的说法自相矛盾。现已改为「」引用。修前 `verify_links.py` 退出码 1（本目录合计 6 条断链：主 Agent 底稿 3 条 + 本报告误加 3 条），修后本报告贡献 0 条。

本报告与 A7 复核报告此前各自的链接检查结论保留为历史记录；当前全目录链接检查结果为 0 条断链。

### 9.2 其他

- `output/3d/regression/` 下有 7 份非全绿的历史回归报告，其中两份是 `roster_showdown_test.gd` 因**每套件超时不足**（`run_regression.py` 默认 90 秒 < 该套件常态 135～144 秒）而 TIMEOUT。详见 A7 复核报告的 §4。
- 审计期间观察到同一工作树上**并发运行着多份 `run_regression.py` 与散装 Godot 进程**，它们会写同一批 `output/3d/*-coverage.json`；并发写同一批证据文件存在互相覆盖的风险。
- 审计结束时仍有 4 个无父进程的 Godot 残留进程（`save_store_test.gd`、`persistence_capture_coverage_test.gd`、`table_checkpoint_test.gd`、`services_save_test.gd`）。**不是本审计启动的，本审计也未终止它们。**

## 10. 本报告**没有**证明的事

- 没有证明分母完整，也没有给出任何全局覆盖率百分比。
- 没有宣布 Phase 1 通过。
- 没有做规划结论或排期（任务书明确这是主 Agent 的判断）。
- 没有跑 UI 截图、没有生成媒体、没有触发正式存档写入。
- 没有穷尽「服务动作的所有组合」这类组合爆炸路径：多条 `player_reachable` 判定是**推理结论**（给了调用链依据），不是穷举实测。

## 11. 复验命令与退出码

```sh
cd "<仓库根>"
python3 output/external-handoff/A8/build_a8.py           # 合并 + 独立核验 + 写出交付文件
python3 output/external-handoff/A8/build_a8.py --check   # 只核验，不重写交付文件
```

当前结果：**退出码 0，`REFUTE=0`**。

- 在**交付锚点**（382 个 ID）上：`CONFIRM=25`，且明确输出「目录与冻结锚点 `8d8464e1` 逐字一致（未漂移）」。
- 在**首次交付后复核的工作区**（383 个 ID，未提交）上：`CONFIRM=22`，退出码仍为 0，漂移以 note 明确报出。后续 385 项当前树对账不使用此锚点核验结果，见 [当前树对账记录](current-tree-reconciliation.md)。

核验器会重新推导、不采信分片里的任何结论性数字，具体检查：

1. 表头逐字一致、14 列、枚举取值合法；
2. 每条 `source_line` 可解析、行号在文件范围内、且落在某个函数体内（**含 `static func` 与类内方法**）；
3. `function_line` 与 `entry` 的 `func` 定义行一致；
4. 每条 `test` / `evidence_report` 路径真实存在；
5. 每个 `catalog_id` 逐字存在于 `transitions.json`（越界即报错）；
6. 同一 `source_line` 对同一 `catalog_id` 不得重复（重复映射检测）；
7. **归一不丢行**：合并前后键集合必须完全相等（防止把无 `catalog_id` 的「未登记可达」行吃掉）；
8. **分支遗漏风险**：统计「目录里有 ID、却没有任何审计行归因」的集合；
9. **锚点漂移 vs 清单漏采**：与冻结锚点逐字比对，把"目录长大了"与"本交付漏采"分开报（§2.2）；
10. 同时固化 15 份源文件、目录、5 份输入分片与 3 份交付 CSV 的 sha256 到 `source-hashes.txt`，供下一轮比对静默改写。

### 本轮已订正的分片缺陷（保留可追溯）

- `g1-run-transitions.csv` 两处 `evidence_report` 笔误：错误写法把报告名的下划线当连字符，写成 output/3d/settlement_coverage.json 与 output/3d/tool_coverage.json（此处**故意不加反引号**：这两个路径并不存在，加了会被当作可打开的引用）；实际文件是 output/3d/settlement-coverage.json 与 output/3d/tool-coverage.json。订正登记在 `build_a8.py` 的 `CORRECTIONS`，不静默改分片。
- `g5-orphan-closure.csv` 有 5 行的 `source_line` 尾部带中文括号注解，已**原样移入 `notes`**（只搬位置，不丢信息）。
- 3 组「同一源码行、并列条件、共享同一后继」的重复行已合并，`branch_or_guard` 用 ` / ` 连接保留各自描述。
