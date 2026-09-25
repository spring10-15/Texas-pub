# 执行任务：A8 当前目录归因复核

> 状态：主 Agent 已完成当前树对账（386 个 ID 全映射；29 条可达无 ID 候选、18 条弱证据项继续待核）。产物见 [current-tree-reconciliation.md](current-tree-reconciliation.md) 与三份 `current-tree-*.csv`。本任务书保留为验收范围记录，无需再分派。

## 目标

在 A8 原报告冻结的 382 项目录基础上，生成一份可独立复验的**当前工作区归因增量**。当前 `transitions.json` 有 386 个 ID，已登记 `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief` 与 `poker.player_raise_pattern`；原报告仍作为 382 项锚点快照保留，不覆盖、不重写。

## 操作步骤

1. 读取现有 `README.md`、三份 CSV、`output/external-handoff/A8/build_a8.py` 与校验结果，核对当前 `transitions.json` 和当前源码/测试。
2. 以当前目录快照为基线，复核 `branch-inventory.csv` 中的每个目录 ID 至少有一条有效归因；将新增 ID 改记为已登记，并附当前测试和回归报告。
3. 逐条复核原 `unmapped-reachable.csv` 的 40 行。至少将其中 6 条 `player_reachable=no` 的恢复/存档防御分支从“玩家可达缺口”计数中剔出，单独标为非玩家路径、条件性系统拒绝或待证据项，并写明判定依据。不要只按列值机械搬行；保留真实文件加载入口与损坏数据场景的边界说明。
4. 对剩余每条候选确认当前源码行、真实可达路径、后继权威状态、测试断言及证据报告；无法确认时标 `unknown`，不要猜测或直接新增目录 ID。
5. 生成新的 current-tree 清单与短说明，记录当前 HEAD、目录 SHA-256、Godot 版本、源码/测试哈希、命令与结果。明确当前分母仍未冻结、不得宣称 Phase 1 通过。
6. 运行构建/校验脚本并检查所有路径、行号、catalog ID、行数和 SHA-256；确保输出可重复。原 382 项冻结产物保持原样。

## 交付物

- `current-tree-branch-inventory.csv`
- `current-tree-player-path-gaps.csv`
- `current-tree-weak-evidence.csv`
- `current-tree-reconciliation.md`（基线、分类变化、复验命令/结果、限制）
- 更新后的校验脚本或一个独立 current-tree 校验器（如现有脚本不能支持新锚点，避免破坏旧锚点复验）
- SHA-256 清单及机检输出

## 完成标准

- 385 个当前目录 ID 全部且仅按有效行映射；没有旧 `382/382` 被误称为当前结论。
- 所有“未映射可达”行均有 `player_reachable=yes` 或逐条解释为何属游戏调度可达；不可达/未知项不计入可达缺口总数。
- `start.partial_bankroll`、`entry.heat_cap` 与 `settlement.heat_relief` 有当前强证据归因。
- 任何当前源码/目录变化都能被哈希和校验器识别；旧锚点报告仍可原样复验。
- 没有修改游戏逻辑、覆盖目录、测试、正式存档或生成资产。
