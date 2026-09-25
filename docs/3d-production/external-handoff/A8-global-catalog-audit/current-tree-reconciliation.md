# A8 当前树对账记录

- 当前 HEAD：`ef7cf22cc8bcc793e8deff041cc31a724b5eba3e`
- 当前目录：389 个唯一 ID，SHA-256 `effd1c79cc02772b317e8b1ba67013c569ec02c99c729e6b65a973d7c1164002`
- 采用的全量回归：`output/3d/regression/20260925-130005/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`48c157323c1a9ac67cf56c68833f2f50b91289343d8b6a70acce9eceb3e2f1d7`
- lifecycle 覆盖报告 SHA-256：`6bfe43fd4543b54570553708ff53df97cbaa9b8d8b9513ddc3e559d100bd08dc`
- 当前分支清单 SHA-256：`7cbcdad5e6910f868f197d7be9d0167a9a125050f5cbcc98071af63f5e1a9990`
- 当前玩家路径缺口清单 SHA-256：`96c81b3cf9e1ebbce7a58101c653aa1884e69fa942a44aacd1b51efdde9c0207`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 对账脚本 SHA-256：`5aed760590f6ae4541890e1f9fc61b2de6678d973393a7e44aee1c15c53d3674`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：389/389。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern` 与 `run_variant.room_layout_selected` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 21 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 140, 'catalogued_strong': 488, 'reachable_unmapped': 21, 'catalogued_weak': 18}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
