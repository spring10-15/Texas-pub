# 任务 A｜回归测试与问题复现（README）

执行日期：2026-09-21
代码版本：`b158491069d38cc7a2e3b02546ed1c47fb650d9e`（`b158491`，2026-09-14 23:03:42，`test: verify short stacks and lone-funded betting queues`）

`git status --short` 在开始与结束时都只显示未跟踪项（`??`），**没有修改任何被跟踪文件**：

```
?? docs/3d-production/blender接续核对-2026-09-21.md
?? docs/3d-production/external-handoff/
?? docs/3d-production/inventory/
?? docs/3d-production/并行开发分工.md
?? poker-tavern-code-review/
?? videos/
?? 德扑酒馆/
```

---

## 1. 执行环境

| 项 | 值 |
|---|---|
| 操作系统 | macOS（darwin） |
| 引擎 | Godot `4.7.2.stable.official.ed1daf0bf` |
| 引擎路径 | `/Applications/Godot.app/Contents/MacOS/Godot` |
| 工作目录 | 项目根（`--path Godot`） |
| 归档工具 | `Godot` 自带（`collect_coverage.py` 用 `python3`） |
| 其他 | 未切换引擎版本、未安装依赖、未改动 `Godot/.godot` 缓存 |

**关键调用约定**：每个套件都必须带 `-- --test`。原因与实测证据见 `issues.md` 的 A-3（`world.gd:580` 失焦自动暂停；不带参数时 `routes_items_test`、`venue_transfer_test` 会假失败）。

**`user://` 落点**：`~/Library/Application Support/Godot/app_userdata/Godot德扑酒馆/`。运行器在每轮开始前做一次可写预检（创建 + 改名），避免在写不了的环境里跑出假失败。

---

## 2. 执行方式

```sh
cd "/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安"

# 1) 串行跑全部主清单套件 + 覆盖汇总器（逐项硬超时 180s，超时整组 SIGKILL）
python3 output/external-handoff/A/run_suites.py

# 2) 单独跑清单外的补充套件
python3 output/external-handoff/A/run_suites.py extra

# 3) 从原始日志反推结果表（保证每个「通过」都能定位到日志）
python3 output/external-handoff/A/summarize_results.py
```

- 每项都记录完整命令、开始时间、耗时、退出码、stdout/stderr，以及从输出里解析出的**实际检查数**。
- **验收自查①（每个「通过」可定位原始日志）**：48 行的 `日志路径` 列**逐条实际存在**，44 个 PASS 全部可点开对应 `.log` 复核；44 个 PASS 的退出码**全为 0**，不存在「退出码 0 却记 FAIL」或「PASS 但退出码非 0」的矛盾行（已用脚本核过）。
- 判定按任务书 3.3：出现 `SCRIPT ERROR` / `Parse Error` / `ERROR`（行首锚定，`verify()` 失败即 `push_error`）时，**即使退出码为 0 也不判通过**。
- 「实际检查数」在 `test-results.csv` 里由 `summarize_results.py` 重新解析原始日志得到，而不是复用运行时的宽松正则，两者若有出入以日志为准。

---

## 3. 汇总结论

取自 `test-results.csv`（48 行，由 `summarize_results.py` 从原始日志反推）：

| 结果 | 数量 | 说明 |
|---|---|---|
| **PASS** | **44** | = 任务书 §3.2 的 **14** 个基础套件 + `collect_coverage.py` 登记的 **15** 个覆盖套件 + **2** 个汇总器 + **13** 个清单外补充套件 |
| **FAIL(脚本错误)** | **2** | `spatial_interaction_test`（40 项 2 失败）、`two_tables`（27 项 1 失败）→ 详见 `issues.md` A-5，**判定为测试断言过时**，非游戏缺陷 |
| **非测试脚本** | **2** | `capture.gd`、`capture_table.gd` 是截图工具，`--headless` 下无渲染帧必然超时 → `issues.md` A-6 |
| 可解析断言计数合计 | **59,193** | 仅作篇幅参考，**不等于覆盖率**（见下方"关于覆盖分母"） |

