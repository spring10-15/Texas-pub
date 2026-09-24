# A5：存档、恢复与 RNG 重放状态转移取证

> **当前源码与目录校订（2026-09-25，基线 `91f8457`）**：近期 `world.gd` 在存档函数前增加试玩轨迹记录，导致本文件 19 条 `source_line` 偏移 3 行；已按原内容锚点刷新，行为未因此变化。A5 强后继证据现映射 31 个目录 ID，包括运行/牌桌 capture 隔离、原子写入失败、畸形快照拒绝、损坏/未来版本保留、锁定房间拒绝、缺字段恢复、表内 RNG 重放、版本 2/3 计划回填，以及磁盘检查点缺失/损坏时从有效内存修复。相同语义的多个输入或负对照复用 ID，不扩大分母。版本迁移检查使用内存旧格式样本，不声称读取真实历史磁盘存档。恢复子图 14/14；全量回归 59/59，目录证据 360/360。其他存档 family 仍待逐项审查。

日期：2026-09-24。执行范围：`Godot/three_d/rules/save_store.gd`、`run_checkpoint.gd`、`table_checkpoint.gd`，
`Godot/three_d/scripts/world.gd` 的 `checkpoint_state` / `save_checkpoint` / `load_checkpoint` / `restore_checkpoint` 及直接依赖的恢复校验。
不含普通场景道具交互（归 A4）。本文只做取证，**未改任何生产代码、既有测试、`transitions.json`、覆盖目录、玩家存档**；未 commit / push；未生图 / 建模。

---

## 1. 基线

| 项 | 值 |
| --- | --- |
| `git rev-parse HEAD`（开工时） | `31918bae7385a7f6c96a689633c616335fe35908` |
| `git rev-parse HEAD`（收工时） | `39cb971a0f0b9cb92547cad0a8e1391cf639d26c`（并行进程于 00:11–00:20 提交，**非本 Agent**） |
| A5 源文件在 `31918bae..39cb971a` 区间 | `save_store.gd` / `run_checkpoint.gd` / `table_checkpoint.gd` / `world.gd` **全部 UNCHANGED**（`git diff --quiet` 核实）→ 本报告行号对两个 HEAD 均成立 |
| Godot | `4.7.2.stable.official.ed1daf0bf`（`/Applications/Godot.app/Contents/MacOS/Godot`，PATH 无 `godot`） |
| 开工时 `git status --short` | 仅 `??` 未跟踪项；**无受控文件被改** |
| 覆盖目录 | `docs/3d-production/phase-1/coverage/transitions.json` sha256 = `25445db3…f0972c6`，与测试日志里的 `catalog_sha256` 一致 → 未被本次改动 |

> **与任务书/交代不一致，已核实**：任务书与派单写 `HEAD = 07f22459…`，本机开工实际为 `31918bae…`、收工为 `39cb971a…`。本报告**全部行号以实际工作树为准**，且在 `repro/verify_outcomes.py` 用「内容锚点」逐行重推校验（不是照抄）。既有测试日志生成于 01:35，晚于最后一次提交（00:20:13），故反映 `39cb971a` 的工作树。
>
> **工作区被第三方改动的披露**：受控文件 `Godot/three_d/tests/difficulty_probe.gd` 在本次执行期间出现改动（内容为 poker 难度/反事实赔率探针；同刻 `output/3d/difficulty-probe.json` 00:24、`output/3d/opponent-profiles.json` 00:20 被刷新）——**与本 Agent 无关**（并行 Agent 所为；该文件 mtime 00:21:38，紧跟在 00:20:13 的并行提交之后）。本 Agent 未修改它，也未回滚它。

### 1.1 正式存档前后快照（证明未碰正式槽位）

正式存档：`~/Library/Application Support/Godot/app_userdata/Godot德扑酒馆/three-d-checkpoint.save`

| | mtime | size | sha256 |
| --- | --- | --- | --- |
| 开工前 | 2026-09-09 15:31:13 | 1416 | `773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a` |
| 收工前 | 2026-09-09 15:31:13 | 1416 | `773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a` |

