# A8 工作底稿：Run 入口映射（未完成审计）

本文件仅记录主 Agent 对 `Run` 模块公开入口的初步盘点，供后续完整审计复用。它不是 A8 最终报告，也不证明 382 个目录 ID 是全局分母。

## 基线

- 审计基线：`b97c3b7`（World 会话入口审计基线；目录与生产源码自 `2e2f697` 起未变化）
- Godot：`4.7.2.stable.official.ed1daf0bf`
- 跟踪文件状态：干净；工作区存在多份未跟踪的外部协作交付，审计期间未修改或清理。
- 目录：382 个已登记 ID，状态 `incomplete_catalog`；当前三个 `pending_families` 数组为空。全局分母仍需源码驱动审计确认。

## 初步入口映射

下表只确认公开状态入口在目录中有对应 `entry`。A8 仍须逐个函数体拆出所有接受、拒绝、动作时机和互斥结果，再核验相应测试的后继状态断言与证据报告。

| Run 入口 | 源码行 | 当前目录 entry | ID 数 | 对应登记 ID 前缀 | 当前证据套件候选 |
|---|---:|---|---:|---|---|
| `start` | 51 | `start` | 5 | `start.*` | `lifecycle_coverage_test.gd` |
| `transfer_venue` | 100 | `transfer_venue` | 12 | `transfer.*` | `transfer_coverage_test.gd` |
| `enter_table` | 165 | `enter_table` | 12 | `entry.*` | `entry_coverage_test.gd` |
| `settle_table` | 183 | `settle_table` | 21 | `settlement.*` | `settlement_coverage_test.gd` |
| `discover_exit` | 219 | `discover_exit` | 4 | `discover.*` | `lifecycle_coverage_test.gd` |
| `extract` | 229 | `extract` | 8 | `extract.*` | `lifecycle_coverage_test.gd` |
| `reset_demo` | 242 | `reset_demo` | 4 | `reset.*` | `lifecycle_coverage_test.gd` |
| `service_action`（基础服务） | 315 | `service_action` | 21 | `service.*` | `service_coverage_test.gd` |
| `service_action`（牌桌工具） | 315 | `service_action(lens/sleeve)` | 15 | `tool.*` | `tool_coverage_test.gd` |
| `service_action`（物理搜索选择） | 315 | `service_action(search)` | 20 | `search.*` | `search_coverage_test.gd` |
| `abandon` | 481 | `abandon` | 5 | `abandon.*` | `lifecycle_coverage_test.gd` |
| `enforce_pressure` | 512 | `enforce_pressure` | 5 | `pressure.*` | `lifecycle_coverage_test.gd` |

基础服务之外的 `Advanced.apply()`、`SearchEvents.apply()` 及其 reason 分支仍须回到各自函数体审计；这里把它们列为 `service_action` 的状态入口分派，不把 helper 数量算作转移分母。

## 暂定排除项

以下方法在本轮初查中属于查询、预览或展示，不作为独立权威状态转移入口：`transfer_quote`、`table_blocked_reason`、`room_requirements`、`room_blocked_reason`、`table_definition`、`extraction_quote`、`slots_used`、`service_reason`、`shop_stock`、`service_view`、`sale_value`、`valuable_total`、`reward_for_table`、`table_reward_pool`、`abandon_quote`、`route_offer`、名称/描述读取方法、`route_known` 与 `reserve_fee`。A8 最终审计仍需检查这些 helper 是否有隐含副作用，以及 UI/游戏调度入口是否都回到被列入的公开命令。

## Table/扑克进度入口初查

源码入口与当前目录的对应关系：

| Table 入口 / helper | 源码行 | 登记 entry | 目录 ID 数 | 当前测试候选 |
|---|---:|---|---:|---|
| `act` | 77 | `act` | 34 | `poker_guard_coverage_test.gd`、`poker_action_coverage_test.gd`、`poker_discount_coverage_test.gd`、`short_stack_queue_test.gd` |
| `act` 的终手结果 | 77–135 | `act/advance/next_hand` | 7 | `table_endings_test.gd` |
| `advance` / `next_hand` | 146 / 185 | `advance/next_hand` | 10 | `poker_progress_coverage_test.gd` |
| `next_hand` 的单挑轮转 | 185 | `next_hand` | 1 | `table_endings_test.gd` |
| `start_hand` 的折扣重置 | 24 | `start_hand` | 1 | `poker_discount_coverage_test.gd` |
| `advance` 的单人有筹码 runout | 146 | `advance` | 2 | `short_stack_queue_test.gd` |

