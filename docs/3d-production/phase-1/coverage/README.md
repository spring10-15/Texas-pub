# 状态转移覆盖：目录与执行证据

> 阅读口径（2026-09-25）：下文按实现批次保留历史快照，226、232、239、247、252 等数字各对应当时状态。最新登记数为 384，当前登记证据为 384/384；扑克、世界、存档三个已审分组虽已清空待办，但全局源码入口与可达结果尚未完成独立分母审计，因此整体覆盖率仍为空。胜者与边池分配已有下文 payout 六种结果的独立金额测试；这不代表穷尽所有牌型和下注路径。

2026-09-25 全局审计增量：新增 `start.partial_bankroll`，覆盖金库为 120 时从藏匿点开始牌局、本金按可用金库封顶的接受结果；测试断言金库归零、现金与本金均为 120、财富守恒、Run 激活且 revision 增加。`entry_coverage_test.gd` 新增 `entry.heat_cap`，验证屋顶会所风声为 5 时成功入座后封顶至 6，并检查现金、金库、revision 和桌型。房间进入测试也验证正种子与完整 `variant_plan` 重生成一致。全量回归 59/59（报告 `output/3d/regression/20260925-111306/report.json`），覆盖汇总器单测 3/3；汇总为 `verified=384 catalogued=384 global_coverage=unavailable`。A8 当前树对账已把旧快照的两条缺口映射到新 ID；另有 31 条可达无 ID 候选待逐项核验，不能据此宣称整体覆盖率。

2026-09-25 内容配置收口：Godot 当前未消费的 Web-only 场景字段、重复桌规展示字段，以及未使用的路线 `revealFlag` 已从权威内容配置移除；风险与买入仍分别由 `publicInfo.risk` 和桌面玩法字段提供。四家酒馆共 16 条固定/特殊路线的中文显示名现由各自场景配置提供，稳定的特殊路线 dispatch key 继续负责逻辑行为。`scene_rules_test.gd` 对字段清理和全部 16 个路线显示名做回归；全量回归 59/59，报告 `output/3d/regression/20260925-091713/report.json`。覆盖汇总为已登记 382/382，但没有新增状态转移 ID；全局目录分母仍未知，不能据此声称整体覆盖率。

2026-09-25 全局覆盖口径澄清：扑克、世界、存档三组 `pending_families` 已全部清空，但这仅表示既有审查分组已收口，不证明完整状态转移分母。`transitions.json` 的计数说明现明确要求源码驱动的全局入口审计；汇总器测试也断言目录仍为 `incomplete_catalog`、三组为空且全局覆盖率为 `null`。目录哈希更新后全量回归 59/59，报告 `output/3d/regression/20260925-092627/report.json`；覆盖证据仍为已登记 382/382，A8 独立审计尚未完成。

2026-09-25 手间快照下注额边界：多种子随机玩家回归在 640 组组合中产生 13 个合法的手间快照，其 `status` 已为 `hand_over`，但上一街的 `currentBet` 与玩家 `currentBet` 最大值不同。`TableCheckpoint.restore()` 现仅在 `playing` 状态要求二者相等；`roster_showdown_test.gd` 验证完整 Run 快照恢复前后相等，并继续完成整桌结算与撤离。专项 37,766 项检查通过；全回归 59/59，报告 `output/3d/regression/20260925-081126/report.json`。这次没有新增目录 ID，381/381 仍只说明已登记结果均有证据；A8 全局分支审计仍需判断是否存在尚未枚举的独立语义结果。

2026-09-25 贵重物出售范围补测：`service_coverage_test.gd` 现在为 `content.json` 中全部 10 件贵重物分别走公开 `service_action("sell")`，断言对应价值到账、物品移除、行动力和 revision 正确变化，以及金库+现金+剩余贵重物总值不变。10/10 售卖案例通过；沿用既有 `service.sell` 语义 ID，没有扩大目录分母。服务子图 21/21、覆盖汇总器当前证据 381/381；全局目录仍为 `incomplete_catalog`，不据此推断全局覆盖率。

2026-09-25 桌后奖励配置接线：`Run.settle_table()` 现依次读取四桌 `rewardRules`，现金门槛、背包条件和抵押返还条件由配置表达；旧 `baseRewardPool` 与 `signatureReward` 双份清单已合并。`settlement_coverage_test.gd` 保留 17 个独立结算情境，并将四桌首条奖励规则替换为另一件有效贵重物，确认实际结算与奖励情报池都跟随同一份配置。结算子图 21/21、四项配置敏感性案例 4/4、全量回归 59/59；全局状态仍为 `incomplete_catalog`。

2026-09-25 桌前风险信息显示：牌桌入座面板现在读取公开配置中的 `publicInfo.risk`，显示对应中文风险等级；四桌 HUD 回归均确认风险等级在买入前可见。未知等级使用“未评估”作为显式回退。此为信息呈现改进，不新增状态转移 ID，也不代替真实玩家对风险是否可理解的验证。

2026-09-25 桌规情报配置接线：入座面板和 `Run.rule_text()` 现读取每桌 `hiddenInfo.rule`，四条配置说明已改为中文。HUD 回归分别替换四桌的规则文本并确认面板显示替换值，证明展示随内容配置变化；全量回归 59/59，未新增转移目录 ID。真实玩家是否读懂规则仍待试玩。

2026-09-25 进行中牌桌旧配置迁移：奖励池改为 `rewardRules` 后，`RunCheckpoint.restore()` 会校验旧/当前桌定义的玩法字段仍一致，再把仅影响展示或奖励配置的旧字段替换为当前权威定义；买入、盲注、加注、手数、对手与其他桌规仍严格比较。运行时旧格式快照恢复后，行动者、底池和玩家状态保持一致；改写买入、手数等桌规仍拒绝。新增 `persistence_run.active_table_definition_migrated`，当前登记数 382。

2026-09-25 旧格式迁移族收口：A5 `legacy_migration` 的所有可复现运行时结果均映射到现有目录 ID，旧 Run 字段、缺失 props、缺少 search event 的 version 1 磁盘封套，以及 version 2/3 variant plan 均有恢复后具体状态断言；未来 envelope 版本拒绝并保留原文件也有测试。版本 1 磁盘夹具由测试运行时构造，version 2/3 variant plan 通过 RunCheckpoint 恢复测试构造；没有真实历史用户 `.save` 样本，本轮不声称验证过历史玩家档案。该外部样本限制不属于当前可复现转移目录，因此从 `pending_families.persistence` 移除 `legacy_migration`。

2026-09-25 不可读存档分支收口：在 `SaveStore.read_checkpoint()` 内部抽出文件打开回调，公开入口仍使用 `FileAccess.open()`；`save_store_test.gd` 对一个确实存在且内容有效的检查点注入拒绝打开结果，断言返回 `unreadable` 且原文件字节未变。新增 `persistence_io.read_unreadable`，从 `pending_families.persistence` 移除此组。该测试稳定覆盖读取拒绝分支，不模拟操作系统权限配置本身。登记数增至 381；全局目录分母与覆盖率仍未封板。

2026-09-25 存档恢复与非法数据复核：A5 `restore` 七行和 `invalid_data` 17 行全部映射到现有目录 ID，当前专项证据分别为 World restore 18/18、Run restore 5/5、Table restore 4/4；三份报告无缺项且目录与相关源码哈希匹配。恢复成功、损坏/缺档处置、试玩存档守卫、World 快照矛盾、Run 字段边界和 Table 快照一致性均有后继状态断言。因此从 `pending_families.persistence` 移除 `restore` 与 `invalid_data`，待审组从 4 减至 2；未新增语义 ID。完整回归 59/59，目录证据 380/380，覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-064158/report.json`。

2026-09-25 存档写入失败保护：新增 `persistence_io.write_temp_verification_rejected`，通过私有 `_write_checkpoint()` 的读回校验器注入无效结果，验证返回 `ERR_FILE_CORRUPT`、旧存档字节保持不变、临时文件被清理；线上入口仍使用真实 `read_checkpoint()`。A5 同组的新建、覆盖、临时文件复核失败、临时文件打开失败和原子重命名失败现在均有正式后继证据；`checkpoint_state()` 不产生任意 `Object` 引用，因此不把外部手工传入的非游戏状态算作玩家路径。从 `pending_families.persistence` 移除 `write`，待审组从 5 减至 4；完整回归 59/59，目录证据 380/380，覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-063601/report.json`。

