# A8 当前树对账记录

- 当前 HEAD：`93e7ed685c875cd5d91cc15ecce9d0fb8b797839`
- 当前目录：386 个唯一 ID，SHA-256 `5a87300ddea8a3ecb03a883e7973bcf930b87312cfc124faa71a08d83b2d5187`
- 采用的全量回归：`output/3d/regression/20260925-113720/report.json`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`3d165e01a86dae792c71ea4b8e0c20c740d98a8815c699db630d03ab368f9ae7`
- lifecycle 覆盖报告 SHA-256：`3a571e898264d5b6b388095e839408cdc6943063dc4034f16fc30a146e87c85d`
- 当前分支清单 SHA-256：`7643199a40f05f6b1deab6e7fb6aa658a02e62ccb80781e9c96b36b631c8e6eb`
- 当前玩家路径缺口清单 SHA-256：`417cff7cb5f9bd794e892b3d8e2b7acd1d333e0185fe1c0c2e5be5848be7df19`
- 当前弱证据清单 SHA-256：`0e041b2f1e3bea08849e6ec08243ef4552f6fdb7943adc04994f64f0156a1214`
- 对账脚本 SHA-256：`407ed259f1d2cb083cf72248c472bb54f24b57603694d74baf6e5ac0d4253afa`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：386/386。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief` 与 `poker.player_raise_pattern` 已在对应 lifecycle、entry、settlement 和 poker 覆盖测试中验证并从旧候选表归因到正式 ID。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 当前仍有 29 条标为玩家可达、尚无目录 ID 的候选，详见 `current-tree-player-path-gaps.csv`。这仍需逐条审查后才能新增语义 ID；全局分母尚未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{'unreachable_or_not_transition': 140, 'catalogued_strong': 480, 'reachable_unmapped': 29, 'catalogued_weak': 18}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入已验证的本金封顶、入座风声封顶、盈利降风声、玩家行为画像结果及明确的可达性/展示项分类。它没有重新逐行审计全部 16 个源码文件，也没有证明剩余候选均是独立状态转移。因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的 385 项 overlay 为准。
