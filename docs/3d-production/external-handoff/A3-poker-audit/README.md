# A3 扑克状态转移分母取证

> **主 Agent 当前复核补记（2026-09-25）**：本文为 2026-09-23 的历史审计快照，原基线登记 291 项。后续已补齐四桌 × 三座位的短额/精确跟注全押、短额全押加注和单一有筹码者队列变体；`pending_families.poker` 当前为空，目录为 357 项。A3 的 7 项核验仍验证其 CSV 映射与原始边界结论，不代表当前扑克完整转移分母已封板，也不证明全局 ≥95% 覆盖率。

任务书原文：`docs/3d-production/external-handoff/任务A3-扑克转移分母取证-2026-09-23.md`。

**本任务只取证，不改规则、不改覆盖目录、不宣布 Phase 1 通过。** 全程只读生产代码与既有测试；只新增本目录文件与 `output/external-handoff/A3/` 下的诊断日志；未提交、未推送。

---

## 1. 基线

| 项 | 值 |
| --- | --- |
| HEAD | `07f22459ffb341a0d5246818c5e9f3270c7d5bac` |
| Godot | `/Applications/Godot.app/Contents/MacOS/Godot`，`4.7.2.stable.official.ed1daf0bf`（PATH 中无 `godot` 命令） |
| `Godot/three_d/rules/table.gd` | 210 行 |
| `Godot/three_d/rules/poker.gd` | 156 行 |
| `Godot/three_d/rules/table_checkpoint.gd` | 58 行 |
| `docs/3d-production/phase-1/coverage/transitions.json` | `schema`=1，`status`="incomplete_catalog"，`transitions` 长度 291 |

开工时 `git status --short`（收工时复核一致，只有未跟踪项，**无任何已跟踪文件被修改**）：

```
?? .workbuddy/
?? docs/3d-production/blender接续核对-2026-09-21.md
?? docs/3d-production/external-handoff/A-regression/
?? docs/3d-production/external-handoff/A2-boundaries/
?? docs/3d-production/external-handoff/A3-poker-audit/          <- 本任务新增
?? docs/3d-production/external-handoff/B-content-assets/
?? docs/3d-production/external-handoff/B2-production-breakdown/
?? docs/3d-production/external-handoff/C-acceptance/
?? docs/3d-production/external-handoff/V1-extraction-visual/
?? docs/3d-production/external-handoff/对抗性审查-B1C1-2026-09-22.md
?? docs/3d-production/inventory/
?? docs/3d-production/并行开发分工.md
?? poker-tavern-code-review/
?? videos/
?? 德扑酒馆/
```

（`output/` 被 `.gitignore` 忽略，故本任务的日志不进入 `git status`。）

---

## 2. 使用的命令（原样可复现）

```sh
cd "/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安"

git rev-parse HEAD
git status --short
/Applications/Godot.app/Contents/MacOS/Godot --version

# 六条边界的独立只读探针（本任务新增）
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/A3/probe-boundaries.log --timeout 180 \
  -- --script "/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/A3-poker-audit/repro/probe_boundaries.gd" -- --test

# 既有回归：单挑庄位轮换（该脚本不写任何报告文件）
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/A3/existing-dealer_rotation.log --timeout 180 \
  -- --script res://three_d/tests/dealer_rotation_test.gd -- --test
```

- 用户参数分隔符 `--` 必须原样保留：本机 Godot 未开 `tests=yes`，`--test` 一旦被 Godot 自己吃掉会直接 abort。
- **未运行**会写 `output/3d/` 下报告文件的既有覆盖套件（`Godot/three_d/tests/short_stack_queue_test.gd`、`poker_guard/poker_action/poker_progress/payout/table_endings` 等）。硬约束只允许写 `output/external-handoff/A3/`，而这些套件会把报告写进 `output/3d/`（其他 Agent 的证据产物）。这些套件的断言改为逐行静态核对，并由本任务探针独立复核同一批字段；`Godot/three_d/tests/dealer_rotation_test.gd` 不写文件，故实际执行。

