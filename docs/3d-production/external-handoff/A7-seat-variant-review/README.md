# A7 座位变体补测 · 独立复核

## 0. 这份交付是什么

任务书 `执行任务A7-扑克座位变体补测-2026-09-25.md` 第 3 行宣布主线已完成，并写明「**不需再次派发或另建独立测试套件**」。

因此本目录**不新建任何测试套件**。这里只做一件事：用一个独立、可重跑的核验器，把主线的四条声明从**源码、目录与实测**重新推导一遍，并回答「这两类座位变体到底给分母贡献了什么」。

| 项 | 路径 |
|---|---|
| 核验器 | `output/external-handoff/A7/verify_a7.py` |
| 机检结论 | `output/external-handoff/A7/a7-verify.json` |
| 完整输出 | `output/external-handoff/A7/verify-full.stdout.txt` |
| 套件日志 | `output/external-handoff/A7/logs/queue-suite.log` |
| 超时套件单跑日志 | `output/external-handoff/A7/logs/roster-standalone.log` |

## 1. 基线

| 项 | 值 |
|---|---|
| 开工 / 收工 HEAD | `8d8464e199c0705510c247ed46c218af9ac2a180`（复核期间未前移） |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| 目录 `docs/3d-production/phase-1/coverage/transitions.json` | sha256 `087971c97f58d22c36f28f1c7b234694c188dd967485a34a071ddbd37111aa28`，382 个 ID，状态 `incomplete_catalog` |
| 被核对测试 | `Godot/three_d/tests/short_stack_queue_test.gd` |
| 正式存档 | sha256 `773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a`、mtime `2026-09-09 15:31:13`，复核前后完全一致 |

## 2. 主线声明的逐条核对

| 主线声明 | 独立实测 | 判定 |
|---|---|---|
| 两类座位变体已并入 `short_stack_queue_test.gd` | 三个变体函数 `verify_all_in_seat`、`verify_short_raise_seat`、`verify_lone_funded_seat` 均存在且都被 `_initialize` 调用 | 成立 |
| **48 个座位样本** | 报告 `seat_variant_cases` 恰 48 条；网格为 4 桌 × 3 座位 × 4 族，**去重后仍 48，无重复格、无缺格** | 成立 |
| **590 项检查通过** | 套件退出码 0，自报 `checks=590 failures=[]`；报告 `checks=590`、`failures=[]`、`missing=[]` | 成立 |
| 复用已有语义 ID、不新增分母 | 命中集合与目录 `queue.*` **双向相等**（10 个 ID），分子=分母=10 | 成立 |
| `pending_families.poker` 现为空 | 成立，且 `poker` / `world` / `persistence` **三个数组当前全为空** | 成立（范围比 A7 自述更宽） |
| **全回归 59/59** | **有条件成立**：`--timeout 180` 下 59/59；但执行器默认 `--timeout 90` 下为 **58/59** | **不可用默认参数复现**，见 §4 |
| **覆盖证据 356/356** | 当前实测 **382/382** | **数字已漂移**，见 §5 |

静态与动态两组检查合计 **CONFIRM 23 / REFUTE 1**（唯一的 REFUTE 即 §4 的超时问题）。

## 3. 机制层面的关键发现（本复核的主要增量）

### 3.1 48 个座位样本**不注册任何目录命中**

`record_seat_case()` 只往 `seat_variant_evidence` 追加遥测记录，**不写 `hits`**；三个变体函数体内也没有任何 `hits[...]` 赋值。真正登记那 10 个 `queue.*` 命中的，是套件里另一段既有代码（`_initialize` 中 `record(...)` 的七处调用，加上两处显式 `if <ok>: hits[...]`）。

含义：座位变体带来的是**夹具广度**（4 桌 × 3 座位 × 4 族），不是**分母增量**。这与任务书「复用已有语义 ID」的要求一致，**没有虚增分母**；但也不能把「48 个座位样本」读成「新增了 48 条覆盖」。

### 3.2 `seat_variant_cases[].passed` 是一个无人消费的字段

全仓库检索确认：除本复核器外，没有任何测试或汇总脚本读取 `seat_variant_evidence` / `seat_variant_cases`。座位变体一旦失败，暴露路径是**全局 `failures` 数组 → 退出码 1 → `collect_coverage.py` 拒绝聚合**，而**不是**这个字段。

这是信息性字段，不是缺陷，但**不得把它当作「48 例通过」的独立证据**。

### 3.3 任务书要求的五个后继维度确实都有断言

