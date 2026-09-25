# 任务 A｜问题报告（issues.md）

更新：2026-09-21。对应代码版本见 `README.md` 中的 `git rev-parse HEAD`。

本文件只写**本次真实执行中复现到**的问题。每条都标注了性质：

- **环境/夹具**：由本次执行链（后台进程 / 沙箱 / 调用方式）造成，**不是游戏逻辑缺陷**，但会让存档回归无法自动化。
- **测试问题**：测试脚本自身的缺陷。
- **待查线索**：未证实，只给查证方法，不作为缺陷结论（见文末）。

判定规则按任务书 3.3：脚本报 `SCRIPT ERROR` / `Parse Error` / `ERROR` 时，**即使退出码为 0 也不判通过**。

---

## A-1｜整轮串行执行时，三个存档类套件「首个写入」即失败，且进程永久挂起

| 项 | 内容 |
|---|---|
| 编号 | A-1 |
| 性质 | **环境/执行链问题（已确认根因，非游戏缺陷）**：执行环境以 `file-write-unlink` 为由拦截 `user://` 目录的改名操作 |
| 严重程度建议 | **中**（原先按"中高"估，定性后下调）。不影响玩法与规则；影响是"在受限环境里跑存档回归会假失败并挂住整条流水线" |
| 是否稳定复现 | 分环境稳定：**受限环境（后台任务）整轮 4/4 失败**；**无沙箱环境整轮 1/1 全部通过**（`table_checkpoint` 2021 项、`save_store` 8 项、`services_save` 46 项） |
| 影响范围 | `table_checkpoint_test`、`save_store_test`、`services_save_test`，以及任何依赖 `Store.write_checkpoint()` 的自动化 |

### 前置状态

- Godot `4.7.2.stable.official.ed1daf0bf`（`/Applications/Godot.app/Contents/MacOS/Godot`）。
- 工作树干净、版本见 README；`Godot/.godot` 缓存存在，未重建。
- `user://` 目录可写（运行器预检 `create+rename OK`）→ 排除「目录不可写」。
- 工作目录为项目根，命令带 `-- --test`（见 A-3）。

### 复现步骤

整轮（失败）：

```sh
cd "/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安"
python3 output/external-handoff/A/run_suites.py
```

单独（通过）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot \
  --script res://three_d/tests/table_checkpoint_test.gd -- --test
```

### 预期

`TABLE_CHECKPOINT {"checks":2021,"failed":0}`，exit 0，约 1 秒结束。

### 实际

1. `ERROR: Every action boundary can be saved`
   —— `table_checkpoint_test.gd:11` 的 `verify()` 经 `push_error` 输出，调用点 `table_checkpoint_test.gd:31`，即 `Store.write_checkpoint(path, Checkpoint.capture(original)) != OK`。
2. `SCRIPT ERROR: Invalid access to property or key 'state' on a base object of type 'Dictionary'.`
   —— `table_checkpoint_test.gd:32` 直接读 `Store.read_checkpoint(path).state`，而失败时返回的字典没有 `state` 键（`save_store.gd:25/28/32/35/38`）。
3. 脚本在 `_initialize()` 抛错后中断，**没有执行到 `quit()`**（`:43`），**进程不退出**，一直占用到外部 SIGKILL。整轮里它会卡住整条流水线（本次实际卡了 668s 与 5116s 两段）。
4. `user://table-checkpoint-test-<pid>.save.tmp` 残留（5620 字节）。

同一失败模式在 `save_store_test` 上表现为 3 项断言失败（`Writes checkpoint` / `Exact round trip including integer cards and vector` / `Atomically replaces existing checkpoint`）+ 同一条 `SCRIPT ERROR`（`save_store_test.gd:19`），同样不退出。

### 日志

- 整轮失败现场：`output/external-handoff/A/logs/table_checkpoint_test.log`、`.../save_store_test.log`
- 单独通过（同名套件单跑，2021 项全绿）：`output/external-handoff/A/logs-secondrun/table_checkpoint_test-standalone-1.log`、`-2.log`
- 挂起现场（`user://logs/godot.log` 快照）：归档在 A 证据目录的 `logs-*` 各轮次中

### 根因（已确认）

失败不在游戏代码，也不在第 19 行的回读校验，而在 **`save_store.gd:21` 的 `DirAccess.rename_absolute(temporary, path)`**：执行环境（后台任务所在的沙箱）以 **`file-write-unlink`** 为由拒绝该目录下的改名/删除操作。沙箱给出的拦截报告原文见
`output/external-handoff/A/logs-sandboxed-run/SANDBOX-DENIAL-根因证据.md`：

