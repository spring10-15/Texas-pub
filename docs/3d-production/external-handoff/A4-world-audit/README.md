# A4 世界交互状态转移取证

> **主 Agent 复核补记（2026-09-25）**：CSV 第 8 行原标为“源码未实现”，依据是当时没有静态 anchor 把 `enabled` 设为 false；但 `interactable.gd::prompt()` 与 `player.gd::can_interact()` 的导出属性分支都已实现，不应把“现有场景无此实例”写成“源码未实现”。现已用引擎测试实例设置禁用状态，断言提示原因、拒绝交互及完整世界快照不变，并登记为 `world.interactable_disabled`。随后补上酒保出售贵重物的 `world.services_sell` 后继：现金、物品、行动力、revision 与服务面板刷新均由正式入口断言。截至当前补记，正式世界子图 70/70、全目录 357/357 均有同版本证据；目录仍不完整，不能计算全局覆盖率。下文 2026-09-23 的 72 行盘点保留为当时快照。

日期：2026-09-23。范围：`Godot/three_d/scripts/world.gd`（`request_action`、`travel`、`leave_seat`、`pause_game`、`resume`、`show_run_panel`、`close_run_panel`、`confirm_run_action`、`open_services`、`close_services`、`service_action`）及被它们调用的 `scene_props.gd`、`player.gd` 交互逻辑。**不含** `world.gd::restore_checkpoint` / `save_checkpoint` / `load_checkpoint`（A5 领域），本文件只做对照。

## 1. 基线

| 项 | 值 |
|---|---|
| `git rev-parse HEAD` | `07f22459ffb341a0d5246818c5e9f3270c7d5bac` |
| `git status --short` | 全部为 `??` 未跟踪项，**无已跟踪文件被修改**；本任务未改动任何已跟踪文件 |
| Godot | `/Applications/Godot.app/Contents/MacOS/Godot`，`4.7.2.stable.official.ed1daf0bf`（PATH 中无 `godot` 命令） |
| 正式存档 | `~/Library/Application Support/Godot/app_userdata/Godot德扑酒馆/three-d-checkpoint.save` |

正式存档 mtime 前后比对（证据见 §7）：

- 开工前：`1788939073` → `Sep  9 15:31:13 2026`
- 收工后：`1788939073` → `Sep  9 15:31:13 2026`

两次一致，本轮**未读写正式存档**。

工作区原有 `??` 项（`A3-poker-audit/`、`A5-persistence-audit/`、`B-*`、`C-*`、`V1-*` 等）均原样保留，未触碰。

## 2. 运行命令

```bash
cd "<仓库根>"
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/A4/a4-world-probe.log --timeout 300 \
  -- --script "<仓库根>/docs/3d-production/external-handoff/A4-world-audit/repro/a4_world_probe.gd" -- --test

python3 docs/3d-production/external-handoff/A4-world-audit/repro/verify_outcomes.py
```

第一次结果：`exit_code=1`，`cases=115 fails=1`（失败项 `forced_seat` 是**探针自身**的阶段污染——上一阶段已真实完成 `cargo-table`，同 run 不能重打该桌）。
修复后（换一个全新 `Run` 作为前置条件）第二次结果：**`exit_code=0`，`cases=115 fails=0`**，日志正文无 `SCRIPT ERROR` / `ERROR`。两次日志以第二次为准，落盘于 `output/external-handoff/A4/a4-world-probe.log`。

CSV 自检：`PASS`（72 行、八组齐全、13 列一致、`source_line` 内容锚点按源码重新推导全部命中、所有 `evidence_path` 存在）。

### 关于 `repro/` 里的另一个文件

`repro/probe_world_transitions.gd` 与 `output/external-handoff/A4/probe-world.log` 是**更早一次不完整尝试的残留**（时间戳 18:00，本轮开工前已存在，交付目录内没有配套 README/CSV）。我没有删除或修改它，但**没有把它当证据**。已确认它失败的原因全是探针缺陷，不是游戏缺陷：

1. `world.service_action(...)` 返回 **void**，原脚本写成 `var r2: bool = world.service_action(...)`，抛 `SCRIPT ERROR` 后 `services_panel` 未被关闭、`controls_enabled` 一直为 `false`，导致其后 8 条 `no landing offset reached anchor` 与 `post_table_heat_is_one` 全部假失败（级联）。
2. 抽屉这类道具会把自身 anchor 一起平移，原脚本复用旧瞄准，导致 3 条 `prop_drawerN_reverse` 与 1 条 `prop_window_reverse` 假失败。

