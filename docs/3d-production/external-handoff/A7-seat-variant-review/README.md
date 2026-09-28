# A7 座位变体补测 · 独立复核

> **门面口径（与正文同步）**：本目录是对任务书 `执行任务A7-扑克座位变体补测-2026-09-25.md` 的**独立复核**，
> 不新建任何测试套件（任务书第 3 行要求）。判定式为「`EXIT=0` 且 `REFUTE=0`」；
> 本轮冻结时的机检结果是 `verify_a7.py --no-regression` 为 **CONFIRM 24 / REFUTE 0**、
> `verify_world_coverage_stability.py` 为 **CONFIRM 10 / REFUTE 0**（见两个 JSON）。
> 主线自述的、属于 A7 口径的四类事实（已并入、48 个座位样本、复用 ID 不增分母、`pending_families.poker` 为空）**全部成立**。
> 两处自述**数字**（全回归 59/59、覆盖证据 356/356）在写下当天为真，但**已随上游前移过期**，只能当历史值读。
> 另记录两项**与本任务无关、但影响整批回归可信度**的缺陷：§4 的默认超时与 §5.2 的 `world_coverage_test.gd` 偶发红 ——
> 两者都**已在当前树被上游修正或部分修正**，且**都不构成 A7 的失败**，理由见各节。

## 0. 这份交付是什么

任务书 `执行任务A7-扑克座位变体补测-2026-09-25.md` 第 3 行宣布主线已完成，并写明「**不需再次派发或另建独立测试套件**」。

因此本目录**不新建任何测试套件**。这里只做一件事：用一个独立、可重跑的核验器，把主线的声明从**源码、目录与实测**重新推导一遍，并回答「这两类座位变体到底给分母贡献了什么」。

| 项 | 路径 |
|---|---|
| 核验器（主线声明） | `output/external-handoff/A7/verify_a7.py` |
| 核验器（世界覆盖套件稳定性，§5.2 用） | `output/external-handoff/A7/verify_world_coverage_stability.py` |
| 机检结论 | `output/external-handoff/A7/a7-verify.json` |
| 稳定性取证结论 | `output/external-handoff/A7/world-coverage-stability.json` |
| 完整输出（`--no-regression`） | `output/external-handoff/A7/verify-full.stdout.txt` |
| 完整输出（稳定性取证） | `output/external-handoff/A7/stability-full.stdout.txt` |
| 队列套件日志 | `output/external-handoff/A7/logs/queue-suite.log` |
| 超时套件单跑日志 | `output/external-handoff/A7/logs/roster-standalone.log` |
| §5.2 的 14 次独立重复日志 | `output/external-handoff/A7/logs/world-coverage-repeat-01.log` … `-14.log` |
| §5.2 的隔离探针源码 / 结果 / 日志 | `output/external-handoff/A7/probe_room_prop_flake.gd`、`output/external-handoff/A7/room-prop-probe.json`、`output/external-handoff/A7/logs/room-prop-probe.log` |

## 1. 基线（含复核期间的漂移记录）

| 项 | 值 |
|---|---|
| 复核起点 HEAD | `8d8464e199c0705510c247ed46c218af9ac2a180` |
| 本批（2026-09-28）开工 HEAD | `e2e91bd7f06b27f2ce1e86255d5c55cf13490fed` |
| 本批收尾 HEAD | `105512a`（`feat: add decision telemetry to fixed-seed playtests`，复核期间前移 1 个提交） |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| 目录 `docs/3d-production/phase-1/coverage/transitions.json` | sha256 `d6de83010a47f16ed7ac838ebc5acafe4ec5955f77452aec70ba693c5961c30b`、382 个 ID、`queue.*` 10 个、状态 `incomplete_catalog` |
| 被核对测试 | `Godot/three_d/tests/short_stack_queue_test.gd` |
| 正式存档 | sha256 `773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a`、mtime `2026-09-09 15:31:13`，复核前后完全一致 |