```
[sandbox] 命令被沙箱拦截，以下操作被拒绝：
  - .../Godot德扑酒馆/logs/godot2026-09-21T20.11.16.log        (file-write-unlink)
  - .../Godot德扑酒馆/table-checkpoint-test-88556.save.tmp       (file-write-unlink)
  - .../Godot德扑酒馆/checkpoint-test-89638.save.tmp             (file-write-unlink)
  ... 及其他 5 项
```

被拒文件里正好包含这两个套件留下的 `.tmp`，与"写入被允许、改名被拒"完全对应：

| 排查项 | 方法 | 结果 |
|---|---|---|
| 是否 API 用法错误 | `output/external-handoff/A/repro/diag_write_error.gd`，小状态 60 字节 | 全部 `err=0`，rename 成功 |
| 是否 payload 太大 | `output/external-handoff/A/repro/diag_write_bigstate.gd`，真实牌桌状态 5472～7940 字节 + 同路径连续写 60 次 | **8/8 通过，60 次连续写 0 失败** |
| 是否后台本身是变量 | 同一份 `diag_write_bigstate.gd` 前台/后台各跑一次 | 两次都全绿 → 后台不是变量，**沙箱权限才是** |
| 失败点在第 19 行还是第 21 行 | `output/external-handoff/A/repro/diag_leftover_tmp.gd` 给残留 `.tmp` 验尸 | `.tmp` **完全有效**（5620 B、`status=ok`、digest 匹配、可解码）；对全新文件与副本实测 rename 均为 0 → 回读通过，**失败在改名** |
| 是否只有这三个套件受影响 | 完整整轮 31 项 | 只有调用 `write_checkpoint()` 的三个套件失败，其余 28 项全通过 |

### 修好的地方（本任务侧）

运行器的环境预检已从「Python 层 create+rename」升级为**双层预检**，第二层会真正调用一次 `Store.write_checkpoint()`
（`output/external-handoff/A/repro/preflight_write.gd`，输出 `PREFLIGHT_WRITE err=… tmp_left=… dest_exists=…`）。
原因是踩过坑：**Python 层的 create+rename 能通过，而 Godot 的 rename 仍可能被拦**，只做第一层会放行一轮注定假失败的运行。
现在预检不通过就直接中止并打印原因，不再产出污染结果。

### 交付用结果

本文件所属的 `test-results.csv` 取自**无沙箱环境下的整轮复跑**（`output/external-handoff/A/logs/`），三个存档套件在该环境下全部通过。
受限环境那一轮的日志单独归档在 `output/external-handoff/A/logs-sandboxed-run/`，作为本条问题的现场证据保留。

---

## A-2｜测试夹具缺陷：写入失败后不退出，导致进程无限挂起

| 项 | 内容 |
|---|---|
| 编号 | A-2 |
| 性质 | **测试问题**（不是游戏问题） |
| 严重程度建议 | 中。它把一个「断言失败」放大成「整条流水线卡死」，是 A-1 之所以耗时数十分钟的直接原因 |
| 是否稳定复现 | 稳定（只要写入失败必现） |
| 影响范围 | 任何无外部超时的自动化执行方式 |

### 证据

- `save_store.gd:23-39`：`read_checkpoint()` 在 missing / unreadable / invalid 时分别返回 `{"status":"missing"}`、`{"status":"unreadable"}`、`{"status":"invalid"}`，**三者都不含 `state` 键**；只有成功分支返回 `{"status":"ok","state": state}`。
- 三个测试直接取 `.state`，未先判 `status`：
  - `table_checkpoint_test.gd:32`
  - `save_store_test.gd:19`
  - `services_save_test.gd:109`
- 三个测试都只用 `quit(0 if failures.is_empty() else 1)` 收尾，**异常路径没有兜底**，GDScript 运行时错误会中断 `_initialize()`，`quit()` 永不执行。
- **一次独立复现（本轮新增，作者已事先知道这个机制、仍然踩中）**：为验证 A-5b 写的临时探针 `output/external-handoff/A/repro/probe_second_table_names.gd` 在 `run()` 中段因场景前置条件未满足而中断，`quit(0)`（`:77`）从未执行，进程**静默运行 17 分钟后被 SIGKILL**（`pipeline` 到 `tail` 还把输出也一起吞了，导致"零输出 + 零退出"）。作者已经读过本条目、仍然复现 → 说明这不是某几个套件的偶然写法，而是**该夹具模式的结构性缺陷**：任何未捕获异常都会把"测试失败"变成"进程永久占用"。这也解释了本任务首轮的耗时异常。

