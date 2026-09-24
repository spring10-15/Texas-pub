# A2 边界问题复现与回归补录 —— 发现（findings）

日期：2026-09-21（跨 09-22）。基线：`d05fe9e`（详见 `README.md` 的环境与工作区说明）。

> **主 Agent 后续复核（2026-09-25）**：本文件以下三条 L-3“缺口复现”是旧基线事实，不能作为当前未解决问题。后来加入的恢复边界校验已覆盖 NaN、越界 Transform 和非 Dictionary `props`，拒绝时核验整份世界快照不变；`world_restore_atomic_test.gd` 定向恢复子图 13/13、54 项检查通过。L-2 两条语义疑问也已按当前实现核清：折扣减的是首次激进行动的实际支付，目标注额仍按桌规；精确跟注打光则按当前手 all-in、下手因零筹码退出，现有折扣与队列测试覆盖这些后继。当前完整回归 59/59、登记证据 357/357；这仍不等于全局覆盖率或真人体验门槛通过。

**结论速览**

| 线索 | 结论 | 是否需要主 Agent 行动 |
|---|---|---|
| L-1 单挑庄位轮换 | **未复现**（原疑虑已被 `d05fe9e` 修掉）。新代码在 16 手 × 2 种夹具下轮换、盲注、首行动者全部符合规则来源 | 否。建议把 `dealer_rotation_test.gd` 纳入覆盖登记，避免再次成为盲区 |
| L-2 首次加注优惠 | **行为符合预期**（同手第二次不享、下一手复位、对手可用、余额边界正确、全桌财富守恒）。但发现 **2 条设计语义疑问** | 是。语义疑问需主 Agent 定性，**本诊断未改动规则、未删除优惠** |
| L-3 非法存档恢复 | **3 项缺口复现**：① NaN 姿态被接受 ② 越界坐标被接受 ③ 非法 `props` 触发"半恢复"。另有 1 项设计边界被证实（摘要不防有意改档） | 是。均为边界校验缺口，是否补校验请主 Agent 决定 |

---

## L-1 单挑（及其余座位出局）庄位轮换

### 预期规则来源（分列，不按手数取模推导）

| 规则 | 来源 | 内容 |
|---|---|---|
| 换手轮换 | `table.gd:35-37` `start_hand()` | `rotate_dealer` 为真**或**当前庄家已 `folded` 时，庄家改为 `ordered_after(dealer)[0]`，即"庄家之后第一个有筹码且未弃牌的座位" |
| 换手入口 | `table.gd:187-188` `next_hand()` | 调用 `start_hand(true)`，故经 `next_hand` 推进时必然轮换 |
| 单挑盲注 | `table.gd:40-41` | `starters.size()==2` 时庄家=小盲，另一人=大盲 |
| 翻前首行动者 | `table.gd:51` | `set_queue(ordered_after(bigBlindSeat))` → 大盲之后第一个 = **庄家** |
| 翻后首行动者 | `table.gd:169` | `advance()` 内 `set_queue(ordered_after(dealerSeat))` → **大盲（非庄家）** |
| 出局座位 | `table.gd:27-28` | 每手按 `stack <= 0` 重算 `folded`，出局座位不再发牌 |
| 玩家座位特判 | `table.gd:31` | `funded.size() < 2` **或 `state.players[0].stack <= 0`** → 直接 `finished` |

### 夹具与行动路径的分工（按任务书要求显式区分）

- **FIXTURE（仅建立初始局面）**：`diag_dealer_rotation.gd:57-63` 直接写 `players[i].stack` 造出"某座位无筹码"，
  随后 `start_hand()` 让 `folded` 按新筹码重算。夹具只负责"谁出局"，不参与轮换。
- **ACTION（全部经公开行动）**：出局之后的每一手，轮换只经 `next_hand()`，下注只经 `act()`，推进只经 `advance()`。
- **两种夹具并测**以暴露夹具敏感性：`deep`（幸存者 `buyIn×20`，隔离筹码深度对轮换的影响）与
  `shallow`（幸存者 `buyIn×2`，接近真实单挑）。两者结果一致。

### 实际结果（16 手，全部经 ACTION 路径）

以 `cargo-table` 为例（`buyIn=60`，`smallBlind=10`，`openBet=20`）：