**漂移核验方式**：HEAD 在复核期间前移时，**逐文件**跑 `git diff --numstat e2e91bd7..HEAD -- <file>`，而不是只看区间整体。
结果：`short_stack_queue_test.gd`、`world_coverage_test.gd`、`run_regression.py`、`transitions.json`、`scene_props.gd`
五个被本复核引用的文件**全部未变**，目录哈希与 ID 数也不变。因此 §2/§3 的结论不受这次前移影响，只有 HEAD 标签需要改。

**复核末尾的另一个改动（工作区，未提交）**：2026-09-28 15:04，上游把 `world_coverage_test.gd:506` 的汇总行改成了同时打印 `missing`（见 §5.2 事实三）。
该文件因此在复核收尾时处于 `M`（已修改未提交）状态。本复核**没有**修改它；`transitions.json`、`short_stack_queue_test.gd` 与 `run_regression.py` 仍然未变，
故 §2/§3/§4 的判定不受影响。

## 2. 主线声明的逐条核对

| 主线声明 | 独立实测 | 判定 |
|---|---|---|
| 两类座位变体已并入 `short_stack_queue_test.gd` | 三个变体函数 `verify_all_in_seat`、`verify_short_raise_seat`、`verify_lone_funded_seat` 均存在且都被 `_initialize` 调用 | 成立 |
| **48 个座位样本** | 报告 `seat_variant_cases` 恰 48 条；网格为 4 桌 × 3 座位 × 4 族，**去重后仍 48，无重复格、无缺格** | 成立 |
| **590 项检查通过** | 套件退出码 0，自报 `checks=590 failures=[]`；报告 `checks=590`、`failures=[]`、`missing=[]`；其中座位案例合计 504 项（占 85%） | 成立 |
| 复用已有语义 ID、不新增分母 | 命中集合与目录 `queue.*` **双向相等**（10 个 ID），分子=分母=10 | 成立 |
| `pending_families.poker` 现为空 | 成立，且 `poker` / `world` / `persistence` **三个数组当前全为空** | 成立（范围比 A7 自述更宽） |
| **全回归 59/59** | **历史值**：2026-09-25 当天、显式 `--timeout 180` 下 59/59 属实。此后套件数已从 59 涨到 64，且批次是否全绿取决于并发状态（见 §4 与 §5.2） | **不可当当前结论**，见 §4 |
| **覆盖证据 356/356** | **历史值**：当天为真；目录此后长到 382 | **数字已过期**，判定式仍成立，见 §5.1 |

本轮冻结时的机检：`verify_a7.py --static` 为 **CONFIRM 18 / REFUTE 0**，`--no-regression` 为 **CONFIRM 24 / REFUTE 0**（两者退出码均为 0）。
历史版本中唯一的 REFUTE 是 §4 的默认超时，该问题已在当前树修正，故当前不再复现。

## 3. 机制层面的关键发现（本复核的主要增量）

### 3.1 48 个座位样本**不注册任何目录命中**

`record_seat_case()` 只往 `seat_variant_evidence` 追加遥测记录，**不写 `hits`**；三个变体函数体内也没有任何 `hits[...]` 赋值。真正登记那 10 个 `queue.*` 命中的，是套件里另一段既有代码（`_initialize` 与 `record` 两处函数，共 7 次 `record(...)` 调用，另有两处显式 `if <ok>: hits[...]`）。

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

## 4. 历史问题：回归默认超时曾不足以覆盖最慢套件（已在当前树修正）

**2026-09-25 当时的实况**：`Godot/three_d/tests/run_regression.py` 的 `--timeout` **默认值是 90 秒**，而 `roster_showdown_test.gd` 的常态耗时是 **135～144 秒**。

证据（全部取自仓库内 `output/3d/regression/` 的真实报告）：

