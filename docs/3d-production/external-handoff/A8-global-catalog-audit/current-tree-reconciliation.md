# A8 当前树对账记录

- 当前 HEAD：`246620ca7b930e640f6bae4a75f1e3fe59b7b267`
- 当前目录：394 个唯一 ID，SHA-256 `b257f6b78b9ae764f877782da8c698f2f42ebb024d22e3860e289df0ec402c19`
- 采用的全量回归：`output/3d/regression/20260925-143046/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`4222a146576a584544c27511119f81fa52dfc9b5b82121b2ad606ddcdd0da843`
- lifecycle 覆盖报告 SHA-256：`aeab5188980586031481a5a5b08e80c193f7085a78f418c60bf29f15faeda373`
- 当前分支清单 SHA-256：`3cab196c6c50b572df82518f6e36f4b37654893eb23f9221d80e42346ea17b2a`
- 当前玩家路径缺口清单 SHA-256：`b58779ab64ef986008257553f17357fbc2506a2985bd0d91651a6f568663a74e`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 对账脚本 SHA-256：`a348d8943ed575c3c20b8202f48a4fe7c5dfc9442ce6992b8a79a67d664b332d`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：394/394。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave`、`world.window_focus_out`、`player.look_changed`、`player.movement` 与 `world.window_close_request` 已在对应测试中登记；无目标 E 输入复用 `world.raycast_unfocused`，成功 E 输入由 captured 鼠标模式的窗口测试走完整 Player→World 信号链。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 12 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 141, 'catalogued_strong': 496, 'catalogued_weak': 18, 'reachable_unmapped': 12}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、窗口生命周期与玩家输入证据及明确的可达性/展示项分类。当前仍有 12 条候选需逐项审查；对账也没有重新审计全部 16 个源码文件。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