**两次完全一致。** 同目录 `playtest-traces/` 前后均为空目录。

披露一处遗留（非正式存档）：第一次**非隔离**批量跑既有测试时被上层删除拦截规则中断，留下 `~/…/Godot德扑酒馆/checkpoint-test-29732.save.tmp`（2026-09-24 01:02，308 B）。它是失败中断产物、不是正式存档；因上层规则禁止在该目录删除文件而保留未动，正式存档 hash 不受影响。

---

## 2. 运行命令

所有命令 `cd "<root>"` 后执行；执行器为 `output/external-handoff/V1/run_godot.py`（墙钟超时 + 杀进程组 + 原始输出落盘）。

```sh
# 三个 A5 诊断探针（隔离临时路径；正式槽位零读写）
python3 output/external-handoff/V1/run_godot.py --log output/external-handoff/A5/probe-save_store.log --timeout 120 -- \
  --script "$PWD/docs/3d-production/external-handoff/A5-persistence-audit/repro/a5_save_store_probe.gd" -- --test --tmp="$PWD/output/external-handoff/A5/tmp"
python3 output/external-handoff/V1/run_godot.py --log output/external-handoff/A5/probe-world_contradiction.log --timeout 180 -- \
  --script "$PWD/docs/3d-production/external-handoff/A5-persistence-audit/repro/a5_world_contradiction_probe.gd" -- --test --tmp="$PWD/output/external-handoff/A5/tmp"
python3 output/external-handoff/V1/run_godot.py --log output/external-handoff/A5/probe-world_replay.log --timeout 240 -- \
  --script "$PWD/docs/3d-production/external-handoff/A5-persistence-audit/repro/a5_world_replay_probe.gd" -- --test --tmp="$PWD/output/external-handoff/A5/tmp"

# 既有测试（隔离 HOME，见 §3）
env HOME="$PWD/output/external-handoff/A5/tmp/iso-home" python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/A5/existing-save_store_test.log --timeout 200 -- \
  --script res://three_d/tests/save_store_test.gd -- --test

# 收尾自检（内容锚点重推行号 + evidence_path 存在 + CSV 可解析 + 既有 ID 去重）
python3 docs/3d-production/external-handoff/A5-persistence-audit/repro/verify_outcomes.py
```

`--script` 后的用户参数分隔符 `--` 原样保留：本机 Godot 未开 `tests=yes`，`--test` 若被 Godot 自己吃掉会直接 abort。

---

## 3. `user://` 隔离：实际做法与取舍

- **Godot 4.7.2 无 `--user-dir`**（已核 `--help`）。实测可用环境变量重定向：`user://` = `$HOME/Library/Application Support/Godot/app_userdata/Godot德扑酒馆/`。
  探针 `repro/a5_userdir_probe.gd` 实测：`env HOME=<隔离目录>` 后 `ProjectSettings.globalize_path("user://")` 落到隔离目录内（见 `output/external-handoff/A5/probe-userdir.log`）。**这是本次跑既有测试的隔离手段**。
- 本 Agent 自己的三个诊断探针**根本不写 `user://`**：文件层用例一律用 `--tmp=<绝对隔离目录>`（`output/external-handoff/A5/tmp/`），`write_checkpoint/read_checkpoint` 收绝对路径。
- **测试自带的隔离**：既有世界测试在 `-- --test` 下 `_ready()` 跳过 `load_checkpoint()`（`world.gd:103-105`），因此不会读正式槽位；`saving_enabled` 保持 false，节拍自动存盘（`world.gd:665`）也不会触发。`services_save_test` / `table_integration` / `save_store_test` / `table_checkpoint_test` 均把 `save_path` 指向各自的 `user://` 临时文件并在结束时删除。
- **取舍（如实说明）**：`--playtest-seed=<n>` 启动时 `save_checkpoint()`/`load_checkpoint()` 会提前返回（`world.gd:948` / `:964`），天然不读写正式槽位；但这**同时意味着测不到这两个函数的真实分支**。因此 A5 探针**没有**用 `--playtest-seed`，而是在 `--test`（不自动 load）下**直接调用** `save_checkpoint/load_checkpoint/restore_checkpoint` 并把 `save_path` 指向隔离绝对路径，以覆盖真实分支。`playtest_seed_test.gd` 负责证明「带 seed 时零读写」。
- **不制造真实损坏样本**：所有损坏/截断/权限用例只作用于 `output/external-handoff/A5/tmp/` 下的副本。

