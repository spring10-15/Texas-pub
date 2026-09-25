# 执行任务：A8 当前树可达缺口逐行核验

> 状态：已完成。审计开始时核验输入 30 行；其中房间图生成现映射到 `run_variant.room_layout_selected`，房间图的两个锁门拒绝路径以完整 Run 快照不变断言补强既有 `entry.locked`；短筹码盲注新增独立 `poker_blind.short_stack_posts`；固定种子起手牌与 RNG 后置新增 `poker_progress.seeded_deal`；开注后加注权保留断言补强既有 `poker_action.open`；暂停 KeyEvent 输入链补强既有 `world.pause`；玩家画像映射到 `poker.player_raise_pattern`；搜索和货架入口补强 `world.services_open`。E 交互输入信号下游映射至 `world.prop_on`，但 captured 鼠标门控仍属弱证据。当前树对账剩 19 条可达无 ID 候选、19 条弱证据项。历史 30 行逐条结果保留在 `current-tree-gap-triage.csv` / `.md`，当前基线见 `current-tree-reconciliation.md`。

## 目标

逐条复核 `current-tree-player-path-gaps.csv` 中的 30 行候选，判断它们是否确实是玩家/正常游戏调度可达、会改变权威状态、且没有被现有目录 ID 覆盖的独立结果。交付证据和分类，供主 Agent 决定是否增补目录与测试。

## 基线与边界

- 当前对账：`current-tree-reconciliation.md`，基线 HEAD `93e7ed6`，目录 385 项；如开始时 HEAD/目录哈希已变化，先记录新值，不要改写对账基线。
- 输入：`current-tree-player-path-gaps.csv`（当前 30 行）。必须核验文件中的全部行；实际行数以 CSV 为准。
- 只读审计：不改 Godot 代码、测试、`transitions.json`、正式存档或既有 A8 文件；不新增语义 ID。
- 不把“函数有分支”或“测试直接改字段构造状态”单独当成玩家可达证据。需要写明触发路径和前置状态来源；证据不足就标 `unknown`。

## 操作步骤

1. 读取 30 行候选及对应源码完整函数，记录当前源文件 SHA-256 和逐行位置。
2. 对每行检查调用链/UI/调度入口，判定前置状态能否由正常游戏流程到达；引用实际入口和必要前置，不以候选表自己的 `player_reachable` 列作为结论。
3. 检查后继是否改变权威 Run、Table、World 或持久化状态；把展示、格式化、纯查询、同一语义结果的重复分支排除或归并。
4. 与当前 385 个目录 ID、现有测试和覆盖报告比对，确认是否已有 ID 覆盖同一结果。明确区分“缺 ID”与“已有 ID 但测试证据不足”。
5. 为每行给出分类、理由、源码/测试/报告锚点及建议动作（新增测试、映射已有 ID、并入同义结果、排除或继续调查）。不确定时写清缺的证据。
6. 检查交付表恰有一行对应每个输入候选，无遗漏、重复或臆造的源行；所有路径真实存在，行号落在源码文件内。

## 分类值

- `confirmed_distinct_gap`：玩家/正常调度可达，权威状态发生变化，且现有目录没有同义 ID。
- `existing_id_needs_evidence`：已有目录 ID 对应同一语义，当前缺的是后置断言或覆盖报告。
- `same_outcome_merge`：输入条件不同但后继语义相同，应归并到现有结果。
- `not_state_transition`：没有权威状态改变。
- `not_player_reachable`：仅由损坏/篡改内部状态、不可触发防御调用等制造。
- `unknown`：现有证据不能支持以上判定。

## 交付物

- `current-tree-gap-triage.csv`：与输入字段兼容，至少保留 `source_file`、`entry`、`source_line`、`catalog_id`，并添加 `triage_status`、`reachability_evidence`、`state_change_evidence`、`existing_id_check`、`recommended_action`、`review_notes`。
- `current-tree-gap-triage.md`：基线 HEAD/目录哈希、输入行数、各分类计数、主要重复/归并建议、未知项及复验方式。
- 在说明中记录输入 CSV SHA-256 与源码文件 SHA-256；不得把旧的 382 项审计结果写成当前结论。

## 完成标准

- 输入 CSV 每行恰有一个分类和可复核的理由。
- 只有 `confirmed_distinct_gap` 能作为新增 ID 候选；不直接编辑目录或代码。
- 所有引用路径存在、行号有效，计数之和等于输入行数。
- 明确声明本审计不等于全局目录完备，也不等于 Phase 1 通过。