**三个存档套件（`table_checkpoint` / `save_store` / `services_save`）在本表中是 PASS**（2021 / 8 / 46 项）。
它们在受限执行环境下曾 4/4 复现假失败并挂住流水线，根因已定位为环境以 `file-write-unlink` 拦截 `user://` 改名，**不是游戏缺陷**：

- 受限环境那轮的日志：`output/external-handoff/A/logs-sandboxed-run/`，含根因证据 `SANDBOX-DENIAL-根因证据.md`
- 单跑复核：`output/external-handoff/A/logs-secondrun/table_checkpoint_test-standalone-1.log`、`-2.log`（2021 项全绿）
- 运行器已加**双层环境预检**（Python 层 + 真正调用 `Store.write_checkpoint()` 的 Godot 层），预检不过直接中止，不再产出被污染的结果。

**真实玩家存档未被改动**：`user://three-d-checkpoint.save` 的 mtime 仍是 `2026-09-09 15:31:13`、大小 1416 字节、`sha256 = 773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a`，早于本次全部执行时间。全部运行都带 `--test`，因此不触发 `world.gd:99` 的 `load_checkpoint()`，也不触发 `:580` 的失焦自动保存。

**边界自查**：本次未生成任何图片/视频/音频（`output/3d/` 下 20:00 后被改写的 31 个文件全是 `.json`，媒体文件新增 0）；`assets/` 与 `Godot/three_d/assets/` 未被改动；`git status --short` 没有任何被跟踪文件的改动。

### 关于覆盖分母（任务书明确要求，不得含糊）

- `docs/3d-production/phase-1/coverage/transitions.json` 的 `status` 为 **`incomplete_catalog`**，已登记且有当前证据的结果为 **239 条**，`pending_families` 仍保留 `poker` / `world` / `persistence` / `signal_analysis` 四族未拆分项。
- 因此 **239 不是分母，本轮也不宣称任何全局覆盖率**。`collect_coverage.py` 输出里 `overall_state_transition_coverage` 显式为 `null`；本报告只逐套件报「实际检查数」，**不做跨套件加总后宣称覆盖率**，也不会把 59,193 这个合计包装成覆盖率。
- 本轮新增登记面积为零：外部 Agent 不修改覆盖统计目录，是否把 `spatial_interaction_test` / `two_tables` 等清单外套件纳入登记，留给主 Agent 决定。

---

## 4. 未执行项（明确列出，不用历史日志冒充）

| 未执行 | 原因 |
|---|---|
| 真人试玩 / 手感与节奏计时 | 属任务 C 与主 Agent；本任务不代替真人 |
| 性能 / 帧率 / 内存长稳测试 | 属 Phase 3，本任务无目标机型环境 |
| 引擎版本切换、依赖安装 | 任务书 §2 边界：缺少依赖只记录，不自行切换 |
| 任何模型导出、素材生成、贴图烘焙 | 任务书 §2 边界 |
| 修改规则、世界场景、测试断言、覆盖统计目录 | 任务书 §2 边界；本轮外部 Agent 的改动为零 |
| 打开游戏窗口做交互试玩 | 本任务全程 `--headless`，只做脚本级回归 |
| 出图（`capture.gd` / `capture_table.gd`） | 需真实渲染窗口；且任务书 §2 要求不生成图片，故未执行 |

---

## 5. 交付文件