### 预期 / 实际

预期：写入失败时打印失败断言并以非 0 退出，日志里能看到失败原因。

实际：先报 `ERROR:` 再报 `SCRIPT ERROR:`，然后进程挂到天荒地老（本次三次分别挂了 668s / 5116s，最后都用 SIGKILL 收场）。

### 建议（供主 Agent 取舍，外部 Agent 未改动）

```gdscript
var loaded := Store.read_checkpoint(path)
verify(loaded.get("status") == "ok", "写入后应可回读")
if loaded.get("status") != "ok":
    push_error("checkpoint 不可用，提前结束以免挂起")
    print("TABLE_CHECKPOINT ", JSON.stringify({"checks": checks, "failed": failures.size() + 1, "failures": failures}))
    quit(1)
    return
```

**「为过测删断言」在本任务里明确发生次数为 0**：所有 verify 计数保持原样，通过/失败都以原始日志为准。

---

## A-3｜运行注意事项：漏掉 `-- --test` 会让 2 个套件假失败

| 项 | 内容 |
|---|---|
| 编号 | A-3 |
| 性质 | 执行方法（本次为外部 Agent 自己的调用方式问题，**不是游戏缺陷**） |
| 严重程度建议 | 低，但必须写进 README，否则后人会重复踩 |
| 是否稳定复现 | 稳定 |

### 机制（代码位置）

- `world.gd:580`：`NOTIFICATION_WM_WINDOW_FOCUS_OUT` 时自动暂停，除非命令行用户参数含 `--test`。
- `world.gd:94`、`world.gd:97`：不含 `--test` 时会抓取鼠标并 `auto_accept_quit = false`，**并且执行 `world.gd:99` 的 `load_checkpoint()`**。
- 因此不带 `--test` 时，所有走 `main.tscn` 的交互断言都会被 `paused = true` / `controls_enabled = false` 拦住。

### 证据

| 套件 | 不带 `--test` | 带 `--test` |
|---|---|---|
| `routes_items_test` | FAIL | **PASS，54 项 0 失败** |
| `venue_transfer_test` | FAIL | **PASS，923 项 0 失败** |

首轮（无 `--test`）的原始日志已保留在 `output/external-handoff/A/logs-firstrun-no-test-flag/`，不做删除，便于对照。

### 附带的好消息（对任务书 §2「不读写玩家真实存档」的交代）

**全部四轮执行都用了 `--test`（首轮除外的 2 个套件除外），且不触发 `world.gd:99` 的 `load_checkpoint()`、不触发 `:580` 的失焦自动保存。** 真实存档 `user://three-d-checkpoint.save` 的 mtime 仍是 **2026-09-09 15:31**，早于本次全部执行时间，且大小仍为 1416 字节 —— 未被写入。首轮无 `--test` 的 9 个套件在 `--headless` 下不会收到失焦通知，也没有关闭请求，因此同样没有落盘。

---

## A-4｜测试残留文件不清理

| 项 | 内容 |
|---|---|
| 编号 | A-4 |
| 性质 | 测试问题（清理策略） |
| 严重程度建议 | 低 |
| 是否稳定复现 | 稳定（失败路径必留） |

- 失败路径会在 `user://` 留下 `<name>-<pid>.save.tmp`（首轮清点 11 个，已**整体搬运**、未删除，归档在 `output/external-handoff/A/user-dir-artifacts/`）。
- **补充清点**：本条目写就之后的补充复跑（20:11–20:17）又新增 3 个 `.tmp`，已一并归入同一目录，**最终归档 14 个**。这恰好再次印证结论 —— 只要是失败路径就必留残留，与次数无关。当前 `user://` 下已无遗留 `.tmp`。
- 成功路径的清理只写在 `table_checkpoint_test.gd:41` 的 `DirAccess.remove_absolute(path)`，位于末尾、且删的是 `.save` 不是 `.tmp`；`save_store_test.gd:22` 只**断言**不留临时文件，不负责清理。
- 长期风险：`user://` 里同名 `.save` 在进程号复用时可能被后续单跑读到，制造“时好时坏”的假象。
- 证据路径：`output/external-handoff/A/user-dir-artifacts/`（含文件名与字节数）。

---

## A-5｜两个已提交套件失败：断言写死了"固定货架 / 固定对手名"，与按种子生成的计划冲突