重做版 `repro/a4_world_probe.gd` 修正了这两点（每次交互前重新瞄准、每个阶段显式关面板复位），同一批语义结果全部 PASS。

## 3. 八组逐条结论

八组的完整逐行证据见 `outcomes.csv`（`family` 列）。汇总：

| 组 | 行数 | 结论 | 主要 `evidence_status` |
|---|---|---|---|
| `room_entry` | 14 | `confirm_run_action` 五分支（enter/transfer/extract/abandon/reset）全部已登记且有后继状态证据；**`travel()` 五目的地、`room:*`/`enter_ledger`/`back_tavern` 跨房间进入、`show_run_panel` 各分支、`close_run_panel`、`discover_exit`、`confirm` 的三类拒绝**目录里都没有登记 | 已登记×5、有测试但未登记×4、有A4探针×5 |
| `seat` | 3 | `sit` 接受与"房间/前置未满足"拒绝已登记且有后继状态证据；**入座态再触发世界锚点被拒**目录里没有（且与 `can_interact` 的 `controls_enabled` 项重合） | 已登记×2、有A4探针×1 |
| `leave_seat` | 7 | pregame/active/finished/unseated 四条已登记且有后继状态证据；**`paused` 拒绝**目录里没有；**`settle_table` 失败拒绝**仅凭静态阅读判定为 `unverified`；**经 `leave_seat` 触发风声封锁强制撤离**此前只在 `check_pressure()` 入口被测过 | 已登记×4、有A4探针×2、unverified×1 |
| `pause` | 5 | `pause_game` 接受（非入座 / 入座两种后继）与 `request_action` 的 `pause_guard` 都已登记且有后继状态证据；**重复调用 `pause_game`** 未找到测试；**`toggle_pause` 的分派**（services→关闭 / run_panel→关闭 / paused→resume / 入座未开局→leave_seat / 其它→pause）有测试但未登记 | 已登记×3、有测试但未登记×1、未找到测试×1 |
| `resume` | 3 | 非入座 / 入座两种后继都已登记且有后继状态证据；**重复调用**未找到测试 | 已登记×2、未找到测试×1 |
| `physical_raycast` | 7 | 已登记的 `world.raycast_unfocused` 有后继状态证据；**距离超过 `REACH=2.0`**、**实心遮挡**目录里都没有（遮挡既有测试只核返回值 → 证据不足）；**focus 命中 / 未命中 / `controls_enabled=false` 的 three-state** 有测试但未登记；**`anchor.enabled=false` 分支源码未实现**（全仓库无赋值点） | 已登记×1、有A4探针×3、有测试但未登记×2、源码未实现×1 |
| `prop_interactions` | 19 | 已登记 5 条（`world.prop_on` / `prop_visual` / `prop_drawer0` / `prop_window` / `prop_card` / `prop_chip`）全部是**正向 accepted**；**所有道具的关闭/翻回方向、四室壁灯（4 个 ID）、四室餐具柜（4 个 ID）、跨道具共享 `busy`、皮箱盖 `toggle_case` 正反两向**目录里都没有 | 已登记×6、有A4探针×10、有测试但未登记×2、不可到达×1 |
| `modal_guards` | 14 | 已登记的 `world.modal_guard`（服务弹窗）/`pause_guard`/`busy_guard` 有后继状态证据；**`run_panel` 可见时的拒绝**目录里没有；**`open_services`/`close_services`/`service_action` 一条 `world.*` 都没有登记** | 已登记×3、有A4探针×9、有测试但未登记×2 |

### 3.1 必须明确回答的那句总结论

**目录里根本没有、且确实缺证据的组（需要新增 `world.*` 条目）**：

- **`prop_interactions` 的反向/关闭方向**（`world.prop_*` 清一色 accepted 正向，没有任何"翻回/关上"结果）；
- **`prop_interactions` 里四室壁灯与四室餐具柜**（`Tavernlight`/`Taverncupboard`/`LedgerCellarlight`/`LedgerCellarcupboard`/`MirrorHalllight`/`MirrorHallcupboard`/`EmbersRoomlight`/`EmbersRoomcupboard` 共 8 个 ID，全仓库无任何测试）；
- **皮箱盖 `toggle_case`**（`request_action` 内实现，不走 `props.interact`，24 条里无一条涵盖）；
- **`modal_guards` 的 `run_panel` 可见时的拒绝**、**`open_services` 的 paused/run_panel 两条拒绝**、**`close_services` 的控制权恢复**；
- **`service_action` / `open_services` / `close_services` 三个入口一条 `world.*` 都没有**（这是本轮最大的真实空白区）；
- **`room_entry` 的跨房间进入**（`travel()` 五目的地、`room:*` / `enter_ledger` / `back_tavern` 接受与锁定拒绝）、**`show_run_panel` 各分支**、**`close_run_panel`**、**`confirm_run_action` 的三类拒绝**（面板未显示 / 暂停中 / confirm 被禁用）；
- **`physical_raycast` 的距离不足、实心遮挡、以及 `can_interact` 的 three-state 本身**；
- **`seat` 的入座态再触发世界锚点被拒**；
- **`leave_seat` 的 paused 拒绝**；
- **`pause` 的重复调用与 `toggle_pause` 分派、`resume` 的重复调用**（后两者仅列观察，未取证）。