`commit`、`set_queue`、`finish_hand`、`log_event` 是 Table 内部的变更 helper；`Poker.shuffle_deck()` 会推进 RNG，由 `start_hand()` 调用；`Poker.settle_pots()` 计算结算结果，由 `advance()` 调用。它们要沿调用链检查，不能按 helper 数量增加分母。`Poker` 的牌型比较/评估及 `Opponent.choose()` 初查属于计算或选择逻辑；若实际入口改变 RNG 或权威状态，最终审计仍须纳入对应调用链。

结构性观察（待后继断言核验）：`act()` 的 stale revision、非法动作/行动者/筹码与下注边界拒绝均映射到 `poker_guard.*`；已接受动作映射到 `poker_action.*`、`poker_discount.*`、`queue.*` 或 `ending.*`；街道推进、摊牌和下一手映射到 `poker_progress.*`、`queue.*`、`ending.*`。当前目录按 `source + entry` 分组对应到 55 个 ID（34 + 7 + 10 + 1 + 1 + 2）；此数量是现有映射数，不是分支完备性证明。

## 服务、搜索、路线与变体初查

| 源模块 / 状态入口 | 当前目录 entry 与数量 | 当前测试候选 | 初步性质 |
|---|---|---|---|
| `Advanced.reason/apply`，由 `Run.service_action` 调用 | `service_action` 26 个 `advanced.*`；`service_action(reserve/phone-route)` 11 个 `reservation.*`；`apply(signal)` 5 个 `signal.*` | `advanced_coverage_test.gd`、`reservation_coverage_test.gd`、`signal_coverage_test.gd` | helper 本身不应按函数数目计数；预约、手机、通行证、笔记和信号动作由 Run 命令进入并递增 Run revision，牌桌信号/笔记还递增 Table revision。须逐项核对分支及状态后置条件。 |
| `Routes.quote`，由 `Run.extraction_quote/extract` 调用 | `Run.extract -> Routes.quote` 24 个 `route_guard.*` | `route_guard_coverage_test.gd`、`lifecycle_coverage_test.gd` | 报价查询本身为计算；抽取成功才写 Run 状态。需要区别路线资格拒绝、现金不足与成功结算，不能把 24 个 quote 案例自动等同于 24 个状态转移。 |
| `SearchEvents.choice/reason/apply`，由 `Run.service_action(search)` 调用 | `Run.service_action(search)` 20 个 `search.*`；搜索 helper 本身没有单独 source 行 | `search_coverage_test.gd`、`event_pool_test.gd` | `choice/reason` 是查询；`apply` 通过统一入口改现金、物品、路线情报、风声、行动力与一次性搜索记录。目录目前按 Run 公开命令归属，A8 要追踪到 helper 里的每个具体结果。 |
| `RunVariants.generate/valid/shuffled` | 无直接目录 entry | `run_variants_test.gd`、`run_restore_bounds_test.gd` | 初查是计划生成/验证 helper，不直接写 Run/Table/World 权威状态；`Run.start/transfer_venue` 提交生成计划，存档恢复校验计划。审计要检查每个变体维度是否由上游状态入口和已有结果覆盖，而不是把计划字段本身计作转移。 |

本组目录核数：`advanced_services.gd` 42 个（26 + 11 + 5），`routes.gd` 24 个；`search_events.gd` 与 `run_variants.gd` 无独立 source entry。以上只核对当前归属关系，没有核定每个接受/拒绝分支的独立性、玩家可达性或证据强度。

## 持久化入口初查

