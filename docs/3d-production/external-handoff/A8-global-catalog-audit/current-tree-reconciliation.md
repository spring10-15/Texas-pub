# A8 当前树对账记录

- 当前 HEAD：`3f2c48b23a7fb93b354e9dbdf7af405b3bd7ef8c`
- 当前目录：387 个唯一 ID，SHA-256 `c27c5fa39ef8424b989937d7ff2e4cbe1c032a70b5a1269a9346fa9c27836b67`
- 采用的全量回归：`output/3d/regression/20260925-123042/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`59576f1583034230a4521994423e15b4cfb61136b88b8951f116ad259ae550a5`
- lifecycle 覆盖报告 SHA-256：`0bf5a2b6629f0e1c0e640f3b58e6f518a2ba28fb25b7cf6ee9d47e0c9cc8a07b`
- 当前分支清单 SHA-256：`c546afeb1f4cf4cca100a6c7b8a6a46b385b1c364c45b35f93dce6f93db37ec4`
- 当前玩家路径缺口清单 SHA-256：`9b9346670af88f6fa8469593e59701ef4e0c912dbc270ade5a0f7ebbb9d7b004`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 对账脚本 SHA-256：`8913ca2000cafdfcab2f61126ac6c5cdd89e5b2fc80dac9c05a81bb902a92c59`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：387/387。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern` 与 `run_variant.room_layout_selected` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 24 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 140, 'catalogued_strong': 485, 'reachable_unmapped': 24, 'catalogued_weak': 18}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