**已登记、但缺后继状态证据的组（需要补测试断言，而不是新增 ID）**：

- 严格按"只核返回值/只核 trace 就标证据不足"的口径，本轮**没有**发现"已登记但完全无后继状态证据"的条目——24 条中 A4 范围内的 23 条在 `world_coverage_test.gd` 里都做了 `checkpoint_state()` 快照或字段级后继断言。
- 但**未登记的结果**里有 3 处既有测试属于"只核返回值/只核 trace"的证据不足，需要在补测试时按下游状态补齐（详见 §6）：`smoke.gd` 的实心遮挡、`two_tables.gd:62`与`room_pool_test.gd:83` 的锁门拒绝、`playtest_seed_test.gd:32-36` 的服务动作拒绝/接受、`two_tables.gd:77` 的 `discover_exit`。这些我都用本轮探针补上了快照断言，但**它们对应的 `world.*` ID 仍待新增**。

因此：**"目录里没有且确实缺证据"是 A4 的主要缺口（47 行候选中 41 行已取证、6 行未取证）；"已登记但缺后继状态证据"在 A4 范围内不成立（23 条全部有后继状态证据），缺口集中在未登记结果上。**

### 3.2 新增分母的算法（不重复计入 24 条）

- `outcomes.csv` 共 **72** 行。
- 其中 **25** 行带 `existing_catalog_id`（引用已登记 `world.*`）。24 条已登记结果中 **23 条**属 A4 范围（`world.prop_restore` 归 A5，本文件只做对照）；这 23 条在 CSV 里被 **25** 行引用（`world.pause` 与 `world.resume` 因"非入座/入座"两种后继各占 2 行，属同一 ID 的不同前置条件类别，**不新增分母**）。
- 剩余 **47** 行 `existing_catalog_id = "(无)"`，即**候选新增语义结果**。其中：
  - `有测试但未登记` **15** 行（仓库既有测试已证，仅缺覆盖目录登记）；
  - `有A4探针后继状态证据` **26** 行（本轮探针取证）；
  - 未取证 **6** 行：`未找到测试` 3、`不可到达` 1、`unverified` 1、`源码未实现` 1 → **不计入已证实分母**。
- 故：**已证实的候选新增语义结果 = 15 + 26 = 41 行**，**不可计入的 = 6 行**。

`evidence_status` 取值（在任务书建议值基础上扩展了两个，README 在此定义）：

| 取值 | 含义 | 行数 |
|---|---|---|
| `已登记且有后继状态证据` | 该结果在 `transitions.json` 有 `world.*` ID，且既有测试做了后继状态/快照断言 | 25 |
| `有测试但未登记` | 仓库既有测试已证该结果，但覆盖目录没有对应 ID | 15 |
| `有A4探针后继状态证据` | 仅本轮探针 `a4_world_probe.gd` 做了后继状态断言 | 26 |
| `未找到测试` | 既有测试与本轮探针都未覆盖 | 3 |
| `不可到达` | 公开入口无法构造该前置条件 | 1 |
| `unverified` | 分支存在于源码，但未构造出可达实例，仅凭静态阅读无法确定 | 1 |
| `源码未实现` | 源码里根本没有这条交互 | 1 |
| `证据不足` | 既有测试只核了返回值 / 只核了 trace，未核后继状态（本列会把这类行按最强证据归类，同时在 `notes` 里以 `既有测试证据不足` 标注，见 §6） | 0（全部并入 `notes` 标注） |

## 4. 道具清单与 6 类情形矩阵

`register(...)` 的**全部调用点**（`scene_props.gd` 是被 `world.gd` 调用的唯一注册者）：

- `scene_props.gd:25` → `lamp`；`:36`（3 次循环）→ `drawer0/1/2`；`:54` → `window`；`:89` → `card`；`:104` → `chip`
- `scene_props.gd:110` → `prefix+"light"`；`:117` → `prefix+"cupboard"`；`prefix` 由 `world.gd:299` 的 `props.build_tavern(room, room_name)` 给出，`room_name ∈ {Tavern, LedgerCellar, MirrorHall, EmbersRoom}`