2026-09-25 存档 RNG 重放族收口：A5 `rng_replay` 的三行结果均落在现有目录 ID：牌桌恢复逐动作边界对照（`persistence_table.rng_replay`，660 个动作边界）、世界恢复后的 160 步同步重放（`persistence_replay.world_rng_resume`）及 +12345 RNG 扰动后的 60 步差异负对照（`persistence_replay.rng_negative_control`）。当前两份专项报告均为全命中、无缺项，目录哈希与相关 Run/Table/World 源码哈希匹配。因此从 `pending_families.persistence` 移除 `rng_replay`，待审组从 6 减至 5；完整回归 59/59，目录证据 379/379，覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-062450/report.json`。

2026-09-25 A4 世界交互四组收口：逐行复核 `leave_seat`、`physical_raycast`、`prop_interactions`、`modal_guards` 的 47 个 A4 结果候选；所有可达结果都映射到当前 74/74 的世界覆盖报告，且对应目录 ID 均有后继状态证据。`leave_seat` 中 `settle_table` 失败仅能通过破坏桌/Run 对象同步制造，A4 标为不可达防御分支，不纳入玩家路径；未注册道具 ID 同样不可由公开交互锚点产生。报告的目录、测试及四份 World 源码哈希均与当前文件匹配。因此 `pending_families.world` 清空；存档仍有 6 组待审，全局目录与覆盖率仍未封板。完整回归 59/59，目录证据 379/379，覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-061911/report.json`。

2026-09-25 入座分支复核：A4 `seat` 组的三项结果现均由 `world_coverage_test.gd` 正式覆盖：`world.seat` 核对真实牌桌交互后的座席面板、座席相机与控制权切换；`world.seat_blocked` 核对藏匿点未入酒馆时拒绝且完整世界快照不变；`world.seated_world_action_rejected` 核对入座后道具请求拒绝且快照不变。三项都能在当前世界覆盖报告中命中，因此从 `pending_families.world` 移除 `seat`，待审组从 5 减至 4；没有新增语义 ID。完整回归 59/59，目录证据 379/379，覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-061253/report.json`。整体目录仍未封板。

2026-09-25 通用房门路由分支：`world_coverage_test.gd` 现在通过 `LedgerCellar` 与 `MirrorHall` 的真实门锚点验证 `room:<dest>` 拒绝和接受路径：前置桌未完成时留在原房间、显示阻塞原因且完整世界快照不变；满足相应前置后分别进入镜厅与余烬牌室，并核对标题、落点与 Run 快照不变。为隔离门路由，测试直接设置完成标记，不声称在该用例内实际打完前置桌；完整桌流程由现有其他套件验证。新增 `world.room_graph_entry` 与 `world.room_graph_blocked`，世界覆盖 74/74；从 `pending_families.world` 移除 `room_entry`，待审组从 6 减至 5。完整回归 59/59，目录证据 379/379，覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-060731/report.json`。测试固定线性布局隔离门路由；房间图种子多样性仍由 `seed_diversity_test.gd` 单独检验。