| 报告 | 每套件超时 | 结果 | `roster_showdown_test.gd` |
|---|---|---|---|
| `20260925-100737` | 默认 90s | `passed=false`，58/59 | TIMEOUT 90.01s |
| `20260925-102421` | 120s（机器被并发审计压满） | `passed=false`，58/59 | TIMEOUT 120.02s |
| `20260925-103247` | 180s（**本复核**） | `passed=true`，**59/59** | PASS 141.28s |
| `20260925-103506` | 240s | `passed=true`，**59/59** | PASS —— |
| 单独重跑（本复核） | 600s | 退出码 0 | PASS 134.0s，`checks:37766 failed:0` |

**结论（历史）**：当时交付文档里的「全量回归 59/59」只有显式抬高超时才可复现；按脚本默认参数跑必然出现 58/59，仓库历史里由此留下了多份变红报告（逐份清单由 `verify_a7.py` 的动态检查列出，此处不写死条数）。

**当前树状态**：`run_regression.py:45` 的默认值已改为 `--timeout=180`，本批复核的 D2b 检查确认该默认值足够 —— 历史 PASS 样本中最慢的 `roster_showdown_test.gd` 为 **150.8s**，本复核单独重跑实测 **134.0s**，均低于 180s。

**因此上一版本文中「A7 核验器本次重新执行后确认完整回归 64/64」这句话必须加限定**：套件总数确实已从 59 涨到 64，但批次全绿是**某一时刻**的性质 —— 引用时须注明对应的报告目录（当时为 `output/3d/regression/20260928-131057/report.json`）。本批复核期间先后出现过全绿（`20260928-143355`）与非全绿（`20260928-143948`，见 §5.2）两种结果，**不能把「64/64」当成本轮回归的当前状态**。

## 5. 数字漂移与当前判定式

### 5.1 计数类数字一律不写死

A7 文档写「覆盖证据 356/356」，本批复核时为 **382/382**，其成因是主 Agent 在本轮期间连续注入多个世界/存档结果。这类计数**不应写进交付文档** —— 写进去几分钟后就会过期。

正确写法是只写**判定式**：「`EXIT=0` 且 `REFUTE=0`，汇总器 `verified == catalogued` 且 `unverified` 为空」。
`verify_a7.py` 的 D3 已按此改：它只断言上述关系，不再把具体条数当结论。

### 5.2 `world_coverage_test.gd` 偶发红（本批复核新发现，**与 A7 无关**）

**先说结论**：`Godot/three_d/tests/world_coverage_test.gd` 在本机**不稳定**；但它是**世界覆盖**套件，与 A7 的座位变体（`short_stack_queue_test.gd`）不是同一个套件。A7 的被测套件在**该套件的全部批次回归报告里从未**出现在失败清单里（截至本轮写此文档时该分母为 161，由 `verify_world_coverage_stability.py` 的 E5 动态重算）。因此这件事**不构成 A7 的失败**，只是复核世界覆盖证据时必须知道的前提。

**事实一：批次历史里红过 4 次**

在 `output/3d/regression/` 里含该套件的运行中，非 PASS 4 次：
`20260925-055330`、`20260925-135507`、`20260925-142425`、`20260928-143948`。

**这四个目录名是固定的；比率不是** —— 分母随主 Agent 继续跑回归而增长，所以本文只写目录名，比率由
`verify_world_coverage_stability.py` 每次重算（本轮写这份文档时为 4/161 ≈ 2.5%）。引用时请以脚本的当次输出为准。

**事实二：失败分属三种签名，不是同一断言恒定失败**

| 报告 | 汇总行自报 | 失败项 | 签名 |
|---|---|---|---|
| `20260925-055330` | `covered=72 total=74 failed=2` | `room_graph_blocked`、`room_graph_entry` | 另有 `SCRIPT ERROR: Invalid access to property or key 'global_position' on a base object of type 'Nil'`（锚点为 null） |
| `20260925-135507` | `covered=75 total=76 failed=0` | **无 ERROR 行** | **隐形失败**，见事实三 |
| `20260925-142425` | `covered=75 total=76 failed=0` | **无 ERROR 行** | 隐形失败 |
| `20260928-143948` | `covered=74 total=75 failed=1` | `room_cupboard_close` | 道具检查断言失败 |