---

## 3. 计数口径

- 分母是**不同语义结果的条数**，不是断言条数、测试项数或静态检查次数。
- 拒绝结果必须是同一状态上的**自环**：`Checkpoint.capture()` 完整不变（`state` + `revision` + `rngValue`，见 `Godot/three_d/rules/table_checkpoint.gd:5-6`）。
- 成功结果必须点名**实际受影响的字段**（筹码、底池、行动队列、街道、庄位、RNG）。
- 不因源码存在一个 `if` 就记一条可达结果；判断不可到达时写明被哪条前置守卫排除。
- 不同种子/数值但后继状态等价的样本不重复计数（本任务显式核过 `short_all_in` 与 `exact_call_all_in` 的后继状态不同）。

**先读代码建立因果链，再决定要不要写探针。** 六条边界的可达性、受影响字段、拒绝规则均可由 `Godot/three_d/rules/table.gd` 的确定性代码直接推出（最短路径 210 行），因此**只**为「既有测试未覆盖的空档」与「疑似不一致的最短复现」写了 `docs/3d-production/external-handoff/A3-poker-audit/repro/probe_boundaries.gd`。

---

## 4. 六项逐条结论

| # | 边界 | 现有目录 ID | 现有测试 | `evidence_status` |
| --- | --- | --- | --- | --- |
| 1 | `short_all_in` | `queue.short_all_in` | `Godot/three_d/tests/short_stack_queue_test.gd:28-34` | 已登记且有后继状态证据 |
| 2 | `exact_call_all_in` | `queue.exact_call_all_in` | `Godot/three_d/tests/short_stack_queue_test.gd:28-34`；`Godot/three_d/tests/table_parity.gd:33-48`（夹具 `Godot/three_d/tests/table-fixtures.json` 用例 30/35/36/55/72/80/109） | 已登记且有后继状态证据 |
| 3 | `queue_reopen` | `queue.raise_reopens_prior_caller`（加注分支） | `Godot/three_d/tests/short_stack_queue_test.gd:40-43` | 已登记且有后继状态证据 |
| 3b | `queue_reopen`（全押分支） | **无** | `Godot/three_d/tests/short_stack_queue_test.gd:58-60`（间接） | 有测试但未登记 |
| 4 | `lone_funded_queue` | `queue.lone_funded_owes` / `queue.lone_funded_matched` / `queue.lone_funded_runout` / `queue.runout_showdown_conserves` | `Godot/three_d/tests/short_stack_queue_test.gd:58-61` / `Godot/three_d/tests/short_stack_queue_test.gd:63-65` / `Godot/three_d/tests/short_stack_queue_test.gd:67-75` / `Godot/three_d/tests/short_stack_queue_test.gd:77-81` | 已登记且有后继状态证据（4 条） |
| 5 | `aggression_discount` | **无**（效果被 `poker_action.raise/open/custom_raise` 隐含；边界被 `poker_guard.open_short/raise_short/matched_raise_short` 登记） | `Godot/three_d/tests/table_test.gd:66-67`；`Godot/three_d/tests/raise_preview_test.gd:38-48`；`Godot/three_d/tests/poker_action_coverage_test.gd:30-38`；`Godot/three_d/tests/poker_guard_coverage_test.gd:29-39` | 首次进攻折扣本身：有测试但未登记；只减一次：未找到测试（本任务探针补证） |
| 6 | `next_hand_heads_up` | **无**（目录只有三人桌 `poker_progress.next_hand`） | `Godot/three_d/tests/dealer_rotation_test.gd:24-44`；`Godot/three_d/tests/table_test.gd:84-89` | 有测试但未登记 |

逐条说明：

