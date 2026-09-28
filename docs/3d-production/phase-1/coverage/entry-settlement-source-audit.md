# 入座与结算的源码结果核对

2026-09-28 当前树局部审计。`run.gd` SHA-256：`2cd7ca0596ae84e32f83a707cf509361c002862b69e45f2fc96dfcc1d9d2c4ca`；`entry_coverage_test.gd`：`395d337dd8514bf5b51635ff9433dabada1fa6ab7f62f0a579485312d23cfd5e`；`settlement_coverage_test.gd`：`05faa4a2393dc0fdb13f98a910d3526a78d8f1ef670ba57202c85e7a412c15c6`。执行证据为 `output/3d/entry-coverage.json`、`output/3d/settlement-coverage.json` 及完整回归 `output/3d/regression/20260928-221245/report.json`。

一个 ID 表示有区别的拒绝或结算后继。这里从 `Run.enter_table()`、`Run.table_blocked_reason()`、`Run.settle_table()` 的条件及写入出发；桌内合法动作、派彩和奖励条件表的内部选择另有子图，不把它们混进入口局部分母。

| 入口 | 源码中的结果划分 | 目录与证据 |
|---|---|---|
| 入座前 | 旧 revision、未知桌、未出发、已有活动桌、该桌已完成、房间锁住、现金不足 | `entry.stale_revision`、`unknown_table`、`inactive`、`table_active`、`completed`、`locked`、`insufficient_cash`；每条拒绝均核对完整 Run checkpoint 不变 |
| 抵押前 | 桌规不允许抵押、未持有、持有但非贵重物 | `entry.collateral_disallowed`、`collateral_unowned`、`collateral_not_valuable`；拒绝不扣买入，也不移走物品 |
| 成功入座 | 扣买入、按酒馆桌规加风声并封顶、可选物品进入抵押；清空上一桌道具使用记录、预览牌及其手数标记，创建三座牌桌并增加 revision | `entry.success`、`entry.collateral`、`entry.heat_cap`；新断言确认旧 `preview_hand` 不会带入新桌 |
| 结算前 | 旧 revision、未出发、无活动桌、牌桌未结束 | `settlement.stale_revision`、`inactive`、`no_table`、`unfinished`；拒绝后完整 Run 不变 |
| 结算后 | 回收玩家筹码；按最终主池是否含玩家决定归还或失去抵押；净盈利时按 `rewardRules` 选择奖励，背包满则不入包，余烬桌盈利降风声；刷新行动力、完成桌序、搜索阶段、出口和 revision | 10 个 `settlement.*` 奖励结果，`break_even`、`loss`、`full_bag`、`collateral_lost`、`collateral_tie`、`side_pot_only`、`legacy_award`、`heat_relief`；18 个已结束牌桌结果夹具逐个核对财富并接入普通撤离，四桌奖励配置替换另作验证 |

本局部目录为 **35 个语义结果，35 个有当前后继证据**：入座 13、结算 22。新一局与入座原先只清空预览牌，未清空 `preview_hand`；复现断言曾使生命周期 `start.success` 和入座 `entry.success`、`entry.collateral` 失败，现已在两个入口重置为 0 并通过专项和全量回归。此处的结算结果大多由已结束牌桌夹具输入，不能据此证明每种奖励/抵押后继都能从合法牌局行动产生；四桌真实动作与跨进程整晚样本见[状态机记录](../state-machine.md)。源码或测试哈希变化后须重新核对本表，35/35 不代表全局 ≥95%。