---

## 4. 七组逐条结论

> `evidence_status` 取值：`已登记且有后继状态证据` / `有测试但未登记` / `A5探针新增证据` / `证据不足（仅核对返回值）` / `unverified`。
> 现有 15 条 `persistence_io.*` / `persistence_restore.*` 在 `outcomes.csv` 中**各出现且仅出现一次**（`existing_catalog_id` 列，去重映射）。

### capture（目录里 0 条）
1. `world.gd::checkpoint_state()` @944 — accepted，返回 `{run,room,player,look,seated,return,caseOpen,props}`（键名逐字核对）。`有测试但未登记`（world_restore_atomic / four_tables / services_save）。
2. `run_checkpoint.gd::capture()` @6 — accepted，31 个 FIELDS 深拷贝 + `table` 子快照。`有测试但未登记`。
3. `table_checkpoint.gd::capture()` @5 — accepted，`{state,revision,rngValue}`，`rngValue` 是重放关键字段。`有测试但未登记`。

### write（目录里 2 条：write_new / write_replace）
4. 首次写入 — accepted；`persistence_io.write_new`；`已登记且有后继状态证据`（save_store_test 断言文件存在；A5 探针复核读回全等且无 `.tmp`）。
5. 覆盖写入（原子替换：先写 `.tmp` → 复核 ok → rename）— accepted；`persistence_io.write_replace`；`已登记且有后继状态证据`。
6. `.tmp` 复核失败则不替换 — rejected（`ERR_FILE_CORRUPT`，旧档保持）；`A5探针新增证据`（静态锚点 `save_store.gd:19`；无独立负用例）。
7. 内存态未变则不重复写盘 / 盘上文件缺失或损坏则重建 — accepted；`有测试但未登记`（services_save_test）。
8. 写入失败（父目录缺失 / 目标为目录）— rejected，返回非 OK；`A5探针新增证据`（无既有测试）。

### read（目录里 5 条：missing/valid/corrupt/truncated/version）
9. 空档 → `missing`；`persistence_io.read_missing`；`已登记且有后继状态证据`。
10. 合法 → `ok`+state 全等；`persistence_io.read_valid`；`已登记且有后继状态证据`。
11. 摘要损坏（payload 改、digest 不重算）→ `invalid`；`persistence_io.read_corrupt`；`已登记且有后继状态证据`（services_save_test 另有下游）。
12. 版本不支持 → `unsupported_version` 并返回存档版本号；`persistence_io.read_version`；**已登记且有后继状态证据**：返回值可与摘要损坏区分，且拒绝后原文件字节不变（`existing-save_store_test.log`）。
13. 截断 / 长度前缀越界 / <4 字节 → `invalid`；`persistence_io.read_truncated`；**已登记且有后继状态证据**：当前正式测试对短文件、截断文件均断言拒绝后原始字节不变（`existing-save_store_test.log`）。
14. 存在但不可打开 → `unreadable`；`A5探针新增证据`（chmod 000 实测可达）。
15. payload 解码为非 Dictionary → `invalid`；`A5探针新增证据`。
16. payload 含完整序列化对象/资源 → `invalid`（`bytes_to_var` 拒绝，引擎返回 Nil）；`A5探针新增证据`。