**事实三：历史上存在「日志看着全绿、退出码却是 1」的隐形失败模式（已由上游修复）**

`world_coverage_test.gd` 结尾是：

```gdscript
print("WORLD_COVERAGE covered=",hits.size()," total=",expected.size()," failed=",failures.size())
quit(0 if failures.is_empty() and missing.is_empty() else 1)
```

`quit()` 同时要求 `failures` 与 `missing` 为空，**但汇总行当时不打印 `missing`**。于是当 `missing` 非空时会出现「日志里 `failed=0`、没有任何 ERROR 行、退出码却是 1」——`20260925-135507` 与 `20260925-142425` 两次就是如此。

**修复状态**：2026-09-28 15:04，汇总行已改为同时打印 `missing`（当时为工作区未提交改动）：

```gdscript
print("WORLD_COVERAGE covered=",hits.size()," total=",expected.size()," failed=",failures.size()," missing=",missing)
```

`verify_world_coverage_stability.py` 的 E3b 因此**用 `git show` 钉住历史版本**（该文件最后一个提交 `4862fa4`）来判定这个缺陷当时确实存在，而不是拿当前源码当依据 —— 否则上游一修，这条检查就会变成恒假。

`missing` 非空的原因见事实四。

**事实四：分母是运行时现读目录的 `world.*` 条数，而目录在被并发改动**

该套件的 `expected` 来自它在**运行末尾**读取的 `docs/3d-production/phase-1/coverage/transitions.json`，取其中 `world.*` 的 ID 条数当分母。历史运行的 `total` 取值多达 **25 种**（7/14/18/…/74/75/76，同样由脚本重算）。目录与测试是两份**独立维护**的清单，一旦目录先加上新 ID 而测试还没补断言，`missing` 立刻非空 → 隐形失败。这类失败与套件本身的质量无关，是**上游改动的时间差**。

**事实五：同源码、同命令，结果不同（决定性证据）**

| 报告 | 命令 | `source_sha256` | 结果 |
|---|---|---|---|
| `20260928-143355` | 完全一致（非 headless） | 98 个文件，**逐键零差异** | PASS，21.55s，`covered=75 total=75 failed=0` |
| `20260928-143948` | 完全一致（非 headless） | 98 个文件，**逐键零差异** | FAIL，22.15s，`covered=74 total=75 failed=1`（`room_cupboard_close`） |

两次运行相隔 6 分钟，源码哈希逐键相同、命令相同、`sources_unchanged` 均为 `true`，结果却不同。**这就是不稳定，而不是某版写坏了。**

**事实六：独立重复 14 次，红 2 次（14%）**

用 `run_godot.py` 以与回归相同的非 headless 方式单独重复 14 次，非 0 退出 2 次：

- `logs/world-coverage-repeat-04.log`：`covered=74 total=75 failed=1`，`room_cupboard_open`
- `logs/world-coverage-repeat-13.log`：`covered=73 total=75 failed=2`，`prop_drawer0_reverse`、`prop_window_reverse`

即复现出的失败项**又换了一组**：一次落在房间道具，一次落在藏匿点道具。两者都经由「把玩家放到某点 → `look_at` → 出手」这条路径。

**事实七：把这条路径单独摘出来，320 个样本 0 失败（阴性结果）**

`probe_room_prop_flake.gd` 复刻了套件自己的两条道具路径 —— `use_room_prop`（`world_coverage_test.gd:559-572`，多点重试）与 `use_stash_prop`（`:509-536`，固定偏移单次尝试），并对每一步额外记录「传送后被物理挤开的位移量」与「出手前 `player.focused` 是否命中锚点」。两轮合计 **320 个样本全部通过**：

