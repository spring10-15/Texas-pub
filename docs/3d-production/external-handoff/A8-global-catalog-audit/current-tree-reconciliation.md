# A8 当前树对账记录

- 当前 HEAD：`a310617854a9fe34259d47552686e6e1e78445fd`
- 当前目录：390 个唯一 ID，SHA-256 `4a44d69efe231b63ffd45814a7b5cc11d11a732acded093cbe985e1d8d685f51`
- 采用的全量回归：`output/3d/regression/20260925-134024/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`69a503dda9e17ab3261d7d3456ccbb2419139ebce88338d231334ac6bdd69ccc`
- lifecycle 覆盖报告 SHA-256：`272a67808f2ad4a5aacd44fce3258679361bff869065a5c782ce4be67a62ab1b`
- 当前分支清单 SHA-256：`190012684658f1f4c8ed1099eb3e2def1f2d8b593e3bcde6b2f5009b0569e792`
- 当前玩家路径缺口清单 SHA-256：`54a6b41455249ecb9341283c820b944189665e98bd307081a12368b5c6edef07`
- 当前弱证据清单 SHA-256：`6613f15d10e3df83d1ce539185644b94d00f3a8b5b276a2ab5c9346e8a5e4259`
- 对账脚本 SHA-256：`66423fdcb7b57b9c058e60df09262a22a10706862042b273f260f7e29d70ee01`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：390/390。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal` 与 `world.autosave` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 17 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 141, 'catalogued_strong': 490, 'catalogued_weak': 19, 'reachable_unmapped': 17}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