### restore（目录里 4 条：valid/seated/replace_live_table/paused_seated）
17-20. `valid` / `seated` / `replace_live_table` / `paused_seated` — 各 accepted，且分别断言 `checkpoint_state()==baseline`、座位面板、活动桌被清空替换、pause 下座位面板隐藏；**均 `已登记且有后继状态证据`**。
21. 损坏文件 `load_checkpoint()` — rejected：不恢复、**保留原文件**、`saving_enabled=false`；`A5探针新增证据`（三向核对：世界状态不变 + 文件 hash 不变 + 自动存盘关闭。
22. 空档 `load_checkpoint()` — accepted：`saving_enabled=true` 且不创建文件；`A5探针新增证据`。
23. 带 `--playtest-seed` 的 save/load 守卫 — rejected（提前返回）；`有测试但未登记`（playtest_seed_test）。

### invalid_data（目录里 3 条：invalid_props / invalid_transform / outside_room）
24. props 非 Dictionary / 取值非 bool — rejected；`persistence_restore.invalid_props`；`已登记且有后继状态证据`。
25. 坐标/视角 NAN/INF — rejected；`persistence_restore.invalid_transform`；`已登记且有后继状态证据`。
26. 坐标越出房间包络 / 房间不符 — rejected；`persistence_restore.outside_room`；`已登记且有后继状态证据`。
27. **活动局与房间/座位的矛盾**（`world.gd:1001`）— **rejected**（**被校验**，既非修复也非错误接受）；`A5探针新增证据`。三例：`room=stash` 却 `active`；有活动桌却 `seated=false`；`seated=true` 却在 stash 房间。
28. **活动桌 id 与所在房间应属桌不符**（`world.gd:1005`）— rejected；`A5探针新增证据`（room=ledger 且已解锁时仍拒）。
29. 目标房间前置桌未完成（锁定房，`world.gd:1003`）— rejected；`有测试但未登记`（room_pool_test）。
30. 运行态嵌套字段逐类：资金/热度/桌面类型 `run_checkpoint.gd:25`；背包 `:94`；路线 `:45`；已知信息 `:36`；搜索 `:47`；结算/预览 `:54`；身份/预约/历史 `:60`；牌桌状态 `table_checkpoint.gd:9` / `:37`（重复牌、缺牌、多筹码、错 actor/bet/status/player/definition、rng 溢出、负 revision）— 全部 rejected；`有测试但未登记`（run_restore_bounds / reservation_restore / table_checkpoint / opponent_pool / venue_transfer / four_tables）。
31. 拒绝恢复**无部分副作用** — rejected；`A5探针新增证据`：13 类拒绝用例**全部** `world_unchanged=true`、隔离存档 hash 不变。

### legacy_migration（目录里 1 条：legacy_props）
32. run 可选 14 字段缺失回填（`run_checkpoint.gd:17`）— accepted；`有测试但未登记`。
33. world `props` 键缺失（`world.gd:993`）— accepted；`persistence_restore.legacy_props`；**已登记且有后继状态证据**。正式测试断言恢复后的完整世界快照等于基线、Tavernlight 可见属性回到默认值；随后通过隔离磁盘存档重新载入，确认自动存盘开启、进入暂停态，并能继续完成情报动作。2026-09-25 重跑 54 项检查通过，见 `output/external-handoff/A5/existing-world_restore_atomic_test.log`。
34. `search_results` 缺 `event`（`:51`）— accepted；`有测试但未登记`。
35. `variant_plan` 旧版本（version 2/3）— accepted；`有测试但未登记`（room_pool / opponent_pool，**有**回填后具体断言）。
36. 跨版本旧档（`version != 1`）— **rejected**（`invalid`，**不迁移**）；`A5探针新增证据`。
37. 「真实可读的旧格式夹具」— **`unverified`**：`Godot/three_d/tests/` 内**不存在任何 `*.save` 旧档夹具**，只有 `table-fixtures.json` / `poker-fixtures.json`。

### rng_replay（目录里 0 条）
38. 牌桌层重放（`table_checkpoint.gd:46`）— accepted；`有测试但未登记`（table_checkpoint_test，2031 checks，见 §5）。
39. 世界层重放（`world.gd::save_checkpoint/load_checkpoint`）— accepted；`A5探针新增证据`（见 §5）。
40. services_save_test 的 world 重放 — accepted，但只核对牌堆相等与一次合法动作、未比较后续可见结果；`有测试但未登记`。

