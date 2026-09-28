# 搜索事件与高级服务的源码结果核对

2026-09-28 当前树局部审计。源码 SHA-256：`search_events.gd` 为 `cd183477b4de961161153cc7742f9b8ef83ebcb1c6700f93b35e537beab079e3`，`advanced_services.gd` 为 `744c5ae66627ed303671111601f48982c1b3ce328f02ed3b0438e4a511f3a2b8`，派发入口 `run.gd` 为 `f6d61934d399eea05728c7f81780744ae8594a23afed8ca4e31a64cb8ffd0308`。测试与当前源码哈希匹配；执行证据为 `output/3d/search-coverage.json`、`advanced-coverage.json`、`reservation-coverage.json`、`output/3d/regression/20260928-215737/event_pool_test.log` 及完整回归 `output/3d/regression/20260928-215737/report.json`。

`Run.service_reason()` 与 `Run.service_action()` 对 `search` 和 `Advanced.KINDS` 先派发，再由各自模块决定拒绝或写入。一个目录 ID 表示有区别的拒绝或状态后继；相同拒绝与不变状态可由多个输入复用。下表从模块源码条件出发，不把其它 Run 服务或世界 UI 状态计入本局部分母。

| 子图 | 源码中的结果划分 | 目录与后继证据 |
|---|---|---|
| 搜索选择 | 未知选项；未出发或仍在牌桌；房间锁住；已处理；行动力或现金不足；背包满；路线已知；目标桌已完成或情报已知；本轮已降风声或风声为零 | `search.unknown_choice`、`phase_unavailable`、`locked`、`repeat`、`no_action_points`、`insufficient_cash`、`full_bag`、`known_route`、`completed_intel`、`known_intel`、`cool_unavailable`；`search_coverage_test.gd` 对每种拒绝核对完整 Run 不变 |
| 搜索落账 | 取得物品、路线、现金、付费/免费情报、付费降风声；行动力和结果记录只写一次；旧 revision 拒绝 | `search.goods`、`route`、`cash`、`paid_intel`、`free_intel`、`cool`、`stale_revision`；核对现金、风声、物品、路线/情报、结果与 revision；`search_events_test.gd` 另覆盖四站点两选项、恢复后防重复领取 |
| 搜索事件池 | 两组事件可互换位置；余烬桌抽到原货运事件时，较晚的固定路线线索改为河边接驳 | `event_pool_test.gd` 以四种布局、四酒馆和每个选项核对显示条款、扣费与奖励、存档恢复及实际事件 ID；这是现有搜索结果的输入变体，不另开重复结果 ID |
| 高级服务通用拒绝 | 未出发、物品缺失或动作不匹配；桌外动作遇到牌桌或行动力不足；牌桌道具遇到缺桌、已结束、目标无效/玩家自己、信号目标已弃牌、同桌信号已用、对手笔记已记 | `advanced.inactive`、`unowned`、`mismatch`、`table_active`、`no_actions`、`no_table`、`finished`、`target_unknown`、`target_player`、`target_folded`、`signal_used`、`notes_known`；`advanced_coverage_test.gd` 核对拒绝后完整状态不变 |
| 手机与通行证 | 手机查未知/已完成/已有全情报桌、通行证类型错误或路线已揭示；成功切换接应方案、补全桌情报、揭示后厨或河边路线 | `advanced.phone_unknown`、`phone_completed`、`phone_known`、`pass_invalid`、`pass_known`；`phone_route`、`phone_table`、`phone_rules_only`、`kitchen`、`dock`；核对物品消耗、行动力、路线/情报与报价影响 |
| 桌上高级道具 | 笔记可记录仍在牌桌的已弃牌对手；信号估算一名有效对手牌力；两者消耗道具、增加风声及牌桌 revision | `advanced.notes`、`notes_folded`、`signal`；成功路径核对记录、提示、道具、热度与 revision，旧 revision 拒绝归 `advanced.stale_revision` |
| 预约接应 | 未出发、传错物品、仍在牌桌、无行动力、路线未知、已有有效预约、现金不足；成功预付及过期续约，手机切换方案不篡改原预约 | `reservation_coverage_test.gd` 对 `reservation.*` 11 个结果按四酒馆×两个方案核对费用、到期搜索序号、现金、行动力、完整 checkpoint 与原预约保留 |

当前局部目录共 **55 个语义结果，55 个有当前后继证据**：搜索 18、高级服务 26、预约 11。`SearchEvents.apply()` 在加风声时防御性封顶；风声已到 6 的探索态在世界层会触发强制撤离，不能把源码的 `mini(6, ...)` 直接当作额外玩家可达搜索结果。这里也不证明所有种子下连续整晚行动、世界射线/弹窗、AI 判断正确性或全局状态转移分母完整。源码或测试哈希变化后须重新核对；55/55 不可换算成全游戏覆盖率。