| 任务书要求 | 断言所在函数 | 源码命中 |
|---|---|---|
| 行动顺序 | `verify_all_in_seat` / `verify_short_raise_seat` / `verify_lone_funded_seat` | `state.toAct`、`currentActorId` |
| 欠注 / 已匹配 | `verify_short_raise_seat` / `verify_lone_funded_seat` | `toAct.is_empty()`、`legal.get("call")` |
| 行动权 | 三个函数均有 | `legal.get("raise")`、`state.raiseUsed` |
| 当前下注目标 | `verify_all_in_seat` / `verify_short_raise_seat` | `state.currentBet` |
| 牌桌终态 | `verify_short_raise_seat` / `verify_lone_funded_seat` | `state.summary`、`state.street` |

另有三项附加守恒断言：总筹码守恒、首攻折扣标志保持、revision 与牌堆/RNG 不被动作改动。

**局限**：48 个样本的短筹码/单人有钱状态，全部由测试**直接改写 `stack` 字段**构造（`donor.stack += ...; actor.stack = needed`），不是从真实对局自然走出来的。因此它们证明的是**规则引擎在各座位上的正确性**，不证明**这些状态在真实玩法中可达**。

## 4. 发现的问题：回归默认超时不足以覆盖最慢套件

`Godot/three_d/tests/run_regression.py` 的 `--timeout` **默认值是 90 秒**，而 `roster_showdown_test.gd` 的常态耗时是 **135～144 秒**。

证据（全部取自仓库内 `output/3d/regression/` 的真实报告）：

| 报告 | 每套件超时 | 结果 | `roster_showdown_test.gd` |
|---|---|---|---|
| `20260925-100737` | 默认 90s | `passed=false`，58/59 | TIMEOUT 90.01s |
| `20260925-102421` | 120s（机器被并发审计压满） | `passed=false`，58/59 | TIMEOUT 120.02s |
| `20260925-103247` | 180s（**本复核**） | `passed=true`，**59/59** | PASS 141.28s |
| `20260925-103506` | 240s | `passed=true`，**59/59** | PASS —— |
| 单独重跑（本复核） | 600s | 退出码 0 | PASS 134.0s，`checks:37766 failed:0` |

结论：**交付文档里的「全量回归 59/59」只有显式抬高超时才可复现；按脚本默认参数跑必然出现 58/59。** 仓库历史里已留下两份因此变红的报告。

建议（供主 Agent 决策，本复核不改代码）：把 `run_regression.py` 的默认 `--timeout` 抬到 ≥180，或在文档的复现命令里显式写 `--timeout 180`。

## 5. 数字漂移说明

A7 文档写「覆盖证据 356/356」，本次实测为 **382/382**。目录在本轮期间从 356 长到 382（主 Agent 连续注入多个存档/世界结果），这类计数**不应写进交付文档**——写进去几分钟后就会过期。建议交付文档只写判定式：「`EXIT=0` 且 `REFUTE=0`，汇总器 `verified == catalogued` 且 `unverified` 为空」。

## 6. 本复核**没有**证明的事

- 没有证明扑克覆盖族完整。`pending_families.poker` 为空只表示**既有审查分组已收口**，不表示扑克状态转移全集已枚举（见 A8 审计）。
- 没有证明全局覆盖率，也没有证明 Phase 1 通过。汇总器的 `overall_state_transition_coverage` 至今为 `null`。
- 没有证明真人可玩性、正常局时长或新老手决策差异（任务书明确保留给主 Agent 与真人试玩）。
- 48 个座位样本的后继断言是**代码级**的，不含画面证据。

## 7. 复验命令

```sh
cd "<仓库根>"
python3 output/external-handoff/A7/verify_a7.py --static              # 纯静态推导，不启动 Godot
python3 output/external-handoff/A7/verify_a7.py --no-regression       # 复用最新完整回归报告
python3 output/external-handoff/A7/verify_a7.py                       # 静态 + 重跑队列套件 + 全量回归(180s) + 汇总器
```

判定只认退出码 0 且 `REFUTE` 计数为 0。当前 `--no-regression` 模式下 `REFUTE=1`，即 §4 的默认超时问题，**属真实缺陷而非核验器误报**。

### 已知坑（写在这里避免后人踩）

- `run_regression.py` 打印的 `Report: <路径>` 里含空格（仓库路径带「Gen 项目集群」），解析时必须吃到行尾，用 `\S+` 会截断。
- `run_godot.py` 把 Godot 的输出**写进日志文件**，不在自己的 stdout 里回显；要读套件摘要必须读日志文件。
- `output/3d/regression/` 下会残留没有 `report.json` 的半截目录（并发运行或中断导致），按 mtime 取「最新」会踩到它，必须过滤出真正完整的报告。