**共 15 个道具 ID**：`lamp`、`drawer0`、`drawer1`、`drawer2`、`window`、`card`、`chip`、`Tavernlight`、`Taverncupboard`、`LedgerCellarlight`、`LedgerCellarcupboard`、`MirrorHalllight`、`MirrorHallcupboard`、`EmbersRoomlight`、`EmbersRoomcupboard`。

另有 1 个**非 `props` 道具**：皮箱盖 `case_target`（`action_id="toggle_case"`，由 `world.gd:500-510` 直接实现，不走 `scene_props.interact`）。

矩阵（`✓`=接受并核对后继；`✗`=拒绝且 `checkpoint_state()` 不变；`—`=该情形不存在）：

| 道具（ID） | 开启 | 关闭/翻回 | 动画忙碌 | 准星未对准 | 距离不够 | 暂停/弹窗阻挡 |
|---|---|---|---|---|---|---|
| `lamp` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `drawer0` / `drawer1` / `drawer2` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `window` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `card`（翻面） | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `chip`（转动） | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| 四室 `<Room>light`（4 个） | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| 四室 `<Room>cupboard`（4 个） | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| 皮箱盖 `toggle_case` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |

要点：

- **开启 / 关闭（翻回）由同一入口 `props.interact` 的同一个 toggle 实现**（`scene_props.gd:13`），方向只由 `states[id]` 当前值决定；因此每类道具的"开启"和"关闭"是两个后继状态不同的语义结果（`opened` vs `closed`）。
- 四室壁灯后继一致（`light_energy`：0.8 ↔ 0.0），四室餐具柜后继一致（`rotation:y`：0.0 ↔ ‑1.2），故各合并为一条，房间差异只在前缀。
- **`动画忙碌` 是道具间共享的**：`scene_props.gd:14` 把 `world.action_busy` 置真，`world.gd:477` 用它拒绝；所以 A 道具动画期间按 B 道具同样被拒（`cross_prop_busy`）。
- **抽屉会把自身 anchor 一起平移**（`register` 里 node 与 anchor 都指向 `drawer`），所以拉开抽屉后不重新瞄准就按 E 会因射线偏离而无效——这是空间关系的结果，不是拒绝逻辑。
- 三种"弹窗/暂停阻挡"以及"未对准/距离不够"在自然路径下都会连带 `controls_enabled=false`，无法归因到具体守卫项；只有 `action_busy` 不关控制，是唯一可独立观测的守卫（§5）。
- **不存在的交互**：`props.interact(未注册 id)` 写入 `entries[id]` 会缺键，但所有 `prop:*` 锚点都由 `register(...)` 与 `world.target(...)` 成对创建，公开入口无法构造未注册 id → 记 `不可到达`，未虚构任何交互。

## 5. 互斥与守卫的关键结论

`world.gd:477` 的单一 `if` 把 5 个条件并在一起：

```gdscript
if paused or run_panel.visible or services_panel.visible or seated or action_busy or not player.can_interact(anchor):
    return false
```

而 `player.can_interact`（`player.gd:70-72`）在 `controls_enabled=false` 时恒为 `false`。**`pause_game` / `show_run_panel` / `open_services` / `sit` 都会把 `controls_enabled` 置 false**，因此 `paused` / `run_panel.visible` / `services_panel.visible` / `seated` 这四项在自然路径下**总是被 `not player.can_interact` 掩盖**，无法归因；只有 `action_busy` 不改控制，是唯一可独立观测的守卫项。

为区分"守卫项本身是否生效"，探针用 `A4ISO` 标注显式把 `controls_enabled` 暂时置真做了隔离实验（`guard_paused_isolated`、`guard_run_panel_isolated` 均 PASS：此时 `request_action` 仍返回 false 且快照不变）。**该实验只用于隔离守卫项，不作为"玩家可达路径"证据。**

## 6. 既有测试"证据不足"清单（只核返回值 / 只核 trace）

按任务书口径（"现有测试若只核对返回值而未核对后继状态，应标为证据不足"），以下既有断言不充分；对应语义结果在 `outcomes.csv` 的 `notes` 里以 `既有测试证据不足` 标注，并已由本轮探针补齐快照断言：