| 项 | 内容 |
|---|---|
| 编号 | A-5（含两处：`spatial_interaction_test`、`two_tables`） |
| 性质 | **测试问题（断言过时）**，不是游戏缺陷；两处都有"同一逻辑、按种子断言"的通过套件作为反证 |
| 严重程度建议 | **中**。不影响玩法；但它们不在任务书清单、也不在 `collect_coverage.py` 的 `SUITES` 登记表里，长期没人跑，会掩盖后续真实回归 |
| 是否稳定复现 | 两处都能复现，但**性质不同**：A-5a 是种子相关的不稳定失败（8 次播种运行中 4 次失败）；A-5b 是**结构上 100% 必失败**，与运气无关（证明见 A-5b） |
| 影响范围 | 仅这两个套件自身；对应的产品行为经另外两个通过套件验证是正常的 |

### A-5a `spatial_interaction_test`：40 项 2 失败

- **命令**：`... --headless --path Godot --script res://three_d/tests/spatial_interaction_test.gd -- --test`
- **实际**：`exit=1`，`{"checks":40,"failed":2,"failures":["Physical shelf opens single product","Purchase hands off and enters bag once"]}`，耗时 19.1s；并伴随
  `SCRIPT ERROR: Invalid access to property or key 'global_position' on a base object of type 'Nil'`（`spatial_interaction_test.gd:23`，由 `:77` 的 `aim(..., shelf)` 触发）。
- **日志**：`output/external-handoff/A/logs/spatial_interaction_test.log`
- **机制**：`:75-76` 在 `Tavern/ShopObjects` 的子节点里找 `node is Area3D and node.action_id == "shop:marked-lens"`；找不到时 `var shelf: Area3D` 保持 Nil，`:77` 传 Nil 进 `aim()` 直接抛错，`:78`、`:82` 两条断言随之失败（第 2 条是第 1 条的连锁）。
- **为什么判为测试问题**：
  - 货架锚点确实是运行时按库存生成的：`bar_display.gd:37` `world.target(display, "ShelfItem", …, "shop:" + id, …)`，`id` 来自当前局的货架计划。
  - 通过的 `run_variants_test.gd:57`（9912 项）明确断言 `displayed == world.run_game.shop_stock()`「**实体货架锚点与种子库存一致**」→ 锚点机制本身是好的，**库存按种子变化是设计行为**。
  - 而 `spatial_interaction_test.gd` 提交于 `0fc7da6`（2026-09-09），早于 2026-09-13 引入种子货架计划；它同时写死了"存在 `marked-lens`"与固定站位 `Vector3(11.25, 0.02, -2.75)`。
- **主 Agent 一步可确认**：在该处打印 `[str(n.action_id) for n in world.get_node("Tavern/ShopObjects").get_children() if n is Area3D]`。
  若里面有一批 `shop:*` 但没有 `shop:marked-lens` → 断言过时（改断言为"按 `run_game.shop_stock()` 取第一个/按计划取锚点"）；若**一个都没有** → 那才是 `bar_display.gd` 的真实回归。

### A-5b `two_tables`：27 项 1 失败

- **命令**：`... --headless --path Godot --script res://three_d/tests/two_tables.gd -- --test`
- **实际**：`exit=1`，`{"checks":27,"failed":1,"failures":["Second table opponent names"]}`，耗时 1.2s。注意**同套件的 `Second table blinds and no cargo discount` 是通过的**，说明第二张桌确实就是 `ledger-cellar`（盲注 30、无货运桌首加注优惠）。
- **日志**：`output/external-handoff/A/logs/two_tables.log`
- **机制**：`two_tables.gd:27` 断言 `world.seat_panel.opponent_left.text.begins_with("河道老鲨")`，即写死"账房地窖的左位对手 = river-shark"。
- **为什么判为测试问题**：
  - 标签逻辑本身正确：`table_hud.gd:148` `opponent_left.text = NAMES[definition.opponentIds[0]]`，而 `content.json` 里 `ledger-cellar → opponentIds: ['river-shark','velvet-rook']`。
  - 但对手名单是**按种子抽取**的（`seeded-pools.md`：整局对手名单在不同种子下 89/89/89/90），所以"左位一定是 river-shark"不是稳定事实。
  - 通过的 `opponent_pool_test.gd:82`（802 项）用的是正确写法：`opponent_left.text == r.actor_name(ids[0])`「**标签与本局可见名单一致**」。
  - `two_tables.gd` 提交于 `0c8a0f6`（2026-09-08），同样早于种子化改造。
- **主 Agent 一步可确认**：在该处打印 `world.seat_panel.opponent_left.text` 与 `world.run_game.opponent_ids()`（或等价取本局名单的接口），比对是否一致；一致则改断言为按本局名单取名字。

