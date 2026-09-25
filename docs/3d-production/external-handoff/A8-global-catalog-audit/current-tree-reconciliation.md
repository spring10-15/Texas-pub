# A8 当前树对账记录

- 当前 HEAD：`ff024b05ad8a791f6d431094188a786acb99a1a8`
- 当前目录：391 个唯一 ID，SHA-256 `f54db0abb995b9a16a6a6a5398853692ea59f4fa6d0e7348ee18e3580c6c8784`
- 采用的全量回归：`output/3d/regression/20260925-140209/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`b61570e5a4e1d4d068e59d36353c2e2b8a507f802c03b0c160cfc7e449a281c1`
- lifecycle 覆盖报告 SHA-256：`7bb90a865cf003f4b916acf47af5159312cfc521b7a8a3e4a96bc72bba92269e`
- 当前分支清单 SHA-256：`bad731d6b56d1b9bcadb721ec720ded78be7527e9b8d5d05c015bb5b2800087b`
- 当前玩家路径缺口清单 SHA-256：`9e0a5343fdeba81871b4161a316ca3932e69955e3912d905b65c84492eb3d3fd`
- 当前弱证据清单 SHA-256：`585aa25d450f91dcc6be6ee0d0e576218e4ca99bc1957e686b0b37fc7f668988`
- 对账脚本 SHA-256：`b0911b3fb8f3d5a0fcf12b112b4027871b5e64d46d1dbd650b6d7799cf9295a3`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：391/391。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave` 与 `world.window_focus_out` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 16 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 141, 'catalogued_strong': 491, 'catalogued_weak': 19, 'reachable_unmapped': 16}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