**1. `short_all_in`（已登记且有后继状态证据）**
`Godot/three_d/rules/table.gd:109-116` 的 `all-in` 分支：`amount = player.stack`，`target = currentBet + amount`，`reset_queue = target > state.currentBet`。当 `0 < stack < 欠注额` 时 `target < state.currentBet`，故**不抬高目标额、不置 `raiseUsed`、不重开队列**。后继状态（探针 cargo-table：欠 20、stack 19）：`stacks[0] 19→0`、`bets[0] 0→19`、`contribs[0] 0→19`、`pot 30→49`、`toAct` 前移一位、`turnCounter+1`、`revision+1`；未受影响：`state.currentBet`、`raiseUsed`、`street`、三处庄位、`community`、`deck`、`rng.value`。`Godot/three_d/tests/short_stack_queue_test.gd:28-34` 显式断言 stack、底池增量、currentBet 不变、队列、`raiseUsed`、RNG+牌堆不变、`revision+1` 与总财富守恒。

**2. `exact_call_all_in`（已登记且有后继状态证据）**
`Godot/three_d/rules/table.gd:106-108` 的 `call` 分支，`amount = currentBet - player.currentBet`，当 `stack == 欠注额` 时筹码归零。后继状态与 #1 是**不同语义结果**：底池与 `handContribution` 各差 1（探针 `pot_delta` 20 vs 19），故按口径不重复计数。`stack == 欠注额` 时 `call` 与 `all-in` 命令的后继状态等价，也不另计一行（探针已核）。另有独立证据链：`Godot/three_d/tests/table-fixtures.json` 由 `src/game.js` 的 JS 参考实现生成（`Godot/three_d/tests/generate_table_fixtures.mjs`），`Godot/three_d/tests/table_parity.gd:33-48` 逐字段比对 `pot/currentBet/street/toAct/各席 stack-currentBet-handContribution`。

**3. `queue_reopen`（加注分支：已登记且有后继状态证据；全押分支：有测试但未登记）**
加注分支 `Godot/three_d/rules/table.gd:88-103` 成功时 `reset_queue = true`，`Godot/three_d/rules/table.gd:130` 用 `set_queue(ordered_after(actor.seatIndex, false))` 按加注者座位重排队列。`Godot/three_d/tests/short_stack_queue_test.gd:40-43` 断言 `toAct == [ledger-clerk, player]`，并在后位跟注后断言原跟注者重新成为 `currentActorId`（等价于断言目标额确实被抬高）。
全押分支 `Godot/three_d/rules/table.gd:109-116` 在 `target > state.currentBet` 时同样 `reset_queue = true` + `raiseUsed = true`，是**不同源码分支**（`Godot/three_d/rules/table.gd:113-116`，不是 `102-103`），后继状态同型但由不同命令到达。本目录对命令粒度一贯分开登记（`poker_action.open/raise/custom_raise` 各自成 ID），故列为独立语义结果；若主 Agent 采「后继状态等价」口径可与之合并。现有证据是间接的：`lone_funded` 夹具里首个对手全押抬高目标，随后 `toAct == ["player"]` 的断言体现了重开，但没有以「全押重开队列」命名的 ID 或专门断言。

**4. `lone_funded_queue`（4 条，均已登记且有后继状态证据）**
守卫在 `Godot/three_d/rules/table.gd:139-141`：仅当唯一有筹码者的 `currentBet >= state.currentBet` 时才清空可用队列。对应四个语义结果：
- `queue.lone_funded_owes`：仍有欠注 → `toAct == ["player"]`、`currentActorId == "player"`（`Godot/three_d/tests/short_stack_queue_test.gd:58-61`）；
- `queue.lone_funded_matched`：补平 → `toAct == []`、`currentActorId == ""`（`Godot/three_d/tests/short_stack_queue_test.gd:63-65`）；
- `queue.lone_funded_runout`：逐街 `advance`，`street/community/deck` 按 3/1 张推进，`toAct` 保持空、底池与 `rng.value` 不变（`Godot/three_d/tests/short_stack_queue_test.gd:67-75`）；
- `queue.runout_showdown_conserves`：河牌 `advance` 触发 `Godot/three_d/rules/poker.gd:131-156` 的 `settle_pots`，`status→hand_over`、`summary.kind=="showdown"`、awards 合计等于底池、三席 `stack` 合计等于 `3×buyIn`（`Godot/three_d/tests/short_stack_queue_test.gd:77-81`）。