| 既有测试 | 缺口 | 本轮补的证据 |
|---|---|---|
| `Godot/three_d/tests/smoke.gd:47-50` | 只核 `request_action` 返回 false，未核 `focused`/快照 | `raycast_occluded_solid` |
| `Godot/three_d/tests/two_tables.gd:62`、`Godot/three_d/tests/room_pool_test.gd:83` | 锁门拒绝只核返回值 | `room_door_blocked` |
| `Godot/three_d/tests/playtest_seed_test.gd:32-33` | 服务动作被拒只核 trace 未新增一行 | `service_action_not_offered_noop` |
| `Godot/three_d/tests/playtest_seed_test.gd:34-36` | 服务动作接受只核 trace 追加 | `服务动作非 buy 分支的子断言`（见 CSV `service_action` 非 buy 行） |
| `Godot/three_d/tests/two_tables.gd:77` | `discover_exit` 只核返回 true | 探针 `discover_exit` 分支（含 public_exit/title） |
| `Godot/three_d/tests/scene_rules_test.gd:88-89`、`Godot/three_d/tests/extraction_fallback_ui_test.gd:36-60` | 只断言 `run_confirm.disabled` 与面板文本，未断言确认后 run 状态不变 | `confirm_disabled_*` |

## 7. 诊断脚本与日志

| 文件 | 说明 |
|---|---|
| `docs/3d-production/external-handoff/A4-world-audit/repro/a4_world_probe.gd` | **本轮探针**（重做版）。只走公开入口、真实相机射线、每用例核 `checkpoint_state()`；找不到输入一律 FAIL，无静默跳过 |
| `docs/3d-production/external-handoff/A4-world-audit/repro/verify_outcomes.py` | 交付自检：CSV 可解析、八组齐全、列数一致、`evidence_path` 存在、`source_line` 按内容锚点重新推导 |
| `docs/3d-production/external-handoff/A4-world-audit/repro/probe_world_transitions.gd` | 更早一次不完整尝试的残留，**未修改、未采用**（原因见 §2） |
| `output/external-handoff/A4/a4-world-probe.log` | 本轮探针原始日志（`exit=0`，`cases=115 fails=0`，无 `SCRIPT ERROR`/`ERROR`） |
| `output/external-handoff/A4/probe-world.log` | 更早那次残留日志（`exit=1`），仅作对照 |

探针不写正式存档：`--test` 下 `world._ready()` 跳过 `load_checkpoint()` 且不开自动存档；探针另把 `world.save_path` 指向 `user://a4-probe-must-never-exist-<pid>.save` 并在收尾断言该文件未生成（`no_save_file_written` PASS）。

## 8. 疑似缺陷

**未发现功能性缺陷。**

三处观察（均非缺陷，仅记录，不自行改规则）：

1. **`interactable.enabled` / `disabled_reason` 已验证，不再是疑似缺陷**：虽然场景当前没有静态禁用 anchor，正式世界测试通过实例设置 `enabled=false`，验证提示显示禁用原因、交互被拒绝且完整世界快照不变；见 `world.interactable_disabled` 与本文件开头补记。
2. **`discover_exit` 幂等但返回 true**：重复按出口告示仍返回 `true`，但 `run_game.revision` 与运行状态不变（`public_exit` 已为 true）。语义等价于 no-op，不是状态泄漏。
3. **`pause_game()` 与 `open_services()` 可同时可见**：`pause_game` 不关闭 `services_panel`（只有 `toggle_pause` 的分派会先关）。这只在程序化调用下发生，键鼠路径由 `toggle_pause` 保证互斥，不构成可达缺陷。

## 9. 未验证边界

- `leave_seat` 的 `settle_table(...)` 失败拒绝（`world.gd:568`）：源码存在该分支，但未构造出可达实例 → `unverified`，不计入已证实分母。
- `pause_game()` / `resume()` 的**重复调用**（无入参守卫）：键鼠路径由 `toggle_pause` 统一路由，重复调用只能程序化触发；本轮未取证 → `未找到测试`。
- `toggle_pause` 中"services 可见时按 Esc 先关弹窗"的互斥顺序：本轮未取证 → `未找到测试`。
- 探针在 headless 下运行，未断言 `Input.mouse_mode`（各入口确实设置了它，但 headless 下该属性无显示意义）；`controls_enabled` / `crosshair.visible` / 面板可见性均已断言。
- 快照比较 `checkpoint_state()==before` 依赖 Godot 4 `Dictionary`/`Array` 的结构化相等；既有测试（`world_coverage_test.gd`）已按同一方式使用，本轮沿用同一假设。
- 探针里标注为 `A4ISO` 的共 7 条，归纳为 **4 类显式构造的前置条件**（`completed` 注入并有复原步骤、`heat=6`+`ivory-chip` 注入、`controls_enabled` 暂时置真以隔离守卫项、用新 `Run` 替换 `run_game`）。它们只为到达分支，**不作为玩家可达路径证据**。