| 轮次 | 样本 | 失败 | 聚焦失手 | 漂移 >0.05 |
|---|---|---|---|---|
| 第 1 轮（仅 `use_room_prop`，5 轮循环） | 80 | 0 | —— | —— |
| 第 2 轮（两条路径 × 10 轮循环） | 240 | 0 | **0** | 40 |

同时测得：

- 每次 `await create_timer(0.5)` 内实际走了 **59 个 process 帧**（约 118 FPS），帧预算充裕；
- 数值偏差 **4.76837e-08**，而 `is_equal_approx` 的相对容差是 **1.2e-5**（相差两个数量级）；
- `scene_props.gd:16` 的补间时长 **0.45s** 对测试等待 **0.5s**，余量 50ms —— 在上述帧率下不是瓶颈；
- `world.action_busy` 在整个过程中**从未为真**；
- 40 条漂移**全部集中在 `card` / `chip`**（各 20/20，位移恒为 0.764 / 0.435，是确定性偏移而非抖动），**且漂移之后 `focused` 依然命中、动作依然被接受**。

因此可以排除三个最自然的猜想：「这一段代码自身的时序余量不足」、「`is_equal_approx` 容差太紧」、「玩家被挤开导致 raycast 打偏」。
（如实说明：探针第 1 版把 `float()` 用在 `Vector3` 值属性上抛错，丢掉了 20 条记录，恰好覆盖 `drawer0`/`window`/`card`/`chip`/`cupboard` 这些 `Vector3` 属性道具 —— 补上类型分支后才得到上表的 240 条完整记录。原始日志 `output/external-handoff/A7/logs/room-prop-probe-run1.log` 与 `output/external-handoff/A7/logs/room-prop-probe.log` 都在，可对照。）

**结论与交代**：`world_coverage_test.gd` 的不稳定**已被复现并量化**（批次 2.5%、独立重复 14%），失败**集中在道具类检查**，且**触发条件依赖该套件前置序列留下的状态** —— 因为把同一段代码单独摘出、连跑 320 个样本（含真出问题的 `drawer0`/`window`/`cupboard` 这些 `Vector3` 属性道具）是**全干净**的，且聚焦从未打偏。**根因尚未确定**，本复核不做进一步推测。留给该套件维护方的具体指针：

1. `use_stash_prop`（`:509-536`）把玩家放在**固定偏移**上、**只尝试一次**、且不校验 `player.focused` 是否命中锚点；`use_room_prop`/`aim_room_anchor`（`:538-552`）则有最多 64 个候选位与显式命中判定。两条路径的稳健性差异是后续排查的第一顺位（本复核的探针测得聚焦从未打偏，故这仍是"待查"而非"已证"）。
2. ~~在 `:506` 的汇总行补上 `missing`~~ —— **已被上游采纳**（2026-09-28 15:04，见事实三）。
3. `expected` 建议改为从**与测试同版本**的目录快照读取，或在断言前显式比对目录与被测 ID 集合的差异并单独报告，避免「上游加 ID」把套件判红。

**本复核不对该套件做任何修改**，也不把它计入 A7 的判定（`verify_a7.py` 的 D2 已改为两级：D2a 只判 A7 自己的套件；批次绿度降级为记录项 D2c）。

### 2026-09-28 后续复验（主线测试改动后的新样本）

主线随后把 `use_stash_prop()` 改为先通过射线选点辅助函数命中交互锚点，并在道具开合失败时打印聚焦、动画忙碌状态与目标属性值；房间道具也增加同类失败诊断。以更新后的 `world_coverage_test.gd`（SHA-256 `4d713bbed65121355b41a8b94238ee73b38024b0c3d16d76e87450a71b3bf79e`）按完整回归相同的非 headless 模式连续复跑 14 次，14/14 均为 `75/75`，未打印道具失败诊断。全量回归 `output/3d/regression/20260928-161517/report.json` 也通过 64/64，世界覆盖结果与本测试 SHA 一致。

