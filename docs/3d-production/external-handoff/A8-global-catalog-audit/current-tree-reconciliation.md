# A8 当前树对账记录

- 当前 HEAD：`86672d6351e5de5760061ca37be208ef020152d6`
- 当前目录：394 个唯一 ID，SHA-256 `b257f6b78b9ae764f877782da8c698f2f42ebb024d22e3860e289df0ec402c19`
- 采用的全量回归：`output/3d/regression/20260925-145158/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`abc9fd11ff30949a1e2d79ed3090bfdf2bfd52fd0ac10c7331ace79d6794e2ce`
- lifecycle 覆盖报告 SHA-256：`aeab5188980586031481a5a5b08e80c193f7085a78f418c60bf29f15faeda373`
- 当前分支清单 SHA-256：`ee7436fe477853cceac572501f73c55f4e5cb61c2769a1c2b7457cc6c6732a7e`
- 当前玩家路径缺口清单 SHA-256：`147f8235e3872dab602718ce1f2e01f3d12b4b7904831e7ca8257de90341b167`
- 当前弱证据清单 SHA-256：`4eb00bea67202c3488afbf6d993f86c0846a58ff1d408db2dde9946c14178a54`
- 对账脚本 SHA-256：`867b784f443da17cd42e77d36c4d0a3e8ecfd088fda0783f2a78a0d37ee50b61`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：394/394。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave`、`world.window_focus_out`、`player.look_changed`、`player.movement` 与 `world.window_close_request` 已在对应测试中登记；无目标 E 输入复用 `world.raycast_unfocused`，成功 E 输入由 captured 鼠标模式的窗口测试走完整 Player→World 信号链。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 原 12 条世界/牌桌编排候选逐项复核后，实际状态后继归并到已有规则层 ID；纯 UI/调度包装早退标为 `not_a_transition`，不借用其他入口的 ID。没有新增语义 ID，也没有把 394 项目录宣称为完整分母；当前候选表无未映射行不等于证明不存在其他缺口，全球分母仍未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 146, 'catalogued_strong': 502, 'catalogued_weak': 19}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、窗口生命周期、玩家输入和世界/牌桌编排证据及明确的可达性/展示项分类。它没有重新审计全部 16 个源码文件，也没有穷举组合状态空间，因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