---

## 5. 旧格式迁移与 RNG 重放的确切证据

### 5.1 旧格式迁移：夹具与前后断言

- **没有真实 on-disk 旧档夹具**。所有“legacy”用例都是**内存内** `Checkpoint.capture(...)` 后 `erase(field)` / 改 `version` 得到，**不是磁盘上可读的旧文件**。`tests/` 只有 `table-fixtures.json`、`poker-fixtures.json`。
- **前/后状态断言强度不一**：
  - 有具体后置断言（较强）：`scene_rules_test` 断言 legacy 恢复后 `scene_id == "smoky-den"`；`room_pool_test` 断言 version 3 后 `room_requirements("mirror-hall")==["ledger-cellar"]`；`opponent_pool_test` 断言 version 2 后 `table_definition("cargo-table").opponentIds == content.tables[...]`。
  - **只有“非 null / 返回 true”**（弱，按规则 3 判证据不足）：`run_restore_bounds_test` 的 legacy（删 14 字段）与“search 缺 event”、`venue_transfer_test`、`four_tables_test`、`event_pool_test`。`world_restore_atomic_test` 的 `legacy_props` 已于 2026-09-25 补充完整后继状态核验，不再属于此类。
- **迁移范围**：仅“VERSION==1 内缺失字段回填”（`run_checkpoint.gd:17-19` + `:51` + `:71`；`world.gd:993`）。**不存在跨版本迁移**——`read_checkpoint` 对 `version != 1` 返回 `unsupported_version`，`load_checkpoint` 保留原文件并关闭自动存盘。即 **VERSION 一旦升到 2，旧档将整体不可读**。A5 探针的 `version=99` 结论是对较早基线的历史记录；当前状态以正式测试 `existing-save_store_test.log` 和后续修复记录为准。

### 5.2 RNG 重放：依据的是“后续可见结果”，不是比较种子

**牌桌层（既有测试，最强）** `table_checkpoint_test.gd`：
对 `cargo-table`、`ledger-cellar` 各 10 个种子，**在每个动作边界**执行「写盘 → 读回恢复副本 → 原件与副本用同一套确定性规则各走一步」，断言
`Checkpoint.capture(copy) == Checkpoint.capture(original)`（该结构含 `rngValue`、`deck`、`community`、`players`、`handNumber`、`revision`）**且** `copy.public_state() == original.public_state()`，一直推进到 `finished`，期间跨越 `hand_over → next_hand`。共 2031 checks，全通过（`output/external-handoff/A5/existing-table_checkpoint_test.log`）。这是**真正的后续可见结果重放**，而非只比种子。

**世界层（A5 探针新增）** `repro/a5_world_replay_probe.gd`（`output/external-handoff/A5/probe-world_replay.log`）：
1. 参考世界真实入座、`start_table(4242)`，走到 hand 1 / table rng=`1320040479`，`save_checkpoint()` 写隔离文件（读回 status ok）。
2. **新实例** `load_checkpoint()` 从同一文件恢复并 `resume()`；恢复后立即断言 `public_state` 与 `rng.value` 与存档时刻全等。
3. 两侧**同步驱动 160 步**（敌方走 `world.advance_table_beat()` 真实消耗 `table.rng.next()`；我方走 `world.play_action`；`hand_over` 时走 `world.continue_hand`），逐步比较 **`public_state` + `rng.value` + `RunCheckpoint.capture(run)`**：
   `steps=160, mismatches=0, rng_equal_steps=160, hands_covered=[1,2], final_status=finished, final_rng=final_restored_rng=808510903`。
   覆盖了**下一手牌**（hand 1→2）与**后续可见结果**。
4. **负对照**：另起一对实例，把恢复方的 `rng.value` 故意 `+12345`，再同步驱动 60 步 → `negative_control_mismatches=60`，**证明上面的“0 分歧”不是空转**。

