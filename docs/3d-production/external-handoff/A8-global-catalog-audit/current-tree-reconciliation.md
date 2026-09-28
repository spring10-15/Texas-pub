# A8 当前树对账记录

- 证据源码基线 HEAD：`c24bcfa8d0afa70e34eb64ac214bce76856e90a8`
- 当前目录：384 个唯一 ID，SHA-256 `5fe6e79c154d648f5905bfdf1d90ea253eeacc7f6e182b24aa4f14ba7431abc9`
- 采用的全量回归：`output/3d/regression/20260928-113749/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`708204023bec0289aec6988683c92b05f60abda0c9f03263b77e549975125776`
- lifecycle 覆盖报告 SHA-256：`6e89f52f23f5920a1b4370584a12bcb16dab95dbfb4406f930b0b462ab7a9777`
- 当前分支清单 SHA-256：`7db01d7f20c6a9f540143d65e83299b62adb86029bc58a376b45efcde8053012`
- 当前玩家路径缺口清单 SHA-256：`147f8235e3872dab602718ce1f2e01f3d12b4b7904831e7ca8257de90341b167`
- 当前弱证据清单 SHA-256：`147f8235e3872dab602718ce1f2e01f3d12b4b7904831e7ca8257de90341b167`
- 对账脚本 SHA-256：`a6e498ea21bff38a5d16981374e9b87229651f40337ed14f4e3d80473ee51759`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：384/384。
- 当前仍有 0 条标为玩家可达但尚未映射。
- 分支清单按字面有 115 条 `player_reachable=yes` 且没有独立 `catalog_id`；它们均有逐行归类说明，未计入当前未映射缺口。其中 53 条的 `outcome=accepted` 仅表示该源码分支可执行，不能单独证明它是独立游戏状态转移。
- 以本脚本生成的 384 项 overlay 为准；外部 triage 输入保留在 `current-tree-player-path-gaps.csv`，不是当前未映射清单。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave`、`world.window_focus_out`、`player.look_changed`、`player.movement` 与 `world.window_close_request` 已在对应测试中登记；无目标 E 输入复用 `world.raycast_unfocused`，成功 E 输入由 captured 鼠标模式的窗口测试走完整 Player→World 信号链。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`。吧台实体入口曾因缺少后置断言被列为弱证据；当前实体射线与 E 键集成测试已补足，映射到 `world.services_open`。试玩提示与 trace 文件 I/O 结果不改变权威状态，分别归为非状态转移；相关 I/O 错误注入未做专门测试。当前弱证据表有 0 行。
- `persistence_replay.rng_negative_control` 是测试侧人工扰动的负对照，现已从 `transitions` 移至 `verification_controls`；它仍作为正向重放断言的非空检查，但不再增加状态转移目录计数。
- 五条 `route_guard.cash_*` 历史 ID 与 `route_guard.cash_general` 共用 `routes.gd:49-50` 的同一拒绝后继；当前 overlay 将它们归并到该单一 ID，六条路线仍由同一专项逐项验证。
- 原 12 条世界/牌桌编排候选逐项复核后，实际状态后继归并到已有规则层 ID；纯 UI/调度包装早退标为 `not_a_transition`，不借用其他入口的 ID。没有新增语义 ID，也没有把 393 项目录宣称为完整分母；当前候选表无未映射行不等于证明不存在其他缺口，全球转移分母仍未冻结。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 150, 'catalogued_strong': 522}`。

## 限制

当前树对账把原 382 项审计映射到现行目录，并补入本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、窗口生命周期、玩家输入和世界/牌桌编排证据。函数级清点覆盖 20 个运行时文件、177 个函数（120 个在分支清单中，57 个为明确排除，未分类 0 个）；这只证明函数入口都有归属，不代表分支结果穷尽。玩家路径分母和状态组合空间仍未冻结，因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