**5. `aggression_discount`（折扣本身：有测试但未登记；只减一次：未找到测试）**
`Godot/three_d/rules/table.gd:94-96` 在 `raise` 分支内消耗 `firstAggressionDiscountAvailable` 并扣减实付；`Godot/three_d/rules/table.gd:66-75` 用折扣后的 `open_cost/raise_cost` 决定 `legal_actions.raise`。货运桌（唯一带折扣的桌）配置为 `firstAggressionDiscount=10`，其余三张桌无此字段。
既有测试覆盖：`Godot/three_d/tests/table_test.gd:66-67`（断言 `stack==30`、`currentBet==40`、标志已消耗）、`Godot/three_d/tests/raise_preview_test.gd:38-48`（隔离桌把折扣临时改成 5，断言预览文案、实际扣款与标志一次性）、`Godot/three_d/tests/poker_action_coverage_test.gd:30-38`（把折扣计入预期扣款并核对 `pot/currentBet/stack`）、`Godot/three_d/tests/poker_guard_coverage_test.gd:29-39`（三条守卫夹具用 `-(10 if firstAggressionDiscountAvailable else 0)` 把「恰好等于折扣后成本」作为边界，并比较 `Checkpoint.capture(t) == before`）。
**目录中没有以「首次进攻折扣」为名的 ID**：它目前只是 `poker_action.raise/open/custom_raise` 的隐含修正量，而这三条 ID 的断言并未单独校验标志翻转（`Godot/three_d/tests/poker_action_coverage_test.gd` 未断言 `firstAggressionDiscountAvailable`）。「第二次进攻按全额扣款」与「`call` 不消耗标志」既有测试**均未覆盖**，由本任务探针补证。

**6. `next_hand_heads_up`（有测试但未登记）**
`Godot/three_d/rules/table.gd:184-189` 的 `next_hand` 调 `start_hand(true)`，庄位在 `Godot/three_d/rules/table.gd:35-36` 轮转到下一名仍有筹码的玩家（不再按座位总数取模）；单挑分支在 `Godot/three_d/rules/table.gd:40-41`（`starters.size() == 2` 时庄家下小盲）。目录只有三人桌的 `poker_progress.next_hand`（`Godot/three_d/tests/poker_progress_coverage_test.gd:51-57` 断言 `dealerSeat==1`），单挑变体的后继状态不同（盲注归属与首行动者），是独立语义结果。
`Godot/three_d/tests/dealer_rotation_test.gd:24-44` 覆盖两种出局座位 × 4 手连续轮换，断言庄位交替、盲注、首行动者、出局席不发牌、总财富守恒与 `Checkpoint` 往返；`Godot/three_d/tests/table_test.gd:84-89` 断言单挑 `start_hand` 的 `smallBlindSeat==dealerSeat` 与 `currentActorId==庄家`。该回归**尚未分配语义覆盖 ID**（与 `docs/3d-production/phase-1/coverage/README.md` 的「next_hand_heads_up 仍待完整分支枚举」一致）。

---

## 5. 总结论：六条边界是「目录里根本没有」还是「目录里有但缺证据」

**分两组，不能一句话概全：**