2026-09-25 世界暂停/恢复分支复核：`world_coverage_test.gd` 和 A4 审计逐项覆盖 `world.pause`、`world.pause_repeated`、`world.pause_guard`、`world.resume`、`world.resume_repeated`、`world.toggle_pause_services`、`world.toggle_pause_run_panel`、`world.toggle_pause_resume`、`world.toggle_pause_pregame_leave` 与 `world.leave_paused_rejected`。这些结果均有正式后继状态断言和当前证据，因此从 `pending_families.world` 移除 `pause`、`resume`，待审组从 8 减至 6；登记数仍为 377。完整回归 59/59、目录证据 377/377、覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-054208/report.json`。全局状态转移分母仍未封板。

2026-09-25 快照捕获字段完整性：`persistence_capture_coverage_test.gd` 现在独立核对 Run 全部显式存档字段及嵌套牌桌快照、Table 的 `state/revision/rngValue`、World 的八个字段与实际值；原有三类深拷贝隔离也继续验证。新增 `persistence_capture.run_fields_complete`、`persistence_capture.table_fields_complete`、`persistence_capture.world_fields_complete`，捕获子图 6/6，因此从 `pending_families.persistence` 移除 `capture`。完整回归 59/59，目录证据 372/372，覆盖汇总器单测 3/3。该结果证明当前序列化入口字段完整及快照隔离，不证明 restore 的全部合法/非法状态或全局覆盖率。报告：`output/3d/regression/20260925-050408/report.json`。

2026-09-25 存档封套拒绝分支：`save_store_test.gd` 新增 `persistence_io.read_invalid_envelope`，逐一写入非字典封套、缺失版本、非整数版本、缺失 payload 和错误摘要；每种输入都要求返回 `invalid` 且原文件字节不变。I/O 子图 11/11；全量回归 59/59，目录证据 373/373，覆盖汇总器单测 3/3。`pending_families.persistence.read` 已收窄为 `read_unreadable`，当前执行环境无法可靠模拟文件存在但操作系统拒绝读取的分支；其余存档分支仍待审，整体覆盖率保持 unavailable。报告：`output/3d/regression/20260925-051031/report.json`。

2026-09-25 修复预约路线存档篡改：`RunCheckpoint.restore()` 原先只验证预约预付、尾款和热度上限是非负整数，未核对它们是否与该路线当前配置相符；把有效预约的尾款改为 0 并重算存档摘要即可制造免费撤离。现按保存的路线 ID 查找唯一配置，并核对折扣后的预付、尾款和热度上限。`run_restore_bounds_test.gd` 从真实预约动作生成合法基线，再修改这三项及路线 ID，确认四类快照均被拒绝且输入不变；合法预约仍可恢复。新结果 `persistence_run.reservation_offer_consistent` 与 `persistence_run.reservation_restored`；运行恢复子图 5/5。全量回归 59/59、当前目录证据 375/375，覆盖汇总器单测 3/3。报告：`output/3d/regression/20260925-052059/report.json`。完整状态机分母和其它存档分支仍未封板。

2026-09-25 牌桌恢复账本不变量：`TableCheckpoint.restore()` 原先只校验总筹码与底池合计，未校验三名玩家的累计投入之和等于底池，也未确保当前街下注额等于所有玩家当前下注的最大值。现拒绝投入总和偏高/偏低、当前下注额与玩家状态不一致、单个当前下注超过其累计投入的快照。`table_checkpoint_test.gd` 在合法开局快照上构造四种矛盾，均确认恢复拒绝且源牌桌不变；660 个合法恢复后动作边界仍保持一致。新增 `persistence_table.contribution_total_consistent` 与 `persistence_table.current_bet_consistent`，牌桌恢复子图 4/4。完整回归 59/59、目录证据 377/377、覆盖汇总器单测 3/3；报告：`output/3d/regression/20260925-052849/report.json`。全局状态机分母仍未封板。

2026-09-25 存档审计新增七项结果：`persistence_table.rng_replay` 在两桌、10 种子下验证 660 个恢复后动作边界一致；`persistence_run.legacy_variant_plan_restored` 用版本 2/3 内存旧计划验证历史对手阵容与线性房间图；`persistence_restore.save_repaired_from_memory` 验证有效内存状态可修复缺失/损坏的磁盘检查点；`persistence_restore.missing_checkpoint_recovered` 验证首次启动遇到缺档后可重新启用存盘且首次保存写出完整状态；`persistence_restore.playtest_save_blocked` 验证固定种子试玩模式不读写正式存档；`persistence_restore.active_table_not_seated` 与 `persistence_restore.table_id_mismatch` 验证两类矛盾快照被拒绝且不改变完整世界状态。恢复专项 59 项检查通过，恢复子图 18/18；RNG 重放、旧计划、修复专项分别通过 2,031、82、55 项。完整回归 59/59，覆盖汇总 `verified=365 catalogued=365`，汇总器单测 3/3 通过。旧计划使用内存样本，不代表验证过历史磁盘旧档。`pending_families` 仍包含世界交互与存档各阶段，整体覆盖率继续为 unavailable，不能据此宣称 Phase 1 通过。报告：`output/3d/regression/20260925-034925/report.json`。

2026-09-25 补充 `world.leave_forced_pressure_exit`：从正式世界覆盖测试的新实例中通过真实入座入口建立活动 Run，达到风声 6 后调用离座；验证系统选择 `dropbag-cash` 强制路线、丢弃现金 120、净额 170 入库、回到藏匿点且 Run 结束。世界专项结果 71/71，完整回归仍为 59/59。测试只固定风声和钱包状态以隔离离座边界，不声称验证所有高风声来源。报告：`output/3d/world-coverage.json`。

2026-09-25 再补 `world.seated_world_action_rejected`：验证已入座时请求台灯交互会被拒绝且完整世界快照不变。此前新增的 `world.leave_forced_pressure_exit` 也已纳入同一世界覆盖套件。静态遮挡焦点清除、暂停时路线确认及暂停时服务动作拒绝同时补上对应后继断言，复用既有语义 ID。`world_coverage_test.gd` 现为 72/72，A4 72 行中 70 行有正式后继证据，2 行正常玩家路径不可达；全量回归 59/59，当前目录证据 `verified=367 catalogued=367`。全局分母仍未封板。报告：`output/3d/regression/20260925-040802/report.json`。

2026-09-25 为 `world.gd::checkpoint_state()` 新增 `persistence_capture.world_snapshot_isolated`：通过修改捕获快照的嵌套 Run 背包/现金和 props，再验证 live 状态不变；随后修改 live Run/props，验证先前快照也不变。该 capture 报告额外记录并校验 `world.gd` 哈希，避免世界层实现变化后误用过期证据。capture 子图 3/3，当前目录证据 `verified=367 catalogued=367`；全局状态转移分母仍未封板。报告：`output/3d/persistence-capture-coverage.json`。

2026-09-25 为存档文件读取新增 `persistence_io.read_non_dictionary`：有效版本与 digest 的 envelope 中包含 Array payload，`read_checkpoint()` 必须返回 `invalid` 且保持原文件字节不变。存档 I/O 子图 10/10，A5 审计映射 37/37；完整回归 59/59，当前登记证据 `verified=368 catalogued=368`，汇总器单测 3/3。全局分母仍未封板，整体覆盖率仍 unavailable。报告：`output/3d/regression/20260925-041659/report.json`。

2026-09-25 修复旧存档 search result 回填：`RunCheckpoint.restore()` 过去仅用 `event=site` 校验旧条目，没有把默认值写回恢复态。新增 `persistence_run.legacy_search_event_restored`，以运行时构造的 version 1 磁盘夹具经正式 `world.load_checkpoint()` 验证：目标事件回填为站点 ID、另一站点的搜索结果保持不变、完整 Run/世界状态与迁移后基线全等，且磁盘旧夹具加载后逐字节未变。专项检查 83 项通过；全回归 59/59、当前目录证据 `verified=369 catalogued=369`，汇总器单测 3/3。该夹具不代表真实历史用户档案。报告：`output/3d/regression/20260925-044032/report.json`。

2026-09-25 补充旧版 v1 运行字段迁移：从完整世界快照中移除 14 个可选运行字段，将该旧形态写入隔离存档并经正式 `world.load_checkpoint()` 恢复；对照 `RunCheckpoint.restore()` 补出的默认值核对完整世界状态，随后继续执行真实情报动作并验证 revision 和已知规则变化。新增 `persistence_restore.legacy_run_fields`，恢复子图 13/13；这只验证 v1 内可选字段回填，不代表跨版本迁移。专项 40 项检查通过；全目录当前登记结果数为 354，完整转移分母仍未封板。

同日把两套既有拒绝测试接入覆盖证据：`run_restore_bounds_test.gd` 对 33 种畸形运行快照确认拒绝、输入和活动 Run 均不变；`table_checkpoint_test.gd` 对 11 种畸形牌桌快照确认拒绝且活动牌桌不变。分别登记 `persistence_run.invalid_fields_rejected` 与 `persistence_table.invalid_snapshot_rejected`。这是对运行/牌桌快照拒绝路径的代表性验证，其他 restore 条件仍留在 pending；当前目录登记数 357，全局分母仍未完成。

2026-09-25 前一批短额与精确跟注全押座位变体：四种桌规 × 三个行动座位 × 两种筹码条件，共 24 个真实队列前置。先按当前下注轮行动构造行动者，再验证欠注/匹配、剩余队列顺序、下注目标、`raiseUsed`、首攻折扣标志与总筹码守恒。现有 `queue.short_all_in` 与 `queue.exact_call_all_in` 已覆盖这些座位，不重复增加 ID；该批完成时扑克 pending 仍保留两类座位变体，专项 254 项检查通过。

随后补齐 A7 所列的两类扑克队列座位变体，并把它们接入现有 `short_stack_queue_test.gd`：短额全押加注和单一有筹码者欠注/跟齐/自动发牌分别轮换四桌 × 三座位，共 24 个新座位案例；连同前一批短额与精确跟注全押的 24 个案例，报告记录 48 个座位案例、590 项检查，全部通过。各输入只复现既有 `queue.short_all_in_raise_one_raise_rule`、`queue.lone_funded_*` 与 `queue.runout_showdown_conserves` 语义，不新增目录 ID；`pending_families.poker` 已清空。全局状态转移分母仍未封板，overall coverage 继续为空。

再将酒保出售贵重物的世界/UI 后继登记为 `world.services_sell`：正式 `world.service_action("sell", ...)` 执行后，贵重物从背包移除、现金增加对应售价、行动力与 revision 各按规则变化，服务弹窗保留且已售物品按钮从面板消失。`world_coverage_test.gd` 的世界子图为 70/70；全目录更新为 357 项，须在同一版本刷新全部套件证据后汇总。

2026-09-25 按 A4 世界取证补上禁用交互目标：射线仍聚焦到 disabled anchor 时，提示显示其 `disabled_reason`，玩家请求被拒绝且完整世界快照不变。`world_coverage_test.gd` 直接通过 Godot 实例设置导出属性；`interactable.gd` 已纳入世界脚本证据哈希，防止测试报告在交互逻辑变化后仍被误认为新鲜。该批基线世界子图为 69/69、全目录 343/343；后续座位与出售结果见上文最新记录。状态转移分母仍未完成。

根据 A5 存档取证，正式恢复套件新增三项拒绝后继：损坏磁盘档案读入失败时，完整世界快照及原文件字节不变、自动存盘关闭；活动局快照不能放在藏匿点；目标房间仍被前置桌锁住时不能载入。后两项同时断言拒绝后完整快照不变。定向恢复子图为 11/11。现有 `legacy_props` 证明的是当前版本内缺字段回填；没有历史发布版本的真实磁盘夹具，也没有跨版本迁移证明。

随后修正不兼容存档的识别：合法 envelope 中版本号不是当前版本时，`read_checkpoint` 返回 `unsupported_version` 和文件版本；损坏 envelope 仍返回 `invalid`。启动恢复对两者给出不同提示；未来版本夹具检查文件原字节、运行快照不变并关闭自动存盘。`read_version` 与 `persistence_restore.unsupported_version_preserved` 通过。这改善了问题诊断与防覆盖，但没有实现跨版本迁移。

根据 A5 世界层 RNG 重放探针新增正式 `world_rng_replay_test.gd`：实际开桌并推进到中段后写入隔离存档，再由新世界实例恢复；两侧同步驱动 160 步，逐步比较公开牌局状态、RNG、完整运行快照和手数，并确认跨过下一手。另以扰动后的 RNG 作负对照，要求差异检测能触发。两个结果由覆盖汇总器校验当前规则、场景脚本、测试和目录摘要；重放子图为 2/2。

同日补齐账房入口的一组玩家流程：货运桌未完成时，用真实射线请求门口交互，核对拒绝原因和完整世界快照不变；完成货运桌并离座后再次交互，核对进入账房、落点、场景标题及运行状态不变，再从账房门返回大厅。另用真实射线查看出口告示，核对普通撤离路线转为已知、revision 增加、门旁提示更新。这四个结果分别登记为 `world.room_door_blocked`、`world.room_door_unlocked`、`world.room_door_return`、`world.discover_exit`；世界子图定向测试为 60/60。

同日继续核对 A4 世界交互取证：新增 `world.confirm_hidden`、`world.confirm_disabled`、`world.show_run_panel` 和 `world.close_run_panel`。前两项分别在面板未打开、路线预览确认按钮禁用时调用正式确认入口，核对完整世界快照不变；后两项核对面板显示、文案、控制权关闭与恢复。暂停时强行保留已打开弹窗的组合需直接拼装内部状态，本批不把它当玩家可达结果登记。世界子图定向测试为 56/56；其它世界和持久化入口仍待枚举。

随后补充两条真实 Esc 分派：撤离面板打开时按 Esc 关闭面板并恢复探索控制；酒保面板打开时按 Esc 关闭面板且不进入暂停。两条路径核对完整游戏快照不变和控制/UI 后继；世界子图定向测试为 62/62。

再补两条 `toggle_pause` 的玩家入口：暂停中再次按键恢复牌桌相机与座位面板；入座但未开局时按键离座，回到原探索控制与站位。两条结果均通过真实坐席流程触发，分别登记为 `world.toggle_pause_resume` 与 `world.toggle_pause_pregame_leave`。

2026-09-24 根据 A3 外部取证补充 `poker_progress.next_hand_heads_up`：四桌各构造两种出局座位，先完成单挑首手，再经 `next_hand` 检查庄位轮换、小盲与大盲归属、翻前先手、两名玩家发牌、出局者不发牌、RNG 前进和总筹码守恒。`poker_action.*` 现有八类成功结果同时核对首次进攻折扣：弃牌/跟注/过牌保留标志；加注、开注、超额转全押和直接进攻性全押消耗标志。定向套件分别通过 8/8 与 11/11；其余扑克边界、世界交互和持久化仍待逐项审查，不能据此计算全局覆盖率。

同日根据 A5 取证加强 `persistence_restore.legacy_props`：测试先把酒馆灯切到另一状态，再恢复缺失 `props` 的旧快照；恢复后的完整世界快照须等于原基线，灯光可见属性须回到默认值。该测试只证明版本 1 内缺失字段的回填，不证明跨版本存档迁移。

随后将同一缺字段快照写到隔离的 `user://legacy-world-test-<进程号>.save`，通过正式 `SaveStore.read_checkpoint` 和 `world.load_checkpoint` 读回；核对完整世界快照、灯光终态、暂停恢复，并在恢复后成功调查牌桌规则、检查 revision 与已知规则，再删除临时文件。这个运行时生成的磁盘样本验证了当前版本的文件读写与回填链路，仍不是历史发布版本留下的静态存档夹具。