| 文件 | 内容 |
|---|---|
| `docs/3d-production/external-handoff/A-regression/README.md` | 本文件 |
| `docs/3d-production/external-handoff/A-regression/test-results.csv` | 逐套件结果：`测试文件,执行时间,命令,退出码,实际检查数,结果,日志路径,备注` |
| `docs/3d-production/external-handoff/A-regression/issues.md` | 问题报告（编号/严重程度/前置状态/复现步骤/预期/实际/日志/影响范围/是否稳定复现）+ 三条待查线索 |
| `output/external-handoff/A/logs/` | **交付用**的原始日志（48 项，无沙箱环境整轮复跑）：每项一个 `.log`，含命令、耗时、退出码、stdout、stderr |
| `output/external-handoff/A/logs-sandboxed-run/` | 受限执行环境那一轮的日志 + `SANDBOX-DENIAL-根因证据.md`（A-1 的现场证据，保留不删） |
| `output/external-handoff/A/logs-firstrun-no-test-flag/` | 首轮**未带** `--test` 的日志，保留作 A-3 的对照证据（不做删除） |
| `output/external-handoff/A/logs-secondrun/` | 单跑复核日志，含 `table_checkpoint_test-standalone-1/2.log`（2021 项全绿） |
| `output/external-handoff/A/logs-thirdrun-sandboxed/` | 更早一轮受限环境的日志，同作 A-1 对照 |
| `output/external-handoff/A/repro/` | 复现脚本（见下表） |
| `output/external-handoff/A/user-dir-artifacts/` | 失败路径在 `user://` 留下的 `.tmp`/`.save` 残留（**整体搬运，未删除**） |
| `output/external-handoff/A/preexisting-output-3d/` | 本次执行前 `output/3d/` 的既有报告副本（33 个），避免被后续执行覆盖 |
| `output/external-handoff/A/run_suites.py` | 串行运行器（双层预检 + 逐项硬超时 + 进程组清理） |
| `output/external-handoff/A/summarize_results.py` | 从原始日志反推 `test-results.csv` |
| `output/external-handoff/B/normalize_asset_gaps.py` | 任务 B 用到的 CSV 规范化脚本（2026-09-24 引用校正：实际位于相邻目录 `B`，原文写作 `A` 是断链） |

### 复现脚本清单（都放在交付目录，不改主仓库）

运行方式：把脚本放在项目外任意位置，用绝对路径执行即可（不需要拷进 `Godot/`）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot \
  --script "$PWD/output/external-handoff/A/repro/<脚本名>" -- --test
```

| 脚本 | 用途 |
|---|---|
| `output/external-handoff/A/repro/diag_save_write.gd` | 存档读写链路的基础诊断 |
| `output/external-handoff/A/repro/diag_route_ray.gd` | 路线锚点射线命中和 `paused/controls_enabled` 的对照（A-3 的证据） |
| `output/external-handoff/A/repro/diag_write_error.gd` | 拆开 `write_checkpoint` 各阶段并打印错误码 |
| `output/external-handoff/A/repro/diag_write_bigstate.gd` | 真实牌桌状态（5472–7940 字节）+ 同路径连续写 60 次（A-1 的压力对照） |
| `output/external-handoff/A/repro/diag_leftover_tmp.gd` | 给失败留下的 `.tmp` 验尸，判定失败点（A-1 决定性证据） |
| `output/external-handoff/A/repro/probe_first_write.gd` | 逐步打印写入链每一步的返回码 |
| `output/external-handoff/A/repro/preflight_write.gd` | 运行器的 Godot 层预检（真正调用 `Store.write_checkpoint()`） |
| `output/external-handoff/A/repro/probe_shelf_stock.gd` | A-5a 的决定性探针：打印本局 `shop_stock()` 与 `Tavern/ShopObjects` 锚点，证明「锚点 == 本局库存」而 `marked-lens` 只在部分种子出现 |
| `output/external-handoff/A/repro/probe_second_table_names.gd` | A-5b 的探针（**已用代码级证明替代，未跑完**：该脚本自身因前置条件未满足而中断并挂起，正是 `issues.md` A-2 的独立复现，故保留作证据，不建议直接使用） |

**执行过的脚本版本 = 交付目录里的版本**（本任务期间未再改动；如需复核请直接使用这些文件）。