| 夹具 | 出局座位 | 手序 | 庄家 | 小盲 | 大盲 | 翻前首行动 | 翻后首行动 |
|---|---|---|---|---|---|---|---|
| deep | 1 | 1→4 | 0, 2, 0, 2 | 同庄家 | 2, 0, 2, 0 | 庄家 | 大盲 |
| deep | 2 | 1→4 | 0, 1, 0, 1 | 同庄家 | 1, 0, 1, 0 | 庄家 | 大盲 |
| shallow | 1 | 1→4 | 0, 2, 0, 2 | 同庄家 | 2, 0, 2, 0 | 庄家 | 大盲 |
| shallow | 2 | 1→4 | 0, 1, 0, 1 | 同庄家 | 1, 0, 1, 0 | 庄家 | 大盲 |
| deep / shallow | 0 | — | 规则守卫命中：`status=finished`，无任何一手 | | | | |

- 断言：`checks=168`，`failures=0`。含 16 手 × 每手 7 项（庄家=小盲、大盲≠庄家、翻前首行动=庄家、
  翻后首行动=大盲、出局座位不发牌、出局座位不担盲注/庄家、两个时点的财富守恒）＋ 换手前 checkpoint 往返
  ＋ `next_hand` 接受 ＋ 出局座位守卫用例。
- 稳定性：两种夹具 × 三个出局座位共 6 个用例，**每次均一致**；日志 `output/external-handoff/A2/logs/diag_dealer_rotation.log`。
- 脚本：`docs/3d-production/external-handoff/A2-boundaries/repro/diag_dealer_rotation.gd`。

### 为什么判"未复现"（含旧代码推导，明确标注非实测）

A 报告 L-1 的疑虑是"某座位 `stack <= 0` 被标记 `folded` 时走跳位分支，可能破坏严格轮换"。

- 旧实现为 `state.dealerSeat = (state.handNumber - 1) % state.players.size()`，再对 `folded` 做一次
  `ordered_after(dealerSeat)[0]` 兜底。**按 `git show d05fe9e` 的 diff 推导**（三座位、座位 1 出局）：
  庄家序列为 `0, 2, 2, 0` —— 第 2、3 手**重复落在座位 2**，严格轮换确实被打断。
  ⚠️ 这一行是**代码推导，不是本轮实测**：本轮无法在不改动生产代码的前提下回放旧实现。
- 新实现实测序列为 `0, 2, 0, 2`，轮换恢复严格交替。

**结论**：原疑虑在 `b158491` 时代成立，已被主 Agent 的 `d05fe9e` 修正；当前 HEAD 未复现，无需再动规则。

### 建议（不代替主 Agent 决定）

`dealer_rotation_test.gd` 与 `diag_dealer_rotation.gd` 都覆盖了这段逻辑，但前者**是否纳入覆盖登记表**由主 Agent 定。
A 轮已指出"清单外且未登记的套件长期无人跑"是盲区来源，L-1 正是这类盲区。

---

## L-2 首次加注优惠（`firstAggressionDiscountAvailable`）

### 预期规则来源

| 规则 | 来源 | 内容 |
|---|---|---|
| 每手复位 | `table.gd:26` | `start_hand()` 把标记重置为 `tableDef.id == "cargo-table"` |
| 可负担性用折扣 | `table.gd:67-69` | `discount=10` 只用于 `open_cost` / `raise_cost` 的**能否加注**判断 |
| 消耗与实付 | `table.gd:94-96` | `act()` 在 `raise` 时 `amount = maxi(0, amount - 10)` 并立刻把标记置假 |
| 目标不减 | `table.gd:101` | `commit` 后 `state.currentBet = target`（**目标下注额不减 10**） |
| 同轮只一次 | `table.gd:102` | `raiseUsed = old_target != 0` → 同一轮内第二次加注被挡 |

### 实际结果（`cargo-table`：`smallBlind=10 / openBet=20 / raiseIncrement=20`）

| 子场景 | 观察 | 判定 |
|---|---|---|
| 1 玩家翻前首攻 | 实付 **30**，`currentBet=40`，标记转假，`pot=60` | 符合（名义 40 −10） |
| 2 同手第二次进攻（翻牌） | 实付 **20**，`currentBet=20`（无优惠） | 符合（同手内不复位） |
| 3 下一手复位 | 新一手首攻实付 **30**，标记为真 | 符合 |
| 4 对手作为首攻者 | 小盲位对手实付 **20**（名义 30 −10）；标记被消耗 | 符合（玩家/对手同等适用） |
| 5 余额边界 | `stack=29/30` **不可加注**；`31/32` 可加注且实付 30（`stack=31` 加注后仅剩 1） | 符合 `table.gd:74` 的 `stack > cost + raise_cost = 30` |
| 5b 跟注不受优惠 | `stack=29/30` 改跟注实付 **20** | 符合（优惠只作用于 raise） |
| 6 对照组 `ledger-cellar` | 无优惠，实付 **60**（`30 + 30`） | 符合 |

