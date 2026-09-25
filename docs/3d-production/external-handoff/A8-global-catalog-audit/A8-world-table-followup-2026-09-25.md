# A8 世界/牌桌编排后继取证补记

本补记执行《执行任务A8-世界牌桌编排后继取证-2026-09-25.md》的固定语义归属。外部复核原始输入 `current-tree-player-path-gaps.csv` 与 triage 交付保持不变；最新主线未映射结果另存为 `current-tree-unmapped-player-path-gaps.csv`。

| 源码锚点 | 判定 | 既有 ID | 后继证据 |
| --- | --- | --- | --- |
| `world.gd:635-636` `start_table` 早退 | `not_a_transition`；可用 UI 状态不会触发该早退，不映射规则拒绝 ID | — | `table_integration.gd` 重复开局时资金不变；开始后桌面面板刷新，暂停/未入座无可用开局控件 |
| `world.gd:642-645` 开局成功 | 规则层结果 | `entry.success` | 真实桌局启动后 buy-in 仅扣一次且 table 创建成功 |
| `world.gd:648-649` `play_action` 早退 | `not_a_transition`；UI/节拍输入锁包装 no-op | — | 暂停、服务面板、双击节拍锁下 revision 不变 |
| `world.gd:653-656` `play_action` 成功 | 规则层结果 | 对应 `poker_action.*` | 实际 HUD 按钮提交合法动作，revision 恰增一次 |
| `world.gd:658-662` 下一手 | 规则层结果 | `poker_progress.next_hand` | 下一手 HUD 信号启动第二手，牌局推进至终局 |
| `world.gd:670-671` 服务面板时 `_process` 早退 | `not_a_transition`；面板 guard 自身已登记，此处不重复计数 | — | AI 回合打开服务面板后执行 `_process`，完整 checkpoint 不变 |
| `world.gd:672-673` 无桌/暂停/未入座早退 | `not_a_transition` | — | 暂停时牌桌 revision 不变；其余状态不产生权威状态后继 |
| `world.gd:681` `_process` 节拍派发 | 规则层结果 | `poker_action.*` / `poker_progress.*` | 牌桌完整流程改由 `World._process` 驱动；每个 AI/街道节拍都断言 revision +1 且公开状态变化 |
| `world.gd:684-685` `advance_table_beat` 守卫 | `not_a_transition` | — | 服务面板打开时直接调用后完整 checkpoint 不变 |
| `world.gd:687-688` 空行动者调用 `advance` | 规则层结果，证据弱 | `poker_progress.*` | 完整牌局观察到 World 调度状态后继；尚未单独构造 empty-actor 调用点断言 |
| `world.gd:690-692` AI 策略行动 | 规则层结果 | `poker_action.*` | 固定牌桌 seed 下由 World 节拍执行真实 AI 行动并逐拍验证状态变化 |
| `world.gd:1047-1051` 强制风声回撤 | 复用已有组合结果 | `world.leave_forced_pressure_exit`、`world.services_close`、`world.travel_landing` | 酒保面板执行有效情报服务动作后，服务面板关闭、玩家回到藏匿点并显示强制失败与损失 |

本轮三个定向 Godot 测试及全量回归通过。全量报告为 `output/3d/regression/20260925-145158/report.json`（64/64）；覆盖汇总器仍为 394/394，语义目录没有新增 ID。A4 为 70/72 有后继证据、2 条不可达；A5 为 50 行、40/40 目录 ID 映射；A7 独立核验 24 项确认、0 反证。

这些结果只处理已列候选，不能证明全部源码状态转移已被枚举。目录仍为 `incomplete_catalog`，没有整体覆盖率或 Phase 1 通过结论。