根据 A4 取证补上九条 `world.services_*` 结果：暂停或撤离弹窗打开时拒绝进入背包；探索中与入座时分别打开、关闭背包并核对控制权；服务面板隐藏或动作未列出时拒绝动作且完整快照不变；已知普通出口的路线动作只打开撤离预览，不改经济状态。正式世界覆盖套件 33/33 通过；服务动作的购买、情报等成功分支和其余世界交互仍待拆分，不把这九条当作整个 `modal_guards` 族完成。

同批增加五条道具反向结果：台灯关回、抽屉推回、窗户关上、扑克牌翻回、筹码转回。全部通过真实准星与 `request_action` 执行，等待补间完成后核对可见属性和运行资金快照；抽屉移动后重新对准新位置。正式世界覆盖套件现为 38/38，其他房间的灯与餐具柜尚未接入正式目录。

随后把四个酒馆各自的壁灯和餐具柜纳入正式测试：逐店用真实射线瞄准并完成开、关两向，分别核对布尔状态、动画终点和运行状态不变。四店共享四种后继语义，因此只新增 `room_light_on/off`、`room_cupboard_open/close` 四个 ID，而非按房间重复计数。世界子图定向测试为 42/42；未覆盖的房间进入、服务动作等分支仍在待审列表。

藏匿点皮箱盖通过准星交互关闭和重开，核对盖板旋转、按钮标题和运行资金不变。跨道具忙碌守卫则先确认台灯和窗户都可命中，台灯补间开始后立即对准窗户尝试交互；窗户仍在准星上但请求被拒，窗户状态与完整世界快照不变。这三项追加为 `case_close`、`case_reopen`、`cross_prop_busy`；世界子图定向测试为 45/45。

服务动作的两个成功后继也已登记：酒保面板里的规则调查消耗 1 行动力、增加已知规则并刷新但保留弹窗；当前上架且可支付的商品购买扣现金、扣行动力、入背包，酒保交付提示出现且商品弹窗关闭。测试从同一固定种子的真实运行态调用 `world.service_action`，核对 revision 与对应 UI 状态；世界子图定向测试为 47/47。其他服务动作仍待枚举。

射线拒绝另拆出交互距离外与实心遮挡两项。距离测试显式确认相机到锚点超过 `Player.REACH`；遮挡测试先确认同一近处站位可命中台灯，再放入碰撞体，确认准星不再命中且 `request_action` 拒绝、世界快照不变。世界子图定向测试为 49/49，准星焦点变化及其它交互仍待审查。

准星焦点现在记录三种独立后继：瞄准台灯时 `focused` 变为锚点且交互提示出现，离开有效距离后焦点与提示清空，暂停关闭控制权后焦点同样清空。正式测试监听 `focus_changed` 信号并核对 UI 文本；世界子图定向测试为 52/52。其它世界入口与存档族仍未枚举完。

2026-09-14。transitions.json 是逐步审查中的语义转移目录，当前 status=incomplete_catalog。pending_families 明确保留未拆分的生命周期、服务、搜索、扑克、世界交互和持久化范围；不得把当前数组长度当作全游戏分母。

一个 ID 表示一次公开入口的成功结果或拒绝原因。多个输入命中同一结果只计一次。拒绝是同一状态上的自环，必须同时验证完整状态未变；只检查返回 false 不构成充分证据。子条件的短路求值覆盖、各种冲突条件的优先级、所有经济数值组合不由这份语义覆盖率替代，仍需要对应边界测试。

首批 transfer.* 共 12 项：成功、旧 revision、无活动局、活动牌桌、未知目的地、已经访问、本店尚未完成新桌、本晚结束、无行动力、现金不足、出口未发现、出口封锁。来源是 run.gd 的 transfer_quote/transfer_venue 和 routes.gd 的普通出口条件。返回原因的优先级可能使同时失效的条件被另一个原因覆盖，本批用例分别隔离各条件。