**再次声明**：本轮**没有为过测删改任何断言**，两个套件的 `verify` 计数保持原样，失败项原样登记。

---

## A-6｜两个脚本是截图工具，不是断言测试

| 项 | 内容 |
|---|---|
| 编号 | A-6 |
| 性质 | 分类说明（不是缺陷） |
| 严重程度建议 | 低 |

- `capture.gd`、`capture_table.gd` 都是 `extends SceneTree`，用 `root.get_texture().get_image().save_png(...)` 出图，并 `await RenderingServer.frame_post_draw`。
- 在 `--headless` 下没有可渲染帧，该 await 永不返回 → 一定超时（本轮各 180s）。
- 因此它们在 `test-results.csv` 中标记为**「非测试脚本」**，不计入通过/失败统计。
- **本次未生成任何图片**：`output/3d/` 下 20:00 之后被改写的 31 个文件全部是 `.json`，`*.png/*.mp4/*.ogg/*.wav` 新增数为 **0**（符合任务书 §2「不生成图片、视频、音频」）。
- 若要出图，需在有窗口的环境下跑，并显式加 `-- --capture`（两个脚本内部都用 `OS.get_cmdline_user_args().has("--capture")` 控制出图）。

---

## 待查线索（未证实，按任务书 3.6 只列方法，不写成缺陷）

### L-1 单挑连续三手的庄位轮换

- 现状：`table.gd` 的 `start_hand()` 用 `state.dealerSeat = (state.handNumber - 1) % state.players.size()` 轮流坐庄；单挑（`starters.size() == 2`）时由庄家下小盲。
- 未覆盖点：**没有任何测试连打三手单挑**；并且当某座位 `stack <= 0` 被标记 `folded` 时会走 `ordered_after(...)` 跳位分支，可能破坏严格轮换。本次运行未观察到相关失败，但**分母里没有这一项**。
- 查证方法：构造两人桌、连打三手，逐手断言 `dealerSeat` 与 `smallBlindSeat` 序列，并各加一个「一人出局」用例。

### L-2 首次加注优惠是否只耗用一次

- 已覆盖：`table_test.gd:67` 断言首次加注后 `stack == 30`、`currentBet == 40` 且 `firstAggressionDiscountAvailable == false`（即“首次消耗”）。
- 代码事实：`table.gd:92-94` 在**任意一次 raise** 时消耗该标记；`start_hand()` 每手重新置为 `tableDef.id == "cargo-table"`。
- 未覆盖点：**没有断言**「同一手第二次加注不再享优惠」，也没有断言「下一手重新可用」。属于覆盖盲区，不是已知缺陷。
- 查证方法：同一手连续两次 raise，断言第二次 `amount` 不减 10；再开一手断言标记复位。

### L-3 非法存档是否可恢复出异常资金或位置

- 已覆盖：`save_store_test.gd:28/32` 覆盖「payload 被篡改 → `invalid`」「version 不支持 → `invalid`」；`table_checkpoint_test.gd:40` 覆盖 `Checkpoint.restore({}) == null`；`world.gd:899-910` 的 `restore_checkpoint()` 校验房间名、类型、`seated` 与 `active` 的一致性、房间阻塞原因、桌子 ID 匹配。
- `run_checkpoint.gd:restore()` 另有大量数值与结构校验（`vault/cash/heat >= 0`、`heat <= 6`、`offer_index` 边界、`transfer_log` 与 `venue_history` 长度/费用一致性、物品 ID 必须存在于 `content.json`）。
- 未覆盖点（两处，均为**设计性**而非已证实缺陷）：
  1. `digest` 由 payload 自身算出，**能改 payload 的一方也能改 digest**，所以该校验防的是“意外损坏”，不防“有意改档”；
  2. `world.gd:900` 对 `player` 只校验 `is Transform3D`，**不校验坐标有限性（NaN/Inf）与房间边界**，一个自洽但坐标异常的存档可能落进 `ok` 分支。
- 查证方法：构造 (a) 摘要自洽但 `cash = -1`、(b) 变换为 `Vector3(NAN, NAN, NAN)` 的两份存档，走 `load_checkpoint()`，看是否被拒。

---

## 明确未执行项

- 真人试玩、性能/帧率测试：**未执行**（属任务 C 与主 Agent）。
- 引擎版本切换、依赖安装、模型导出、素材生成：**未执行**（越界）。
- 修改游戏规则、世界场景、Blender 源文件、GLB、贴图、覆盖统计目录：**未执行**；本次运行只新增了本任务目录与 `output/external-handoff/A/` 下的日志与复现脚本。