| 源入口 | 当前目录 entry 与数量 | 当前测试/报告候选 | 初步证据边界 |
|---|---|---|---|
| `RunCheckpoint.capture/restore` | `capture` 2；`restore` 7 | `persistence_capture_coverage_test.gd`、`run_restore_bounds_test.gd`、`world_restore_atomic_test.gd`；`persistence-capture/run/restore-coverage.json` | capture 测完整字段与深拷贝隔离；restore 涵盖缺省迁移、字段/预约/桌定义校验与失败输入不变。没有真实历史用户存档样本，旧版恢复只证明当前合成兼容夹具。 |
| `TableCheckpoint.capture/restore` | `capture` 2；`restore` 4 | `persistence_capture_coverage_test.gd`、`table_checkpoint_test.gd`；`persistence-capture/table-coverage.json` | 捕获字段、隔离、非法快照拒绝、贡献/下注额一致性与 RNG 连续恢复有断言；需继续核对每条拒绝分支是否映射同一合法结果或独立结果。 |
| `SaveStore.read_checkpoint/write_checkpoint` | `read_checkpoint` 8；`write_checkpoint` 5 | `save_store_test.gd`；`persistence-io-coverage.json` | 读错/不支持版本保持文件字节，临时文件写回验证失败与原子替换失败受测；不可读分支用打开回调拒绝模拟，不等于 OS 权限实测。 |
| World `checkpoint_state/load_checkpoint/restore_checkpoint/save_checkpoint` | 合计 22 个目录 entry 结果 | `persistence_capture_coverage_test.gd`、`world_restore_atomic_test.gd`、`world_rng_replay_test.gd`；`persistence-capture/restore/replay-coverage.json` | 失败恢复的 World 全快照不变、读档损坏/未来版本处理、桌中 RNG 重放有报告；只覆盖当前列举的错误输入与 160 步重放样本，不证明任意无效数据穷尽。 |

本组当前映射核数为 50 个目录结果（Run capture/restore 9、Table capture/restore 6、SaveStore 13、World capture/load/restore/save 22）。现有 `output/3d` 报告最新快照分别显示：persistence capture 6/6、Run restore 6/6、Table restore 4/4、I/O 13/13、World restore 18/18、RNG replay 2/2，均无 missing/failure；这只证明登记结果报告可命中，不等于源码入口已穷举，也不等于真实历史存档样本覆盖。

## 已发现的全局目录候选缺口（待完整审计复核）

| ID | 初步判定 | 证据 | A8 处理建议 |
|---|---|---|---|
| `world.interactable_disabled` | 当前没有证据证明是玩家可达分支；较可能是测试专用防御状态 | 目录来源已纠正为 `player.gd::can_interact`：`interactable.gd::prompt()` 只生成提示字符串，禁用时拒绝实际发生在 `target.enabled` 守卫。`world_coverage_test.gd:39-48` 手动设置 `anchor.enabled = false` 和 `disabled_reason`，断言提示文案及 `request_action` 拒绝。对 `Godot/three_d` 全目录检索，生产源码没有 `.enabled = false` 或 `disabled_reason` 赋值；`Interactable.enabled` 默认 `true`。 | 归入 `unverified-or-unreachable.csv` 并注明仅测试夹具可达；复核是否应作为目录外的 UI guard 记录，而非玩家状态转移。不要在 A8 结束前直接删除 ID。 |

该项当前只证明目录分母可能含有一个不可达/错归属结果，不足以计算修正后的全局分母。后续还须以同样方式检查其它固定夹具或人工改状态的测试结果。

## World 物理道具入口初查

`SceneProps.build_stash()` 创建三只抽屉，分别登记为 `drawer0/1/2`，都使用相同 `interact()` 状态翻转逻辑和 `position` 开合属性。覆盖目录只有 `world.prop_drawer0` 与 `world.prop_drawer0_reverse` 两个语义 ID；`world_coverage_test.gd` 对 drawer0 实际调用 World 交互并验证开/关属性，原 `spatial_interaction_test.gd` 则通过焦点射线操作 drawer1。为确认三只实体都接到同一交互路径，主 Agent 将空间测试扩展为实际射线打开 drawer0/1/2；专项测试 47 项全过。它仍只为 drawer0 做关闭的目录后置断言；A8 可按相同通用函数/相同开合状态的归并依据判断是否需要逐只补反向测试，不能仅凭名称缺失增加三条 ID。变更后全量回归 59/59，报告 `output/3d/regression/20260925-095832/report.json`；覆盖汇总与单测仍为 382/382、3/3，没有新增语义 ID。

同场景的台灯、窗、桌面牌和筹码亦通过 `props.interact()`；目录分别有开与反向 ID（灯的开由 `prop_on` 代表，关为 `prop_lamp_reverse`）。四酒馆壁灯/餐具柜复用同一构建函数，覆盖测试在四个实际房间逐个开合，再将相同“开/关”语义归并为 `world.room_light_on/off` 与 `world.room_cupboard_open/close`。这些归并有相同代码路径的证据，但最终审计仍应确认 CSV 记录了四房间逐一执行的测试后置断言。