这是一组不同源码快照的新样本；结合本节前述旧快照的 14 次中 2 次失败，只能说明本次改动后的重复测试暂未复现失败，不能据此证明低频故障已经根除。后续若再出现失败，应先读取 `ROOM_PROP_DIAG` / `PROP_DIAG` 字段判断失败在选点聚焦、动作守卫、动画完成、节点属性还是 Run 快照比较。

## 6. 本复核**没有**证明的事

- 没有证明扑克覆盖族完整。`pending_families.poker` 为空只表示**既有审查分组已收口**，不表示扑克状态转移全集已枚举（见 A8 审计）。
- 没有证明全局覆盖率，也没有证明 Phase 1 通过。汇总器的 `overall_state_transition_coverage` 至今为 `null`。
- 没有证明真人可玩性、正常局时长或新老手决策差异（任务书明确保留给主 Agent 与真人试玩）。
- 48 个座位样本的后继断言是**代码级**的，不含画面证据。
- 没有证明世界覆盖套件稳定 —— 相反，§5.2 给出的是它**不稳定**的证据，且**未定位根因**。

## 7. 复验命令

```sh
cd "<仓库根>"
python3 output/external-handoff/A7/verify_a7.py --static              # 纯静态推导，不启动 Godot
python3 output/external-handoff/A7/verify_a7.py --no-regression       # 复用最新完整回归报告（只认 D2a）
python3 output/external-handoff/A7/verify_a7.py                       # 静态 + 重跑队列套件 + 全量回归(180s) + 汇总器
python3 output/external-handoff/A7/verify_world_coverage_stability.py # §5.2 的取证，只读仓库既有报告与归档日志
python3 output/external-handoff/C1/verify_links.py                    # 文档引用可解析性
```

判定只认退出码 0 且 `REFUTE` 计数为 0。

- `verify_a7.py`：A7 声明面的判定式是「`EXIT=0` 且 `REFUTE=0`」，且汇总器满足 `verified == catalogued`、`unverified` 为空。
  其中 D2a 只判 `short_stack_queue_test.gd` 是否在回归清单里且 PASS；批次绿度记在 D2c，**不影响退出码**。
- `verify_world_coverage_stability.py`：判定式同为「`EXIT=0` 且 `REFUTE=0`」，其结论是"该套件不稳定且**不属于 A7 的声明面**"，不是"该套件有问题"。

### 已知坑（写在这里避免后人踩）

- `run_regression.py` 打印的 `Report: <路径>` 里含空格（仓库路径带「Gen 项目集群」），解析时必须吃到行尾，用 `\S+` 会截断。
- `run_godot.py` 把 Godot 的输出**写进日志文件**，不在自己的 stdout 里回显；要读套件摘要必须读日志文件。
- `run_godot.py` 的用户参数分隔符 `--` **必须原样保留**两次（`--log X -- <Godot 参数> -- --test`），少一层会让 `--test` 落到引擎上并直接 abort。
- `output/3d/regression/` 下会残留没有 `report.json` 的半截目录（并发运行或中断导致），按 mtime 取「最新」会踩到它，必须过滤出真正完整的报告。
- 该套件是**非 headless**（窗口）运行：`run_regression.py` 只在 `player_input_coverage_test.gd` 与 `world_coverage_test.gd` 两个套件上不加 `--headless`，且为它们隔离 `HOME`。用 headless 复跑这两套件会得到与回归不同的结果。
- 每次运行该套件都会覆写 `output/3d/world-coverage.json`（覆盖证据文件）。做重复实验会覆盖掉并发回归刚生成的证据；正式判定前应重跑一次回归或汇总器让证据回到与批次一致的状态。
- `seq -w 1 14` 会补零成 `01`…`14`，与 `run1.log` 这类未补零的文件名对不上，批量归档日志时容易静默少拷（本批复核踩过一次）。
