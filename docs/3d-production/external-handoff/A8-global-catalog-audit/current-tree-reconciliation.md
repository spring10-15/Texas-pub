# A8 当前树对账记录

- 当前 HEAD：`0d63fee9725c0d78af99ced894fcba2d362740cc`
- 当前目录：388 个唯一 ID，SHA-256 `e498c9579659e5fb560b49663718de64b92891f45c4c543626983a20b3806269`
- 采用的全量回归：`output/3d/regression/20260925-124058/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`010fc8638e356205e6c174493f6f9ff4d9346ec4eb7b154814d03212d900d70f`
- lifecycle 覆盖报告 SHA-256：`e11ed7830f7c0e8d1942e2fd40448eaae10631a6f96edf3769b09747b3219763`
- 当前分支清单 SHA-256：`9c9b5eec170ec1264448fef1d0ba68fa909994c911ccaaa5a3888ad4ca92c13e`
- 当前玩家路径缺口清单 SHA-256：`123f09720d317c868670f8583efaee664f1c42c261421c1b0521139ddfe19109`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 对账脚本 SHA-256：`ce4606fd4e70152b9d7f5a25a04ff6e82eba3a95f89a2645f07aca5fcc32b7fa`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：388/388。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern` 与 `run_variant.room_layout_selected` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 23 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 140, 'catalogued_strong': 486, 'reachable_unmapped': 23, 'catalogued_weak': 18}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
