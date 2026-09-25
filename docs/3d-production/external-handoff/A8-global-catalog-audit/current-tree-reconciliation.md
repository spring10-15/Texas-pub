# A8 当前树对账记录

- 当前 HEAD：`b686911d4d738ba51f0f0588ca43d04f463d0b7b`
- 当前目录：387 个唯一 ID，SHA-256 `c27c5fa39ef8424b989937d7ff2e4cbe1c032a70b5a1269a9346fa9c27836b67`
- 采用的全量回归：`output/3d/regression/20260925-121929/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`14fff115d023fa8cdaae624e1769fccbf0d7c61c7298d480ac5821fe22f1253c`
- lifecycle 覆盖报告 SHA-256：`0bf5a2b6629f0e1c0e640f3b58e6f518a2ba28fb25b7cf6ee9d47e0c9cc8a07b`
- 当前分支清单 SHA-256：`093eb55c701567aaf2d2cb16dd6497a5e3e9d85932259d269896349cc6ba1c6c`
- 当前玩家路径缺口清单 SHA-256：`6f0c18bd3299fbc5d50f0f32d66f831ba04f788e39fbb4f54e9ba1b0b07f80db`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 对账脚本 SHA-256：`8df9fbcf04b93567879f75ac6318f0f2ba00021bea6294efe42883871edf2deb`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：387/387。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern` 与 `run_variant.room_layout_selected` 已在对应测试中登记；搜索点与货架入口复用既有 `world.services_open` ID，并由真实锚点射线测试补强。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 26 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 140, 'catalogued_strong': 483, 'reachable_unmapped': 26, 'catalogued_weak': 18}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、搜索/货架入口证据及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