- **前四条（`short_all_in`、`exact_call_all_in`、`queue_reopen`、`lone_funded_queue`）：目录里有，而且已有真实的后继状态证据。** 它们对应的 8 条 `queue.*` ID（`short_all_in`、`exact_call_all_in`、`raise_reopens_prior_caller`、`lone_funded_owes/matched/runout`、`runout_showdown_conserves`、`matched_round_ends`）都由 `Godot/three_d/tests/short_stack_queue_test.gd` 用真实断言支撑（筹码、底池、目标额、队列、`raiseUsed`、`revision`、RNG、牌堆、财富守恒），不是「跑过返回 true」；探针独立复核了同一批字段。**它们留在 `pending_families` 的原因不是缺证据，而是枚举不完备**：夹具只覆盖三人桌、货运/四桌的指定座位，`docs/3d-production/phase-1/coverage/README.md` 自述「不同座位、两人局、加注权与优惠交互全部审查完成」尚未成立。按本任务口径（同一语义不因座位/数值重复计数），这些组合**不构成新的语义结果**，而是同一结果的不同输入样本。
- **后两条（`aggression_discount`、`next_hand_heads_up`）：目录里确实没有独立 ID（「根本没有」），但有测试覆盖后继状态（「有测试但未登记」）。** 它们的语义在源码里真实可达、后继状态明确，既有测试也做了字段级断言，只是没有任何 `docs/3d-production/phase-1/coverage/transitions.json` 条目指向它们。其中 `aggression_discount` 的「只减一次 / 非激进动作不消耗」连既有测试都没有，属「未找到测试」，本任务已用探针补证（未登记入目录，交由主 Agent 决定）。

**给主 Agent 的直接结论：** 前四条**不需要新增证据**，需要的是决定「同一语义的座位/人数/折扣组合是否单列 ID」；后两条**需要新增目录 ID**（`aggression_discount` 建议挂在 `Table.act` / `Table.legal_actions`，`next_hand_heads_up` 建议挂在 `Table.next_hand`），并给 `aggression_discount` 的「只减一次」补一条正式断言。

---

## 6. 已知验证边界

1. **未运行会写 `output/3d/` 的既有覆盖套件**（`Godot/three_d/tests/short_stack_queue_test.gd`、`poker_guard/poker_action/poker_progress/payout/table_endings` 等）。原因是硬约束只允许写 `output/external-handoff/A3/`。这些套件的断言按源码逐行核对；本任务探针独立复核了六条边界的同一批字段。
2. **`Godot/three_d/tests/table_parity.gd` 未重跑**（会写 `output/3d/` 下的 table-parity 报告）。仅静态核对了夹具数据与比对逻辑，未实际执行 JS 预言机比对。
3. **探针只覆盖 cargo-table（唯一带折扣的桌）与三人/两人局**，未做四桌 × 多种子穷举；`short_all_in` / `exact_call_all_in` 只覆盖玩家座位。
4. **RNG 只做了「未受影响」方向的断言**（`rng.value` 不变），未做 RNG 序列重放；`next_hand` 方向只断言「RNG 前进」而非重放具体牌序。
5. **`Godot/three_d/tests/poker_action_coverage_test.gd` 与 `Godot/three_d/tests/poker_guard_coverage_test.gd` 依赖 `-(10 if firstAggressionDiscountAvailable else 0)` 硬编码货运桌折扣值 10**；若 `Godot/three_d/rules/content.json` 的 `firstAggressionDiscount` 改动，这两处先失败。
6. **探针首轮曾在 S4 前置断言失败**（在 `start_hand()` 之前读取总财富，而 `start()` 已把盲注计入 `pot`，重设 stack 后总额不再守恒）。已改为在 `start_hand()` 之后读取；`output/external-handoff/A3/probe-boundaries.log` 为修正后版本，修正前的失败日志未保留。
7. `evidence_status` 列的取值只用任务书四个中文串。CSV 中「只减一次」一行标 `未找到测试`，指的是**既有测试**未覆盖；该行实际已由本任务探针补证，见 `evidence_path`。

---

## 7. 疑似缺陷

**疑似不一致（已用探针复现，未改规则）**

同一个「全押」结果，经两条命令到达时 `firstAggressionDiscountAvailable` 不同：

- 最短复现（cargo-table，seed 7，开局 `currentBet=20`、玩家 stack=60）：
  - A：`act("player","raise",revision,10000)` → 走 `Godot/three_d/rules/table.gd:88-103`，先在 `Godot/three_d/rules/table.gd:94-96` 消耗折扣，再在 `Godot/three_d/rules/table.gd:97-98` 转成全押；
  - B：`act("player","all-in",revision)` → 直接走 `Godot/three_d/rules/table.gd:109-116`，不经过折扣块。