执行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
```

报告 output/3d/transfer-coverage.json 保存每个真实命中 ID、执行结果、所有规则文件、测试脚本与目录 SHA-256、缺失项及失败项。本轮 12/12；这是转场子图的结果。overall_state_transition_coverage 明确为 null。测试出现任何脚本错误，即使进程退出码为 0 也不得记通过。

后续工作：逐一审查 pending_families 的实际入口与内部结果，增补稳定 ID；在验证后继状态的测试中记录命中，再汇总同一源码版本的证据。全目录审查完成以前不计算 ≥95% 总覆盖率。已有大量断言与测试文件不自动转换成覆盖命中。

## 生命周期与防过期汇总（2026-09-14）

新增 start/reset/discover/extract/abandon/pressure 六组共 31 个具名结果。验证出发金库转移、120 门槛、六类撤离的现金/贵重物等式、重复到账拒绝、夹层钱包保留 80、封锁时可撤离与无路可走的失败分支。各拒绝结果检查完整 checkpoint 不变。路线报价内部守卫仍列在 pending_families.route_quotes，不能因 extract.rejected_quote 命中一例就将它们全部记通过。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/lifecycle_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
python3 Godot/three_d/tests/collect_coverage.py
python3 Godot/three_d/tests/test_collect_coverage.py
```

两份执行报告核对当前目录、所有规则文件及各自测试脚本的摘要。汇总器拒绝过期来源、已有失败、缺失或杜撰命中、夸大计数；3 个单元测试（含 7 个缺陷子情境）通过，缺陷只在内存中注入，不改真实证据文件。摘要文件 output/3d/coverage-summary.json 显示 43 个已登记结果均有当前证据，全局覆盖率仍为 null，未枚举的状态族保持显式待办。

## 撤离守卫与边界（2026-09-14）

route_guard.* 新增 24 个具名结果：20 个拒绝结果与 4 个允许边界（风声 5 的普通出口附加费、预约有效期最后一轮、两种特殊出口最高允许风声）。测试通过实际 Run.extract 入口执行，报价前后不变，拒绝后完整 checkpoint 不变，成功时校验独立计算的费用与到账。四酒馆 × 两个预约方案 × 24 个结果共 192 个情境通过；这些样本只贡献 24 个语义命中。

“丢贵重物但紧急出口未知”不作为独立最终结果：有贵重物时 emergency_known 为真；无贵重物时最终原因是“没有可舍弃的贵重物”。源码中的条件存在并不代表可到达一个额外的独立拒绝状态。复杂条件重叠时的优先级仍不等同于本批隔离守卫覆盖。

2026-09-23 补充重叠守卫回归：路线未发现、封锁、过期或无可舍弃贵重物时，即使现金也不足，报价仍先显示路线不可用的真实原因；只有路线本身可用时才显示费用不足。四酒馆、各预约方案均核对报价只读、撤离被拒与完整快照不变。该修复不新增语义 ID，仍不宣称穷尽所有守卫组合。

本批完成初始 pending_families.route_quotes 的拆分；总目录仍因其它状态族未完整枚举而未封板。现在 67 个已登记结果均有当前证据，整体百分比依旧为空。