**结论：同一合法存档恢复后继续操作，RNG、下一手牌及后续可见结果**在牌桌层与世界层**都可重放**。
唯一偏弱的是 `services_save_test`：它只断言牌堆相等 + 折叠一次后 `revision+1`，未比较后续可见结果（即“只核对局部后继”）。

---

## 6. 总结论：哪些组缺证据 / 哪些组目录里根本没有

> **`capture`、`rng_replay` 两组在覆盖目录里根本没有**（0 条 `persistence_*` 登记）。
> `write`/`read`/`restore`/`invalid_data`/`legacy_migration` 五组已**部分登记**，但：
> - `read_version`、`read_truncated`、`persistence_restore.legacy_props` 后续均已在正式测试中补齐后继状态断言并重跑通过；不再列为缺证据项。
> - **有测试但未登记**（目录里没有对应 ID）：牌桌/世界 capture、写盘去重与自愈、`unreadable`/长度前缀/非字典 payload、锁定房拒绝、全部运行态嵌套非法字段、牌桌畸形状态、旧版本 variant_plan 回填、`playtest` 守卫、牌桌层 RNG 重放、services_save 的局部世界重放。
> - **只有 A5 探针新增证据（无既有 ID、无既有测试）**：`.tmp` 复核失败不替换、写入失败错误码、`unreadable`、payload 非字典、对象/资源 payload、活动局与房间/座位矛盾、活动桌 id 与房间不符、拒绝恢复三向无副作用、损坏 load 保留原文件、空档 load 启用存盘、**跨版本不迁移**、**世界层 RNG/下一手牌/可见结果重放**。
> - **完全缺证据**：**旧格式迁移无真实可读夹具**（`unverified`，见 §5.1）。

---

## 7. 疑似缺陷与未验证边界

**未发现使游戏不可玩的缺陷。** 以下为证据层面的缺口/边界，均以「最小复现 + 实际结果 + 证据」给主 Agent 定性（**不自行改规则**）：

1. **已修复：版本不支持可与摘要损坏区分**。当前 `read_checkpoint` 对未来版本返回 `unsupported_version` 和版本号；正式测试同时断言未来版本与截断/损坏文件拒绝后原字节不变。`probe-save_store.log` 中的 `version_unsupported.distinguishable_from_digest=false` 是旧基线探针结果，不代表当前行为。
2. **不存在跨版本迁移**（`read_checkpoint:35`）。若未来 `VERSION` 升为 2，所有旧档变 `invalid` 且自动存盘被关闭，用户将无法读档。当前 `VERSION=1` 未触发。
3. **写路径静默接受含 Object 引用的 state**（`save_store.gd:6` `var_to_bytes`）。实际：`write_checkpoint(path, {"node":Node})` → 返回 OK，读回 `status=ok`（对象以引用编码）；只有 `var_to_bytes_with_objects` 的**完整**序列化对象才会在读取时被拒。**公开入口不可到达**（`checkpoint_state()` 只含原生类型/Dictionary/Array，无 Object/Resource），故列为“不可达但存在”的边界。
4. **读取含完整序列化对象的 payload 会向日志打印引擎 `ERROR`**（`decode_variant` `ERR_UNAUTHORIZED`）。不是崩溃，但会让“日志含 ERROR 即失败”的判定在该输入下误报——取证时需知道这是**预期拒绝**（见 `probe-save_store.log`）。
5. **旧格式迁移无真实磁盘夹具**（§5.1）仍是主要证据缺口；部分弱断言列表已按当前正式测试更新。