- 断言：`checks=52`，`failures=0`；语义结果数 10（6 用例 / 10 子场景）。
- 全桌财富：以上每个动作后均验证 `Σstack + pot` 不变，**全部守恒**。
- 日志：`output/external-handoff/A2/logs/diag_first_discount.log`；脚本：`repro/diag_first_discount.gd`。

### 守恒错误 vs 设计语义：分开写（任务书明确要求）

**没有发现守恒错误。** 恒等关系 `Σstack + pot` 在所有场景下都成立。

但发现 **2 条设计语义疑问**，本诊断不下结论、不改规则，交主 Agent 定性：

一个关键的语义点，也是**本轮最容易误报的测量陷阱**：

1. **优惠改变的是"实付"，不是"目标"。** 首攻后 `currentBet=40` 而实付仅 30，底池只增加 30。
   因此 `pot` **小于** `名义下注额 × 人数`。若按"`currentBet × 人数 == pot`"这种朴素公式测守恒，会**假报不守恒**。
   需要主 Agent 明确：这 10 是"折扣"（少收钱但抬到同样的注额），还是"下注额的虚拟抬升"（注额本该是 30）？
   两种解读对"底池与注额是否同源"的影响不同，也会影响 UI 如何展示。
2. **刚好打光的语义。** `stack` 恰好等于跟注额时，跟注后 `stack=0`，下一手被判 `folded`（`table.gd:27-28`）。
   这算"打光出局"的正常语义，还是应判 `all-in` 并保留在桌？属规则语义确认项。

> A 报告 L-2 原文把这条列为"覆盖盲区"。本轮**已把盲区补上**：同手第二次进攻、下一手复位两项都已实测并符合预期。

---

## L-3 非法存档与恢复边界

### 分层与边界

- **组1 纯规则层**：直接 `RunCheckpoint.restore()`，不碰文件系统。
- **组2 文件层**：只写 **A2 专用文件** `user://a2-boundary-probe.save`（脚本结束时删除）。
- **组3 世界层**：经 `world.restore_checkpoint()`；仅在内存中构造存档，**从未调用 `save_checkpoint()`**。
- **组4 RNG**：`TableCheckpoint` 往返。

> **玩家真实存档 `user://three-d-checkpoint.save` 全程未被读写**（mtime 与内容校验见 `README.md`）。

### 已确认有效（符合预期，共 33 个场景里 29 个）

> 说明：纯规则层的 `bankroll / revision / search_index / action_points / known_rules / used_tools / 背包容量`
> 这批校验，来自本轮基线 HEAD `d44a1dd`（"reject invalid run checkpoint ranges and inventory capacity"）。
> 也就是说这些都是**已提交**代码的行为，不是工作区临时状态。同提交附带的 `run_restore_bounds_test.gd` 也已复跑通过（29 项）。

- 纯规则层**全部拒绝**：`cash=-1`、`vault=-1`、`heat=7`、`heat=-1`、`bankroll=-1`、`revision=-1`、
  `search_index=0`、`action_points=-1`、`action_points=上限+1`、`known_rules=未知桌`、`used_tools=未知道具`、
  `inventory=未知道具`、`scene_id=未知酒馆`、`offer_index=越界`、`completed=重复项`、缺 `cash` 字段、
  `cash` 类型不符、背包超容量。
- 文件层：摘要不匹配 → `invalid`；`version=0` → `invalid`；截断到一半 → `invalid`；
  缺 `run` 字段 → 文件层读回 `ok` 但规则层拒绝。
- 世界层：`room="nowhere"` → 拒绝；自身 `capture → restore` 往返 → **接受**（说明基线链路是通的）。
- RNG：`Checkpoint.restore()` 后 `rng.value` 一致，且两侧 `next_hand()` 洗出的牌堆**逐元素相同**
  → 恢复后随机序列确定性延续。

### 缺口 1｜NaN 姿态被接受（L-3 线索 2 复现）

- **最短复现**：`state.player = Transform3D(Basis(), Vector3(NAN, NAN, NAN))` → `world.restore_checkpoint(state)`
- **预期**：拒绝。**实际**：**接受**，且 `world.player.global_transform.origin` 变为 `(nan, nan, nan)`，
  `is_finite()` 为 `false`。
