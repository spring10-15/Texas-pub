# A8 当前树对账记录

- 证据源码基线 HEAD：`98ef9e2fa006cc60621885e550e00b76c102139a`
- 当前目录：394 个唯一 ID，SHA-256 `b257f6b78b9ae764f877782da8c698f2f42ebb024d22e3860e289df0ec402c19`
- 采用的全量回归：`output/3d/regression/20260928-103143/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`87ac653a909aa42700a32e12d6f7920fe896634e1850a07f678d37467ef93d59`
- lifecycle 覆盖报告 SHA-256：`aeab5188980586031481a5a5b08e80c193f7085a78f418c60bf29f15faeda373`
- 当前分支清单 SHA-256：`22ad08544f29cf69aa7cddf1f88adc42f17fca0578e9ac6c2dc3b14c3d1fa653`
- 当前玩家路径缺口清单 SHA-256：`147f8235e3872dab602718ce1f2e01f3d12b4b7904831e7ca8257de90341b167`
- 当前弱证据清单 SHA-256：`147f8235e3872dab602718ce1f2e01f3d12b4b7904831e7ca8257de90341b167`
- 对账脚本 SHA-256：`8b79ebdd85e886b2e33ba59bb9ab6982f9c16cc1bfee8d30a4240ab4ad426ea4`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：394/394。
- 当前仍有 0 条标为玩家可达但尚未映射。
- 分支清单按字面有 115 条 `player_reachable=yes` 且没有独立 `catalog_id`；它们均有逐行归类说明，未计入当前未映射缺口。其中 53 条的 `outcome=accepted` 仅表示该源码分支可执行，不能单独证明它是独立游戏状态转移。
- 以本脚本生成的 394 项 overlay 为准；外部 triage 输入保留在 `current-tree-player-path-gaps.csv`，不是当前未映射清单。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave`、`world.window_focus_out`、`player.look_changed`、`player.movement` 与 `world.window_close_request` 已在对应测试中登记；无目标 E 输入复用 `world.raycast_unfocused`，成功 E 输入由 captured 鼠标模式的窗口测试走完整 Player→World 信号链。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`。吧台实体入口曾因缺少后置断言被列为弱证据；当前实体射线与 E 键集成测试已补足，映射到 `world.services_open`。试玩提示与 trace 文件 I/O 结果不改变权威状态，分别归为非状态转移；相关 I/O 错误注入未做专门测试。当前弱证据表有 0 行。
- 原 12 条世界/牌桌编排候选逐项复核后，实际状态后继归并到已有规则层 ID；纯 UI/调度包装早退标为 `not_a_transition`，不借用其他入口的 ID。没有新增语义 ID，也没有把 394 项目录宣称为完整分母；当前候选表无未映射行不等于证明不存在其他缺口，全球转移分母仍未冻结。
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