**未验证 / 未做到（如实列出）**：
- 未制造任何真实存档损坏样本（按要求）。
- 写入失败只测了“父目录缺失 / 目标为目录”；**未测**真实磁盘满（ENOSPC）或只读卷，因此 `write_checkpoint` 里 `file.get_error()`（flush 后分支，`save_store.gd:14-17`）**未被单独触发**（只由静态阅读确认存在）。
- 「对象引用 payload 跨进程重启后读回什么」未验证（同上，公开入口不可达，标为不可达而非通过）。
- `world.gd` 的 `return_transform`/`caseOpen`/`look` 只在 `restore_checkpoint` 的 world 用例里覆盖，未单独逐字段做“非法值矩阵”（部分由 `invalid_transform` 与 A5 探针的 `look_not_vector`/`return_nan_seated` 覆盖）。
- 一次非隔离批量运行被上层删除拦截规则中断（见 §1.1 遗留 `.tmp`）；此后所有既有测试改用隔离 `HOME` 重跑。

---

## 8. 交付文件与证据清单

交付目录：`docs/3d-production/external-handoff/A5-persistence-audit/`

- `README.md`：本文件。
- `outcomes.csv`：49 行，七组齐全（capture 3 / write 6 / read 8 / restore 7 / invalid_data 16 / legacy_migration 6 / rng_replay 3），15 条既有 ID 各一次（去重映射），1 行 `unverified`。
- `repro/`（仅新增诊断，均只读/隔离）：
  - `a5_save_store_probe.gd`、`a5_world_contradiction_probe.gd`、`a5_world_replay_probe.gd`、`a5_userdir_probe.gd`、`verify_outcomes.py`
- `output/external-handoff/A5/`（原始日志，`exit_code` 与正文均核对）：
  - 探针：`probe-save_store.log`、`probe-world_contradiction.log`、`probe-world_replay.log`、`probe-userdir.log`
  - 既有测试（隔离 HOME 重跑，全部 exit=0、日志 0 条 `ERROR`/`SCRIPT ERROR`）：`existing-{save_store_test,world_restore_atomic_test,services_save_test,table_checkpoint_test,run_restore_bounds_test,reservation_restore_test,room_pool_test,opponent_pool_test,four_tables_test,playtest_seed_test,venue_transfer_test,completion_checkpoint_test,table_integration,scene_rules_test,event_pool_test}.log`
  - 隔离临时文件：`output/external-handoff/A5/tmp/`（含 `iso-home/`）

收尾自检 `repro/verify_outcomes.py` 结果：`rows=49`、`catalog_ids_mapped=15/15`、所有 `evidence_path` 存在、`source_line` 按内容锚点命中、七组齐全、既有 ID 不重复、CSV 可被 `csv` 解析且列数一致。

> 说明：跑既有测试会按其自身设计刷新 `output/3d/*.json`（如 `persistence-io-coverage.json`、`persistence-restore-coverage.json`、`four-tables.json`、`table-integration.json` 等），这是既有测试的常规产物，非本 Agent 另行写入；覆盖目录 `docs/3d-production/phase-1/coverage/` 未被改动（hash 一致）。

## 2026-09-25 后续源码锚点复核

主 Agent 在当前工作树重跑自检时发现本 CSV 的 17 个 `source_line` 已随源码演进失配，其中版本判定锚点也已从 envelope 入口调整为 `stored_version` 检查。现按当前源码行与实际条件更新这 17 处定位；49 行、七组内容、15 个既有目录 ID 及原始证据结论不变。`python3 docs/3d-production/external-handoff/A5-persistence-audit/repro/verify_outcomes.py` 复核通过（`catalog_ids_mapped=15/15`）。

在本次定位刷新后，主 Agent 又增强了 `save_store_test.gd`：对摘要损坏、未来版本、短文件及截断文件，测试逐字节确认读取拒绝后原文件没有变化；`read_version` 还断言 `unsupported_version` 与版本号。现按该当前证据更新 outcomes.csv 与 §3、§5、§6、§7；A5 探针原始日志保留为历史基线，不再代表当前状态。

随后 `save_store.gd` 的写失败清理逻辑增加了 4 行，主 Agent 重跑锚点自检并更新受影响的 9 个 `source_line`。当前 A5 自检仍为 `catalog_ids_mapped=15/15` 且通过；本轮另将“创建临时文件失败”与“重命名替换失败并清理 `.tmp`”登记为正式 `persistence_io.*` 回归结果。