更新汇总前，先运行新增套件及原两套件，避免目录摘要过期：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/route_guard_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/lifecycle_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
python3 Godot/three_d/tests/collect_coverage.py
python3 Godot/three_d/tests/test_collect_coverage.py
```

## 搜索结果与拒绝守卫（2026-09-14）

search.* 新增 20 个结果：物品、路线、现金、付费情报、免费情报、降风声六类成功，以及未知选择、非活动局、活动牌桌、房间未解锁、重复处理、无行动力、现金不足、背包满、路线已知、情报目标桌已完成、情报已知、已经降过风声、无需降风声、旧 revision 十四类拒绝。测试走公开 service_action(search) 入口，先核对查询原因且查询不改变状态；成功用独立预期的完整 checkpoint 对比，拒绝要求完整 checkpoint 不变。消息内容仅要求非空且与领取记录一致，不把文案本身当作经济状态证明。

本套件固定烟雾酒馆和种子 0，以隔离语义结果。它不替代现有 search_events/event_pool 的事件置换、其他物品奖励、存档及物理交互测试，也不声称覆盖所有边界与守卫冲突组合。初始 search 待拆分族已列入目录；其他待拆分族仍保留。

执行 search_coverage_test.gd 以及上述三个覆盖套件，再运行 collect_coverage.py 和 test_collect_coverage.py。本轮四套件全部通过，汇总器 3 个测试通过：87 个登记结果均有当前证据。全局状态转移分母尚未完成，不能据此宣布达到 95% 或完成 Phase 1。

## 入座与抵押守卫（2026-09-14）

entry.* 新增 12 个结果：普通入座、抵押入座，以及旧 revision、未知牌桌、非活动局、已有牌桌、已经完成、房间未解锁、买入不足、不允许抵押、未持有抵押物、抵押物非贵重物十类拒绝。真实 enter_table 入口执行；成功检查现金扣款、风声、金库、revision、抵押物归属、完成记录、行动力与牌桌创建，拒绝检查完整 checkpoint 不变。固定种子 0、烟雾酒馆隔离入口条件；发牌、盲注、RNG 与多酒馆风声边界仍由其他专用测试负责，未在本套件声称完整覆盖。

新增执行 entry_coverage_test.gd 后，重跑四个既有覆盖套件，再运行汇总和汇总器测试。本轮 99 个已登记结果均有当前证据，3 个汇总器测试通过。settle_table 仍明确保留在 pending_families.run_lifecycle，入座通过不能替代结算奖励、抵押归还和重复到账的验证。全局覆盖率仍未计算。

## 结算奖励与抵押归属（2026-09-14）

settlement.* 新增 21 个具名结果：十种奖励选择、保本、亏损、背包满、抵押失去、主池平分归还、只赢边池不归还、旧格式 awards 归还，以及旧 revision、非活动局、无牌桌、未结束牌桌四种拒绝。奖励选择中 antique 同时验证主池胜利后归还抵押。所有成功情境再次调用结算，要求拒绝且完整状态不变；重复调用归入 no_table 守卫，不重复计数。

测试真实入座后注入 finished 结果夹具，再通过 settle_table 执行。这是结算边界测试，不声称这些结果由该套件实际打牌产生。独立断言现金增加量、金库不变、物品列表、奖励结果、风声缓解、完成记录、行动力重置、出口发现和 revision。四种拒绝均比较完整 checkpoint。初始生命周期待拆分项已经枚举，但扑克、服务、世界和持久化仍待完成。

运行 settlement_coverage_test.gd 与五个原覆盖套件后，汇总为 120 个登记结果具备当前证据；汇总器 3 个测试通过。全局分母仍未封板，不能宣布达到 Phase 1 的 95% 门槛。

## 离桌基础服务（2026-09-14）

service.* 新增 21 个结果：购买、出售、喝镇定酒、付费降风声、查明规则五种成功，以及旧 revision、非活动局、道具动作不匹配、活动牌桌、无行动力、未上架、购买现金不足、满背包、出售未持有物、已经降风声、风声为零、没有镇定酒、降风声现金不足、规则已知、未知牌桌、未知动作十六类拒绝。每例先验证 service_reason 与查询无副作用，再通过 service_action 执行。成功用独立现金/物品/风声/规则/行动力/revision 预期对比完整 checkpoint；拒绝要求完整 checkpoint 不变。

本套件固定烟雾酒馆、种子 0、镇定酒交易，分别使用买价 30、卖价 10、降风声费用 24 的独立预期。四酒馆费率、其它物品与货架池组合由专用测试覆盖，不在此扩大宣称。lens/sleeve 与高级道具、预约仍留在 pending_families.services；共享的 mismatch 守卫本例仅用 drink 隔离，不能替代其他动作的专用边界。

运行 service_coverage_test.gd 和六个原覆盖套件后，141 个登记结果均有当前证据，汇总器 3 个测试通过。全局状态转移目录仍未完成，整体覆盖率保持为空。

## 透镜与袖夹（2026-09-14）

tool.* 新增 15 个结果：透镜预览、袖夹换牌、先预览再换牌保留牌堆顶、风声上限四种成功，以及旧 revision、非活动局、道具不匹配、无牌桌、牌桌结束、未持有、本桌已用、河牌无法预览、翻牌后无法换牌、首次行动后无法换牌、非玩家行动无法换牌十一种拒绝。成功验证物品消耗、used_tools、两层 revision、资金与行动力不变、风声、手牌及剩余牌堆；拒绝比较完整 checkpoint。组合用例先真实调用透镜，再调用袖夹，验证抽走的是牌堆倒数第二张且顶部预览保留。

固定烟雾酒馆与首桌；阶段和行动时机的拒绝条件使用隔离夹具。该套件不替代实际打牌推进、跨桌额外风声和存档重放测试。运行 tool_coverage_test.gd 与七个既有覆盖套件，156 个登记结果具备当前证据，汇总器 3 个测试通过。全局目录仍不完整，服务中的高级道具与预约继续保留待办。

## 情报重复消耗修复（2026-09-14）

审查高级服务发现手机可消耗在已知完整情报或已完成的牌桌，笔记可重复消耗在已记录的同一对手。新增 redundant_intel_test.gd：修复前 7 项中 4 项失败（包含第二份笔记被浪费后无法记录另一对手的连带失败），修复后 7 项通过。手机仍允许把“仅规则已知”升级成完整情报，另一位对手仍可消耗第二份笔记记录。新增拒绝理由由现有 service_reason 驱动，拒绝时完整 checkpoint 不变。

routes_items_test.gd 的 54 项通过；规则摘要变化后重跑八个覆盖套件，156 项证据更新有效，汇总器 3 项通过。此次 7 项专用回归没有自动计入语义覆盖目录，高级服务族仍待完整枚举。

## 预约费用与条件快照（2026-09-14）

reservation.* 新增 11 个结果：首次预约、过期重订、手机更新候选后保留原预约，以及旧 revision、非活动局、错误物品、活动牌桌、无行动力、接应未知、已有有效预约、预付款不足八类拒绝。四酒馆 × 两个方案 × 十一个结果共 88 个情境，计 11 个具名结果。成功预约用独立公式构造完整预期 checkpoint，验证预付折扣/最低费用、尾款快照、有效期、行动力与 revision；过期重订照常再次付费。手机更新仅改变候选，原预约与撤离报价尾款保留；拒绝比较完整 checkpoint。

本轮 reservation_coverage_test.gd 与八个原覆盖套件通过，167 个登记结果证据有效，汇总器 3 个测试通过。phone-route 的无预约状态及其他高级物品仍待枚举，故不从服务待办中移除 phone-route。全局目录未封板，不报告全局覆盖百分比。

## 高级道具入口与拒绝结果（2026-09-14）

advanced.* 新增 26 个结果：手机更新候选、完整情报、新增规则基础上的完整情报、两种通行证、对手笔记、已弃牌对手笔记、信号八种成功，以及非活动、未持有、道具不匹配、活动牌桌、无行动力、未知/已完成/已知情报牌桌、非通行证、路线已知、无牌桌、已结束牌桌、未知/自己/已弃牌信号目标、信号已用、笔记已知、旧 revision 十八类拒绝。成功构造完整 checkpoint 预期，包含牌桌 revision，但牌堆、手牌与 RNG 应不变；拒绝要求完整状态不变。

信号成功仅检查三档格式、物品和风声消耗、不泄露底牌；其强/中/弱阈值及有效对手计数新增为 pending_families.signal_analysis，尚未证明。初始 services 入口已拆分，不能将它误读成全部服务内部计算已经覆盖。固定烟雾酒馆与首桌的用例也不代表全部多酒馆组合。

本轮 advanced_coverage_test.gd 与九个原覆盖套件通过，193 个登记结果具备当前证据，汇总器 3 个测试通过。扑克、世界、持久化和信号分析仍待完成，全局分母未封板。

## 非正式动作名跳过扣款修复（2026-09-14）

审查 Table.act 发现 legal_actions 的 UI 字段 allIn 可被当作命令名传入：合法性检查为真，但执行分支只识别 all-in，造成不扣筹码仍推进 turnCounter、revision 和队列。入口现限定 fold/check/call/raise/all-in 五种正式命令。action_name_test.gd 在四桌分别验证 allIn、空值、未知值及大写值拒绝且完整牌桌快照不变，并验证正式 all-in 将全部筹码加入底池。修复前 20 项有 4 项失败，修复后全部通过。

table_test.gd 1879 项、table_checkpoint_test.gd 2021 项通过。规则摘要变化后十个覆盖套件重跑，193 个登记结果证据有效，汇总器 3 项通过。新增专用回归尚未转换为扑克语义目录命中，扑克族继续保留待办。

## 扑克行动拒绝守卫（2026-09-14）

poker_guard.* 新增 15 个拒绝结果：旧 revision、未知动作、非进行状态、错误回合、未知行动者、已弃牌、零筹码、欠注时过牌、无欠注时跟注、跟注不足、已经加注、欠注时加注不足、开注不足、已跟平时加注不足、低于最低目标。四桌共 60 个隔离情境。先核对 legal_actions 与只读不变，再通过 act 执行并比较完整 TableCheckpoint（包含 RNG）。低于最低目标及旧 revision 的合法动作仍可出现在 legal_actions；错误 allIn 则验证 UI 字段存在并不构成正式命令授权。

筹码与阶段拒绝条件采用边界夹具，不声称全部夹具是完整对局自然到达的状态。成功行动、街道推进、摊牌、边池与下一手仍保留待办。poker_guard_coverage_test.gd 和十个原覆盖套件通过，208 个已登记结果具备当前证据；汇总器 3 项通过。全局分母未封板。

## 合法下注与资金转移（2026-09-14）

poker_action.* 新增 8 个结果：弃牌、跟注、过牌、默认加注、无人下注时开注、自定义加注、超额加注转全押、直接全押。四桌共 32 个情境；过牌/开注通过真实跟注和推进到翻牌到达前置状态。核对自身筹码减少、贡献/底池增加、牌桌目标、下一行动者、其他玩家筹码不变、手牌/牌堆/公共牌/RNG 不变，以及桌上筹码加底池等于三人初始买入。

本批基础动作成功不涵盖短筹码全押、刚好跟注耗尽、重新开放队列、仅一人有筹码的队列，以及优惠状态的完整组合；这些显式追加到 poker 待办。poker_action_coverage_test.gd 与十一个原覆盖套件通过，216 个登记结果具备当前证据，汇总器 3 项通过。全局分母仍未封板。

## 街道推进与下一手（2026-09-14）

poker_progress.* 新增十个结果：翻牌、转牌、河牌、摊牌、下一手五种成功，以及仍有人行动、进行中不能开下一手、旧推进 revision、已结束手牌不能再推进、旧下一手 revision 五种拒绝。四桌都通过真实 call/check 完成首手后开启第二手；检查发牌数量及牌堆顺序、推进前后筹码和贡献、RNG 不变、派彩总额等于底池、结算后总财富、轮转庄位及新盲注。拒绝验证完整牌桌 checkpoint 不变。

摊牌测试比较实际 awards 与筹码增量并验证总额，不用它证明胜者分配正确；showdown_winner_allocation 在本批次仍待办（历史状态；随后 payout 小节新增六种独立预期，不代表所有牌型组合已穷尽）。单挑下一手、牌桌彻底结束后禁止下一手也另列待办。poker_progress_coverage_test.gd 与十二个原覆盖套件通过，226 个已登记结果具备当前证据，汇总器 3 项通过。全局目录尚未封板。

## 胜者与边池独立金额预期（2026-09-14）

payout.* 新增六种结果，通过 Table.advance 的河牌入口执行：单一胜者、三层贡献、最强牌已弃牌、三人公共牌平分、各层边池平分、平分余数。固定非连张彩虹公共牌下 AA/KK/QQ 排序；贡献 30/60/90 时预期派彩 90/60/30，AA 弃牌则为 0/150/30。公共皇家同花顺使剩余玩家平分；三人各贡献 5、第一人弃牌时，当前按 seatIndex 分余数规则派彩 0/8/7。预期金额直接写入测试，不调用同一个 evaluator 生成答案。

测试核对每人到账、各层底池金额、弃牌者不在可领奖或胜者列表、总财富 360、RNG/牌堆/公共牌不变，以及重复 advance 不重复派彩。固定河牌夹具只证明该边界，不声称是实际完整下注路径或穷尽全部牌型比较。payout_coverage_test.gd 与十三个原覆盖套件通过，232 个登记结果具备当前证据，汇总器 3 项通过。全局分母仍未封板。

## 整桌结束专用回归（2026-09-14）

table_endings_test.gd 新增 66 项检查。四桌按自身手数连续真实执行两人弃牌、赢家领取底池和下一手；验证未达上限时仍可继续，已弃牌但有筹码的对手返回，最后一手结束整桌且 next_hand 不可重启。另用全员全押河牌夹具验证玩家输光与玩家独赢所有筹码的结束条件及精确财富。

首轮测试夹具误把一位对手配成与公共牌 J 匹配的三条，造成 4 项预期失败；修正为明确 AA/KK/QQ 比较后 66 项通过。此次没有改动游戏规则，也不把专用断言数量计入语义覆盖；对应 poker 待办仍待接入带来源摘要的登记证据。

## 结束条件登记与隔离（2026-09-14）

将 table_endings_test.gd 接入来源摘要和汇总，登记 ending.* 七类：弃牌派彩、达到手数上限、继续下一手、已弃牌者返回、结束后拒绝重开、只剩一人有筹码、玩家破产。原来玩家输光的夹具也同时满足“只剩一人有筹码”，本轮改为两位对手持不同花色 AA 平分、玩家 QQ 输光；验证有筹码人数为 2，单独证明玩家破产分支。玩家获胜场景仍验证只有一人有筹码。

更新后的 66 项检查全部通过，贡献 7 个具名结果而非 66 个。十五个覆盖套件报告均匹配当前目录和源码；239 个登记结果证据有效，汇总器 3 项通过。全局分母仍未完成，整体覆盖率保持为空。

## 短筹码与行动队列专用回归（2026-09-14）

short_stack_queue_test.gd 四桌共 56 项通过：短于欠注额的全押、刚好耗尽的跟注、加注重新召回已跟注玩家、补齐新目标后清空队列、仅一人有筹码且仍欠注、仅一人有筹码但已跟平、自动发完三条街并摊牌。短筹码前置通过在玩家间转移筹码构造且保持初始总额；自动发牌场景随后走真实 call/all-in/advance，最终财富等于三人初始买入。

这些专用检查尚未转换为带来源摘要的语义命中，short_all_in/exact_call_all_in/queue_reopen/lone_funded_queue 仍保留在目录待办，后续接入不能按 56 个断言计数。游戏规则未修改。

## 短筹码与行动队列证据（2026-09-21）

`short_stack_queue_test.gd` 纳入汇总器，登记八个 `queue.*` 结果：不足跟注的全押、刚好跟注后全押、加注召回先前跟注者、跟齐后结束下注轮、唯一有筹码者仍欠注、唯一有筹码者跟齐、无人可继续下注时发完公共牌、摊牌后的总财富守恒。四种桌规分别执行，实际断言 84 项；断言数不当作转移数量。

短筹码夹具保留总财富，并核对实际扣款、底池、目标下注额、队列、revision、牌堆与 RNG。自动发牌按测试执行前的牌堆独立取预期公共牌，验证每一轮不改变底池、不产生行动者、不消耗 RNG。报告绑定规则、测试与目录哈希；全部十六个登记套件需在当前目录下重跑。

本轮登记总数 247。`short_all_in`、`exact_call_all_in`、`queue_reopen`、`lone_funded_queue` 暂留 pending：当前夹具覆盖三人桌指定座位，尚不能据此宣布不同座位、两人局、加注权与优惠交互全部审查完成。全局分母仍未封板，不声明达到 95%。

## 信号打火机牌力分档（2026-09-21）

`signal_coverage_test.gd` 登记五个 `signal.*` 结果，四种桌规各执行一次，共 20 个河牌夹具：目标持皇家同花顺必胜（强）；公共皇家同花顺三人平分（弱）；另一位对手弃牌后两人平分（中）；玩家弃牌后两人平分（中）；第三人已全押但未弃牌仍按三人平分（弱）。预期来自必胜与平分事实，不调用同一估算函数生成答案。

每例通过 Run.service_action 执行，完整比较使用前后快照：只允许消耗打火机、登记使用、增加并封顶风声、更新文案与 revision；资金、其他物品、牌堆、底牌、公共牌、RNG 与队列保持不变。再次使用拒绝且状态不变。该夹具直接设置河牌，并非完整发牌流程；不证明 Monte Carlo 估算在所有未知公共牌下的校准程度，也不单独证明 AI 无隐藏信息泄漏。

signal_analysis 的强/中/弱与参与人数分支已拆分入目录，从 pending_families 移除。当前 17 个登记套件、252 个结果具备同版本证据；汇总器 3 项检查通过。扑克其他边界、世界交互和持久化仍待枚举，全局覆盖率为空。

## 两人局庄位轮换修复（2026-09-21）

`dealer_rotation_test.gd` 在四种桌规下分别设定座位 1/2 出局，使用实际 call/check/advance/fold/next_hand 连续推进四手，并在每手之间恢复存档。为跨越完整轮换周期，夹具把手数临时设为四手；产品桌规手数未改。修复前的下注前检查复现 24 项失败：按三座位与手数取模会让两人局第三/四手的庄位、盲注和首行动者错误。

`next_hand` 现在从上一位庄家轮到下一名仍有筹码的玩家，不以原始座位总数取模。首手及直接重设夹具不额外轮转。新测试 304 项通过，包含庄家付小盲、翻牌前先行动、非庄家翻牌后先行动、出局席不获牌、每手总财富守恒和跨手恢复。17 个登记覆盖套件及六个相关回归套件通过，汇总器三项通过。该回归暂未分配语义覆盖 ID，因此登记数仍为 252，next_hand_heads_up 仍待完整分支枚举。

## 存档恢复边界校验（2026-09-21）

`run_restore_bounds_test.gd` 复现恢复器接受负数行动力、超额行动力、负数本金/revision、零搜索轮次、未知情报/使用道具 ID、超容量背包的问题。恢复器现在拒绝这些状态，并在向类型化数组赋值前检查库存、情报和已用道具的元素类型。背包按 slots 累计占格，不按物品件数判断；不禁止合法重复贵重物。

新增 29 项检查通过，包含双格物品超容量、非法数组元素、拒绝时原始输入和运行对象不变、合法满背包、零/最大行动力，以及旧版本可选字段缺失时的迁移。测试仅操作内存快照，不读取玩家存档。17 个覆盖套件和 services_save/table_checkpoint/run/run_variants/venue_transfer 五个回归套件通过，汇总器三项通过。尚未穷尽嵌套 reservation/search_results 等字段，因此不宣布整个持久化族完成；登记覆盖数仍为 252。

## 世界交互首批登记（2026-09-23）

`world_coverage_test.gd` 首批将七个公开结果纳入证据：射线未对准拒绝、台灯开关生效、动画忙碌拒绝、灯光到达目标值、暂停拒绝、服务弹窗拒绝、读档恢复台灯状态。真实相机从场景坐标瞄准交互锚点，拒绝结果核对世界快照不变；操作结果同时核对道具状态、灯光与规则快照。报告 `output/3d/world-coverage.json` 除全部规则文件与测试/目录哈希，还绑定 `world.gd`、`player.gd`、`scene_props.gd` 的源码哈希；汇总器拒绝这些脚本的过期证据。

本批只覆盖台灯相关的世界交互；抽屉、窗户、扑克牌、筹码、入座/离座、转房间、其他弹窗与存档分支继续保留在 `pending_families`，不据七个登记结果推断整个世界系统达到 95%。

同日继续登记七个入口结果：未出发时牌桌拒绝入座、藏匿点门口实际准星打开出发确认并进入酒馆、实际牌桌准星入座、入座暂停、恢复、开桌前离座返回原位置、开桌未完成时拒绝离座且现金不变。专项报告达到 14/14；测试没有绕过准星直接赋予入座状态。已登记结果的范围仍是已采样的语义结果，其它房间、坐席变化与弹窗组合继续待审。

同日增加四种藏匿点实体道具结果：抽屉拉开、窗户打开、扑克牌翻面、筹码转动。每项都先等待角色碰撞稳定，再用相机准星射线调用 `request_action`，验证道具状态、动画终点以及规则账本快照未变化；桌面物件的准星不再依赖瞬移后尚未稳定的相机方向。专项报告达到 18/18。其它抽屉、反向关闭、各酒馆壁灯与餐具柜、转房间和存档文件族仍在待审范围；全局状态转移覆盖率继续为空。

2026-09-25 扑克队列与首次进攻折扣专项复核：`short_stack_queue_test.gd` 新增全押抬高下注目标后重新召回先前跟注者的独立结果 `queue.all_in_raise_reopens_prior_caller`，以及短额全押召回欠注玩家、但按项目“一街一次加注”规则保持加注关闭的结果 `queue.short_all_in_raise_one_raise_rule`；队列专项 86 项检查通过。新建 `poker_discount_coverage_test.gd`，登记被动动作保留折扣、首次进攻消耗折扣、同手后续进攻按全额扣款、下一手恢复折扣四项；以真实下注队列推进至下一街、完成本手并开启下一手，定向套件 18 项检查通过。`pending_families.poker` 已将短全押、精确全押和单人有筹码队列收窄为座位/单挑变体待审；两种队列重开结果已有核心证据，短全押座位变体仍待审。该项变更不表示扑克覆盖族完成，也不计算全局覆盖率。

同日根据 A5 存档取证，为 `RunCheckpoint.capture`（包含活动牌桌快照）和 `TableCheckpoint.capture` 新增隔离结果：核对捕获值、revision/RNG，并通过修改快照嵌套字典/数组确认运行状态未被反向改变。两个结果分别登记在 `persistence_capture.*`；其余文件错误分支、旧版磁盘迁移和世界层完整重放边界仍留在存档待办中。

同日增强 `save_store_test.gd` 的拒绝读取后置条件：摘要损坏、不支持版本、短文件和截断文件在返回拒绝结果后，原文件字节均保持不变。原 `persistence_io.read_version` 与 `read_truncated` 语义 ID 不变；写入失败新增两项稳定 ID。全量回归 59/59，覆盖汇总器 353/353。

同日将写入失败的两条分支加入正式覆盖：临时文件无法创建时不产生目标文件；目标路径是目录、原子替换失败时目录保留且临时文件清理。结果登记为 `persistence_io.write_open_rejected` 与 `persistence_io.write_rename_rejected`，待本轮全量回归刷新报告。

## 牌桌奖励情报与结算一致性（2026-09-23）

玩家买到的完整情报原本从 `content.json` 的 `baseRewardPool` 显示可能奖励；独立结算夹具发现账房地窖多列了红宝石袖扣、余烬桌多列了翡翠胸针，两者都无法在对应桌的实际结算分支获得。现已从这两桌的展示池移除，并让 `settlement_coverage_test.gd` 从十种真实结算奖励结果汇集可达物品，逐桌与展示池比较；不再只检查奖励发放本身。结算金额、阈值与掉落规则未改。该检查是情报准确性证据，不新增语义转移 ID，也不改变全局覆盖率未定的状态。

同一轮还把货运桌首次激进行动折扣接回 `content.json` 的 `firstAggressionDiscount`：牌桌合法行动、实际扣筹码和 HUD 实付预览均读取该字段，已有值 10，因此现有玩法金额不变。另用隔离牌桌把配置临时改为 5，验证预览、扣款与一次性消耗同步变化；没有修改正式桌规。

## 运行中存档文件丢失或损坏（2026-09-23）

`world.save_checkpoint()` 曾在内存快照未变时直接报成功，即使磁盘上的存档已被移走或损坏。现在跳过写盘前会读取并核对磁盘存档确实等于当前快照；若文件缺失或校验失败，使用当前有效内存状态重新原子写入。`services_save_test.gd` 先复现“文件已删除却返回成功”，再覆盖删除与篡改摘要两种恢复情形，并核对恢复文件内容与内存完全一致。启动时遇到坏档仍按原规则保留坏档、禁止覆盖；本测试只使用独立的 `user://full-run-test-<进程号>.save`，不操作玩家正式存档。