### `World.request_action()` 分支映射增量

`world-request-action-review.csv` 按 `request_action()` 当前 19 个目录 ID 记录分支/守卫、源码区间、测试行和 `output/3d/world-coverage.json` 证据。CSV 校验器逐行确认目录 ID、source/entry、测试路径与报告命中均存在；报告中的目录 SHA-256 和 `world.gd` SHA-256 与当前文件一致。World 覆盖报告为 74/74，但此数字只表示已有 World ID 均命中。

可达性单独判断后，12 行有正常游戏流程证据，6 行目前仅证明防御守卫后置状态：焦点缺失、超距、被遮挡、暂停、模态框打开、入座后直接调用 `request_action()`。正常玩家输入会被 `Player._unhandled_input()` 的焦点/控件门控挡在这些调用之前；因此这些行的测试可证明拒绝原子性，但不能单独证明玩家可达。`world.room_graph_entry` 的接受分支后置断言成立，不过测试手动向 `completed` 加入解锁条件，只证明已解锁状态下的入口结果，真实逐桌解锁路径仍需独立复核。该 CSV 是 A8 的 World 单入口增量，不是完整 `branch-inventory.csv`，也不封闭 World 或全局分母。

### 离座与暂停/恢复入口映射增量

`world-session-lifecycle-review.csv` 记录 `leave_seat()`、`toggle_pause()`、`pause_game()` 和 `resume()` 的 14 个现有目录 ID，并额外列出 `leave_seat()` 中 `Run.settle_table()` 返回失败的无 ID 防御分支。映射行同时引用 `world_coverage_test.gd` 与 `table_integration.gd`：后者实际验证牌局中暂停后行动 revision 不变，以及恢复后牌桌视角/座位状态还原。该组测试不只是返回值检查；已登记行都核对界面、Run/桌状态或离座后的资金结算。

可达性方面，暂停后直接离座、未入座时直接离座、牌局未结束时直接离座、重复直接调用 pause/resume 都是防御性直接方法调用，正常 UI 不提供这些动作；离开预备座位、Esc 关闭弹窗、暂停进行中的牌局及结算完成后的离座有实际 UI 流程证据。强制撤离行的后继结算断言充分，但夹具直接把风声设为 6，正常玩法自然达到该阈值的完整路径仍未在该测试中演示。`settle_table()` 失败防御分支则已由 A4 审计 `outcomes.csv` 第 36 行判为正常玩家路径不可达：`start_table()` 绑定同一 Table 对象，恢复也会将 `table_game` 重新绑定 `run_game.table`，且入口使用当前 Run revision；该分支没有独立目录 ID。

## 未完成事项

- 尚未对上述入口逐分支确认源码后继状态与目录 ID 的一一映射。
- 尚未核验候选测试是否对每条结果断言权威 Run 状态及拒绝原子性。
- 尚未为除 `World.request_action()` 与离座/暂停/恢复外的分支填写当前源码行、测试、报告、证据强度和可达性 CSV。
- 尚未逐分支完成 Table、扑克/对手、服务 helper、路线/事件/变体、存档及 World 物理入口审计；本节已对这些模块做部分入口归属初查，但仍未逐行核对接受/拒绝语义、玩家可达性及后继断言。
- 尚未分析目录外的可达结果；不能据本底稿推导覆盖百分比或 Phase 1 通过。

本增量后的复验基线为 `2e2f6970043c3e0ab92ebd632238f66addb43f36`，Godot `4.7.2.stable.official.ed1daf0bf`。使用 `python3 Godot/three_d/tests/run_regression.py --timeout 240` 得 59/59；`python3 Godot/three_d/tests/collect_coverage.py` 显示 `verified=382 catalogued=382 global_coverage=unavailable`；`python3 Godot/three_d/tests/test_collect_coverage.py` 为 3/3。报告：`output/3d/regression/20260925-101457/report.json`。加长单测超时是因为 `roster_showdown_test.gd` 单项 640 组、37,766 检查，单独实测约 167 秒通过；默认 90 秒会将它误报为 TIMEOUT。
