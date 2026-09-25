# A8 当前树对账记录

- 当前 HEAD：`7202b01cf573dc2d205a4b5357124d64b58877d0`
- 当前目录：384 个唯一 ID，SHA-256 `b3b3005d4e12fa3eec460cc1d710e23b59821d73d3858f50ffed90d8a0eb5bd6`
- 采用的全量回归：`output/3d/regression/20260925-111306/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`56ccd85660eacf595f427d444d83695a07a373dde0cacbe6b554149ef2550e94`
- lifecycle 覆盖报告 SHA-256：`bb788be714c5f6ac4289465ecc4d312894e95e2595e7868a8a9badff553127bb`
- 当前分支清单 SHA-256：`842e0cef38ac2de627eb95b5f25c620dee346ff55c1d2524a2e1466bb620d63b`
- 当前玩家路径缺口清单 SHA-256：`dbbfd18d6423de9d8e2c14e7b1ef075336dbfd008a9881e65d6c609bfcf0a21e`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：384/384。
- `start.partial_bankroll` 与 `entry.heat_cap` 已在 `lifecycle_coverage_test.gd` / `entry_coverage_test.gd` 中验证并从旧候选表归因到正式 ID。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 31 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 140, 'catalogued_strong': 478, 'reachable_unmapped': 31, 'catalogued_weak': 18}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的高风声入座封顶结果、修正明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```