## 存档文件与世界恢复首批语义登记（2026-09-23）

`save_store_test.gd` 现在登记六种文件层结果：缺档、首次写入、有效读取、原子替换、摘要损坏、版本不支持；`world_restore_atomic_test.gd` 登记八种世界恢复结果：道具状态非法、变换含非有限值、坐标越界三组拒绝，以及合法、旧版无道具字段、入座预备态、从活动牌桌恢复探索、暂停中恢复座位五组接受。拒绝逐例核对世界完整快照不变，接受核对相机、移动、UI、牌面与座位状态；报告分别保存为 `output/3d/persistence-io-coverage.json` 与 `persistence-restore-coverage.json`，汇总器核对目录、规则、世界脚本和测试文件的同版本 SHA-256。

另补 `run_checkpoint.gd` 的预览牌点数/花色/手数校验：之前这类内部无效状态可被恢复，之后界面读取预览字段时可能出错；现在无效快照被拒绝，真实镜片预览的存档往返继续通过。现有登记由 270 增至 284，但 `pending_families.persistence` 仍保留未审的写入失败、截断文件、运行状态嵌套一致性和 RNG 重放等结果；不能按 284/284 声称全游戏达 95%。

## 牌桌结束后的世界离座（2026-09-23）

`world_coverage_test.gd` 在实际准星入座、买入后，使用合法行动打完货运桌，再经 `leave_seat` 验证玩家筹码仅一次回到随身现金、房间保持酒馆、镜头与移动控制回到探索状态。重复离座核对完整世界快照不变。新增 `world.leave_finished` 与 `world.leave_unseated` 两个语义结果，世界专项证据 20/20、当前登记总数 286。其它房间与弹窗组合未穷尽，全局覆盖率仍为空。

## 截断存档的安全拒绝（2026-09-23）

`save_store_test.gd` 新增 `persistence_io.read_truncated`：独立测试文件分别写入不足四字节的文件和完整存档前半段。读取前先核对二进制记录声明长度，两个截断样本均返回 `invalid`，不进入 Godot 解码器、也不产生底层脚本错误日志；已有有效读取、摘要损坏及版本不支持路径继续通过。当前登记总数 287；它只覆盖文件层截断，不证明所有嵌套状态或旧版本迁移均已审完。

## 确认操作的世界状态交接（2026-09-23）

`world_coverage_test.gd` 在实际入座打完货运桌后，经 `confirm_run_action` 依次执行换店、普通撤离、再次出发后的主动放弃，以及低金库时的试玩资金重置。每步核对报价、当前房间、随身现金、金库、已访酒馆和弹窗状态；规则层金额仍由专门的守恒测试核对。新增四个 `world.*_confirm` 结果，世界专项 24/24，当前登记总数 291。其它按钮拒绝条件与所有房间布局组合仍未穷尽，全局覆盖率保持为空。