- **机制**：`world.gd:900` 只校验 `state.get("player") is Transform3D`。NaN 仍是合法 `Transform3D`，
  故通过校验；`:917` 随后直接 `player.global_transform = state.player`。
- **影响范围**：一旦玩家坐标进入非有限值，后续相机 `look_at`、射线、碰撞都将产生不可预期结果，且**没有自愈路径**。
- **稳定性**：稳定复现（本轮 1/1，其余组3 用例均在基线重置后执行）。

### 缺口 2｜越界坐标被接受（同一处，L-3 线索 2 的另一半）

- **最短复现**：`state.player = Transform3D(Basis(), Vector3(9999, 0, 9999))` → `restore_checkpoint`
- **实际**：**接受**，玩家坐标变为 `(9999, 0, 9999)`。
- **机制**：同上，`:900` 不校验房间包围盒，`:907` 只校验"房间是否被解锁"，与坐标无关。
- **稳定性**：稳定复现。**影响**：玩家可被送出可玩区域，且因房间状态与坐标不一致，可能卡死。

### 缺口 3｜非法 `props` 触发"半恢复"（本轮新发现，A 报告未列）

- **最短复现**：`state.props = "not-a-dictionary"` 且同时令 `state.run.cash = 原值 + 100` → `restore_checkpoint`
- **实际**：函数返回**失败**，但 **`run_game` 已被替换**：现金 `300 → 400`，而房间仍是 `tavern`（未 `travel`）。
- **机制**：`world.gd:900` 的守卫**没有检查 `props`**；`:911` 先执行 `run_game = restored`，
  到 `:912` 才调用 `props.restore(state.get("props", {}))`，因类型不符抛
  `SCRIPT ERROR: Invalid type in function 'restore' ... Cannot convert argument 1 from String to Dictionary`，
  函数中断返回 —— **之前的写入没有回滚**。
- **影响范围**：这是**拒绝不彻底**。存档被判"损坏"（`world.gd:891-893` 会显示"存档损坏或版本不兼容，
  已保留原文件；本次不覆盖存档"并置 `saving_enabled=false`），但世界已停在"货币是新档、位置与道具是旧档"
  的不一致状态；`saving_enabled=false` 又恰好阻止了自动保存覆盖，形成难以自察的错位。
- **稳定性**：稳定复现（现金变化可观测，日志见下）。
- **日志关键行**：`半恢复探针：返回=拒绝 | 房间 tavern→tavern | 现金 300→400`

### 已证实的设计边界（非缺陷，但需写清）

- **摘要只防意外损坏，不防有意改档**：`save_store.gd:7` 的 `digest` 由 payload 自身算出
  （`payload.hex_encode().sha256_text()`）。实验 (b) 改 payload 并**重算 digest** → 读回 `status=ok`。
  即：能改文件的一方也能改摘要，该校验防的是传输/写入损坏，不是篡改。

### 需主 Agent 决定的语义项（单列，不代替决定）

1. 上述**缺口 1/2** 是否补 `is_finite()` 与房间包围盒校验？建议至少补 `is_finite()`——代价极低且症状严重。
2. 缺口 3 是否把 `props` 纳入 `:900` 的守卫、或把 `run_game` 的赋值**移到全部校验与副作用之后**以保证原子性？
3. `run_checkpoint.gd` 对 `preview` / `full_intel` / `opponent_notes` / `last_result` 等只做类型检查、
   不做内容语义校验；这类字段被篡改**不会导致拒绝**。是否属可接受范围？

---

## 本轮踩到的一个测量陷阱（供后续复用）

测"全桌财富守恒"时**不能**统一用 `Σstack + pot`：

- `finish_hand()`（`table.gd:173-182`）把 `state.pot` 复制进 `state.summary.pot`，但**不清零 `state.pot`**；
  真正的清零发生在下一次 `start_hand()`（`table.gd:26` 的 `mirror`）。
- 因此在一手刚结束时用 `Σstack + pot` 会把**已经派发给赢家的底池重复计入**，凭空多出一份 pot（本轮实测多出 40）。
- 正确做法：**手进行中**（刚发完盲注）用 `Σstack + pot`；**一手刚结束**用 `Σstack`。
  本轮 `diag_dealer_rotation.gd` 已按两个时点分别断言。

> 这条与 C1 第 7 条"资金守恒要有闭合边界"是同一类问题：守恒式必须写清**在哪个时点、包含哪些容器**。