- 实际结果（`output/external-handoff/A3/probe-boundaries.log`，`cases.discount_consumption_divergence`）：两条路径 `stacks=[0,50,40]`、`pot=90`、`state.currentBet=60`、`toAct`、`raiseUsed` 全部一致，**唯一差异是 A 的折扣标志已被消耗（false），B 仍为 true（true）**。
- 影响面：`Godot/three_d/tests/poker_action_coverage_test.gd` 的 `raise_to_all_in` 与 HUD「把加注滑到最大」都走 A 路径；「全押」按钮走 B 路径。即同一用户意图因入口不同，会决定「本手首次进攻折扣」是否还留给后续街。
- 本任务只报现象，不判断哪种更正确、不修改规则。

**观察项（非缺陷）**

- 每轮只允许一次加注：`Godot/three_d/rules/table.gd:102` 的 `state.raiseUsed` 会禁用本轮后续加注。这是既有设计，已由 `poker_guard.raise_used` 登记为拒绝结果。
- JS 参考实现（`src/game.js`）会把「唯一有筹码且不欠注」的玩家留在队列，Godot 的 `Godot/three_d/rules/table.gd:139-141` 则清空队列；`Godot/three_d/tests/table-fixtures.json` 由 `Godot/three_d/tests/generate_table_fixtures.mjs` 标记为 `intentionalDifference`，`Godot/three_d/tests/table_parity.gd:38-41` 显式接受该差异。属已登记的有意差异，不是缺陷。

---

## 8. 收尾自检记录

| 检查 | 结果 |
| --- | --- |
| `docs/3d-production/external-handoff/A3-poker-audit/outcomes.csv` 可被 `csv.DictReader` 解析 | 通过 |
| 列数 / 列名 | 12 列，与任务书要求的 12 个列名及顺序完全一致 |
| 数据行数 | 13 |
| 六个 family 是否齐全 | 齐全（各 1 / 1 / 2 / 4 / 3 / 2 行） |
| 必填列空值 | 0（`existing_catalog_id`、`existing_test` 按语义允许为空） |
| `evidence_status` 取值 | 已登记且有后继状态证据 8、有测试但未登记 4、未找到测试 1（无自创主类别） |
| CSV 内全部文件引用可解析 | 88 处引用，0 处指向不存在的路径 |
| 行号是否越界 | 0 处越界（源文件与测试文件均已核对长度） |
| `source_line` 内容锚点（按内容校验，不只信行号） | 10 个区间全部命中预期关键词（`all-in` / `call` / `raise` / `set_queue` / `advance` / `river` / `firstAggressionDiscountAvailable` / `can_raise` / `next_hand` / `Heads-up`） |
| 既有测试行号抽查 | 11 个探针行全部命中（含 7 条 `queue.*` 注册点、`Godot/three_d/tests/table_test.gd:66-89`、`Godot/three_d/tests/raise_preview_test.gd:48`、`Godot/three_d/tests/dealer_rotation_test.gd:44`） |
| `output/external-handoff/A3/probe-boundaries.log` | exit_code 0；`checks=67 failed=0`；无 `SCRIPT ERROR` / `ERROR:` |
| `output/external-handoff/A3/existing-dealer_rotation.log` | exit_code 0；`checks=304 failures=[]`；无 `SCRIPT ERROR` / `ERROR:` |
| 退出码之外是否复核日志正文 | 已复核（退出码 0 不单独作为通过依据） |
| 是否改动生产代码 / 测试 / 覆盖目录 / 存档 | 未改动（收工 `git status --short` 只有未跟踪项） |

---

## 9. 交付文件清单（绝对路径）

```
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/A3-poker-audit/README.md
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/A3-poker-audit/outcomes.csv
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/A3-poker-audit/repro/probe_boundaries.gd
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/A3-poker-audit/repro/verify_outcomes.py
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/output/external-handoff/A3/verify_a3_result.json
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/output/external-handoff/A3/probe-boundaries.log
/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安/output/external-handoff/A3/existing-dealer_rotation.log
```

**确有需要新增诊断脚本**（不是为凑数）：`docs/3d-production/external-handoff/A3-poker-audit/repro/probe_boundaries.gd` 只补两件事——(a) 六条边界「可达性 + 实际受影响字段」的独立复核（不依赖既有测试断言的措辞）；(b) `aggression_discount` 的两处既有测试空档与第 7 节的疑似不一致复现。脚本只在内存中构造牌局，不读写任何存档，自身不写文件，只把结构化结果打到 stdout。

---

## 10. 可重复自检脚本与随之发现的一处修正（2026-09-24 补）

### 10.1 为什么补

第 8 节的核对当时在会话内完成，但**没有把脚本交出来**，复核者无法重跑。本轮补上
`repro/verify_outcomes.py`：只读，从**源码 / 覆盖目录 / CSV** 重新推导，逐项打 `CONFIRM` / `REFUTE`，
结果写 `output/external-handoff/A3/verify_a3_result.json`。
**判定只认 `exit 0 且 REFUTE 0`**，不把检查条数当语义结果数。当前 `CONFIRM=7  REFUTE=0`。

| 检查 | 内容 |
| --- | --- |
| C1 | CSV 含任务书要求的 12 列 |
| C2 | 六个 family 全部出现 |
| C3 | `source_line` 的行区间**落在它声称的入口函数体内**（按 `func` 行号表推导；`A -> B` 链式写法命中任一环节即算通过） |
| C4 | `existing_catalog_id` 的每个 ID 都存在于 `transitions.json` |
| C5 | `existing_test` / `evidence_path` 的每个路径可从仓库根打开 |
| C6 | `evidence_status` 与 `existing_catalog_id` / `existing_test` 三角自洽（如「有测试但未登记」不得填 catalog_id） |
| C7 | `accepted_or_rejected` ∈ {accepted, rejected} |

### 10.2 脚本查出的真问题（已修）

`outcomes.csv` 第 7 行（`lone_funded_queue` / `queue.lone_funded_matched`）原文写作
`source_entry=Table.act` 却配 `source_line=Godot/three_d/rules/table.gd:136-143`——
**`:136-143` 整段是 `set_queue()` 的函数体**（`table.gd:136` 即 `func set_queue(ordered: Array) -> void:`），
不在 `act()`（`77-134`）内，两者自相矛盾。

据任务书对 `source_entry` 的定义（第 2 步："从公开入口 `legal_actions`、`act`、`advance`、`next_hand`、`start_hand` 出发"）
判定**入口写 `Table.act` 是对的、错的是行号**——该行 `action` 列本就是 `act("player","call")`。
修正为 `Godot/three_d/rules/table.gd:106-108`（`act()` 的 `call` 分支：`amount = maxi(0, state.currentBet - player.currentBet)` + `commit`），
并在 `notes` 补出完整路径：`act()` 内 `:132-133`「弹出后重排队」→ `set_queue()` `:140-141`「唯一有筹码者已跟平则清空队列」。
**该行的 `precondition` / `postcondition` / `evidence_status` / `existing_catalog_id` / 测试断言均未改动**，只修引用位置。

### 10.3 脚本自身的两个坑（一并记下）

1. **扩展名正则太窄**：初版 `LOC_RE` 只白名单了 `gd/json/py/mjs/csv/tscn/md`，
   于是 `output/external-handoff/A3/probe-boundaries.log` 这类 `.log` 引用被误判成断链（12 处假 `REFUTE`）。
   已放宽为任意字母数字扩展名。**教训：白名单式路径识别会把合法引用误报成断链，宁可宽进严出。**
2. **仓库根不能用硬编码 `parents[N]`**：脚本若在 `docs/` 与 `output/` 之间挪动，下标立刻失效。
   改为向上探测同时含 `docs/3d-production` 与 `Godot/three_d` 的祖先目录。
