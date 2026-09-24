# V1：撤离界面真实画面验收（4 店 × 3 状态 = 12 张真实渲染 PNG）

执行日期：2026-09-23。任务书：`docs/3d-production/external-handoff/执行任务V1-C3-画面与真人试玩取证-2026-09-23.md` 的 V1 段。

本目录只放**画面证据**。不修改 UI、不修改生产代码、不修改既有测试、不读写玩家正式存档、未提交未推送。UI 修复由主 Agent 负责。

---

## 1. 基线

| 项 | 值 |
|---|---|
| HEAD | `07f22459ffb341a0d5246818c5e9f3270c7d5bac`（开工与收工一致，全程未变） |
| Godot | `/Applications/Godot.app/Contents/MacOS/Godot` → `4.7.2.stable.official.ed1daf0bf`（PATH 中无 `godot` 命令） |
| `git diff` / `git diff --staged` | 空（**未改动任何受版本控制的文件**，含生产代码与既有测试） |

`git status --short` 开工时（仅未跟踪项，与任务书给的清单一致）：

```
?? .workbuddy/
?? "docs/3d-production/blender接续核对-2026-09-21.md"
?? docs/3d-production/external-handoff/A-regression/
?? docs/3d-production/external-handoff/A2-boundaries/
?? docs/3d-production/external-handoff/B-content-assets/
?? docs/3d-production/external-handoff/B2-production-breakdown/
?? docs/3d-production/external-handoff/C-acceptance/
?? docs/3d-production/external-handoff/V1-extraction-visual/
?? "docs/3d-production/external-handoff/对拍性审查-B1C1-2026-09-22.md"
?? docs/3d-production/inventory/
?? "docs/3d-production/并行开发分工.md"
?? poker-tavern-code-review/
?? videos/
?? "德扑酒馆/"
```

收工时多出一项 `?? docs/3d-production/external-handoff/A3-poker-audit/`——这是**其他子 Agent 的并行产物**，与本任务无关；HEAD 未变。

**存档未被读写**：`~/Library/Application Support/Godot/app_userdata/Godot德扑酒馆/three-d-checkpoint.save`（正式存档）mtime 仍为 2026-09-09；本次执行未新增任何 `*.save`；`playtest-traces/` 目录为空（未写试玩追踪）。仅 Godot 自身在 `logs/` 写引擎日志。

**既有测试原始输出**（情境基准，**不等于画面通过**）：

```
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/existing-fallback-test.log --timeout 180 --windowed \
  -- --script res://three_d/tests/extraction_fallback_ui_test.gd -- --test
# 日志 output/external-handoff/V1/existing-fallback-test.log：exit_code=0，1.5s
# 正文：EXTRACTION_FALLBACK_UI {"checks":44,"failed":0,"failures":[]}
```

---

## 2. 环境

| 项 | 实测值（`CAPTURE_ENV`，见 `output/external-handoff/V1/capture-12-shots.log`） |
|---|---|
| DisplayServer | `macOS`（**非 headless**，未加 `--headless`） |
| 渲染后端 | Forward+ / Metal 4.0，`Apple M5 (Apple9)`；`rendering_device/driver.macos=metal` |
| 窗口逻辑尺寸 | **1376 × 768**（= `Godot/project.godot` 的 `display/window/size/viewport_width/height`；`stretch/mode=canvas_items`，`aspect=expand`） |
| 屏幕分辨率 | 3024 × 1964 |
| 显示缩放 | **2.0**（Retina） |
| 截图分辨率 | **1376 × 768**，与窗口逻辑尺寸 1:1 |
| MSAA | `rendering/anti_aliasing/quality/msaa_3d=2` |

headless 下 `save_png` 必超时（历史证据 `output/external-handoff/A/logs/capture.log`），故本次全程走窗口模式。

---

## 3. 复现命令（原样可复现）

```bash
cd "<仓库根>"
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/capture-12-shots.log \
  --timeout 300 --windowed \
  -- --script /Users/springwater/Desktop/Claude/项目集群/Gen\ 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/V1-extraction-visual/repro/capture_extraction_states.gd -- --test
```

- `--` 之后的参数**原样**传给 Godot。`--test` 是**给脚本的用户参数**，不能被 Godot 自己吃掉（本机 Godot 未开 `tests=yes`，被吃掉会直接 abort）。
- `--script` 用**绝对路径**：诊断脚本放在 `res://` 之外的交付目录（`res://` 根 = `<仓库根>/Godot`），实测 Godot 接受绝对路径脚本。脚本内用 `res://` 引用生产资源。
- 实测结果：`exit=0`，`elapsed=4.2s`，日志 `CAPTURE_ROW` **12 行**，`CAPTURE_DONE made=12`，**日志正文无 `SCRIPT ERROR` / `ERROR`**。

无弹窗房间原貌探针（辅助，非交付物）：

```bash
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/probe-signage.log --timeout 120 --windowed \
  -- --script /Users/springwater/Desktop/Claude/项目集群/Gen\ 项目集群/1、德扑酒馆：落袋为安/docs/3d-production/external-handoff/V1-extraction-visual/repro/probe_tavern_signage.gd -- --test
# exit=0，产物 output/external-handoff/V1/signage/<venue>__tavern-noonpanel.png
```

### 3.1 一次失败记录（如实保留）

首次执行用了同一脚本、`--timeout 240`，**240s 墙钟超时被 SIGKILL**，只产出 smoky-den / high-rise-suite 两店 6 张：

- 日志：`output/external-handoff/V1/capture-extraction-12.log`（`exit_code: None`，`status=TIMEOUT`，约 40s/张）

随后同一脚本第二次执行 **4.2s 跑完 12 张**（`output/external-handoff/V1/diag-timing.log`；脚本内 `CAPTURE_TIME` 显示每张 `frames≈90–100ms / frame_post_draw≈7–9ms / save_png≈130–140ms`）。

**原因未完全定位**：两次差异极大，怀疑首次运行处于受限沙箱而无法正常走 GPU/窗口路径（本会话记录显示该次 Bash 调用未走"沙箱放开"通道）。无论原因，**交付的 12 张来自同一次运行**（`capture-12-shots.log`，`screenshots/` 下全部 mtime 17:48:41–17:48:44），首次那 6 张已被覆盖，不在交付内。

---

## 4. 状态构造：任务三态 ↔ 测试行

诊断脚本 `docs/3d-production/external-handoff/V1-extraction-visual/repro/capture_extraction_states.gd` 严格照抄 `Godot/three_d/tests/extraction_fallback_ui_test.gd` 的**同一会话变更顺序**（不能只截片段，否则 `completed` / `inventory` 等累积字段与测试不一致）：

| 任务状态 | 测试行 | 本脚本构造（按实际执行顺序：②→①→③） |
|---|---|---|
| ① 普通出口可付款 | `:50-55`（接管 `:46` 的 `inventory+=["ivory-chip"]`） | `cash=300`、`heat=0` → `show_run_panel("extract")` |
| ② 现金 19 / 风声 5，普通出口付款不足、紧急出口可用 | `:25-28` + `:37` | `completed+=["cargo-table"]`、`public_exit=true`、`heat=5`、`cash=19` → `show_run_panel("extract")` |
| ③ 已知后厨/河边路线 + 预约过期 + `route:fixed` 最长备选 | `:57-67` | `route_flags={"service-stairs":true,"river-launch":true}`、`reservation=route_offer().duplicate(true)`、`reservation.expiresAfterSearch=1`、`search_index=2` → `show_run_panel("route:fixed")` |

> **行号已按 `39cb971a` 用内容锚点重定位**（不是简单加偏移量；原 `07f22459` 的行号见 §12 对照表）。测试的**状态构造代码本身未变**——漂移只对该测试**新增 12 行、删除 0 行**（见 §12）。

四店取自 `Run.SCENE_NAMES`（`Godot/three_d/rules/run.gd:10`）：`smoky-den / high-rise-suite / rooftop-club / neon-poker-club`。

每格截图前的布局等待：`world.set_process(false)` → `await physics_frame` → 每格 `world.show_run_panel(...)` 后 `await process_frame ×12` → `await RenderingServer.frame_post_draw` → `root.get_texture().get_image().save_png(...)`。**每个状态都重新调用 `show_run_panel`**，文案由生产代码完整重算，不存在沿用上一态残留弹窗的情况。

---

## 5. 12 格逐格结论

逐张都是**人工目视**（PNG 直接读图 + 弹窗区域放大裁切）得出的结论，不是靠尺寸断言。判定口径：①文案末行完整；②按钮可点区域未被遮挡；③费用/预计到账可读；④不可付款时确认按钮确实禁用且"主动放弃"含义明确；⑤未知路线未出现在弹窗内；⑥整窗（标题/正文/按钮齐全）；⑦窗口分辨率与显示缩放已记（见第 2 节）。

| # | 截图 | 酒馆 / 状态 | ①末行完整 | ②按钮在画面内 | ③数字可读 | ④禁用与"主动放弃" | ⑤未知路线 | 结论 |
|---|---|---|---|---|---|---|---|---|
| 1 | `smoky-den__normal.png` | 烟雾酒馆 / 普通出口可付款 | ✔ 末行「本局净变化 +0」 | ✔ 4 个按钮（确认可用/返回探索/查看背包/继续去下一家） | ✔ 费用 60、最终到账 300 | — 确认按钮**可用**（亮色），未显示放弃按钮 | ✔ 弹窗无「已知可用路线」段 | PASS |
| 2 | `smoky-den__short-cash.png` | 烟雾酒馆 / 付款不足 | ✔ 末行「紧急出口 · 丢现金…预计到账 2」 | ✔ 5 个按钮 | ✔ 现金 19、费用 71、到账 2 | ✔ 确认为**灰色禁用**；「查看主动放弃本局的损失」独立成行、措辞明确 | ✔ 无「后厨楼梯/河边接驳」 | PASS |
| 3 | `smoky-den__expired-reservation.png` | 烟雾酒馆 / 预约过期最长备选 | ✔ 末行「紧急出口 · 丢贵重物…预计到账 290」（第 8 行） | ✔ 4 个按钮 | ✔ 5 条路线费用/到账全可读 | ✔ 确认禁用；放弃按钮可见 | ✔ 弹窗只列**已获得**的路线 | PASS |
| 4 | `high-rise-suite__normal.png` | 高层套房 / 普通出口可付款 | ✔ 末行「本局净变化 -36」 | ✔ 4 个按钮 | ✔ 费用 96、最终到账 264 | — 确认按钮**可用** | ✔ | PASS |
| 5 | `high-rise-suite__short-cash.png` | 高层套房 / 付款不足 | ✔ 末行「…预计到账 2」 | ✔ 5 个按钮 | ✔ 费用 115 | ✔ 确认禁用；放弃按钮可见 | ✔ 无「维修电梯/地下车库」 | PASS |
| 6 | `high-rise-suite__expired-reservation.png` | 高层套房 / 预约过期最长备选 | ✔ 第 8 行完整 | ✔ 4 个按钮 | ✔「贵宾电梯/维修电梯/地下车库」费用与到账可读 | ✔ 确认禁用 | ✔ 只列已获得路线 | PASS |
| 7 | `rooftop-club__normal.png` | 屋顶会所 / 普通出口可付款 | ✔ 末行「本局净变化 -7」 | ✔ 4 个按钮 | ✔ 费用 67、到账 293 | — 确认按钮**可用** | ✔ | PASS |
| 8 | `rooftop-club__short-cash.png` | 屋顶会所 / 付款不足 | ✔ 末行完整 | ✔ 5 个按钮 | ✔ 费用 90 | ✔ 确认禁用；放弃按钮可见 | ✔ 无「消防楼梯/停机坪接应」 | PASS |
| 9 | `rooftop-club__expired-reservation.png` | 屋顶会所 / 预约过期最长备选 | ✔ 第 8 行完整 | ✔ 4 个按钮 | ✔「员工通道/消防楼梯/停机坪接应」可读 | ✔ 确认禁用 | ✔ | PASS |
| 10 | `neon-poker-club__normal.png` | 霓虹扑克俱乐部 / 普通出口可付款 | ✔ 末行「本局净变化 -16」 | ✔ 4 个按钮 | ✔ 费用 76、到账 284 | — 确认按钮**可用** | ✔ | PASS |
| 11 | `neon-poker-club__short-cash.png` | 霓虹扑克俱乐部 / 付款不足 | ✔ 末行完整 | ✔ 5 个按钮 | ✔ 费用 91 | ✔ 确认禁用；放弃按钮可见 | ✔ 无「传感器盲区走廊/后台传送门」 | PASS |
| 12 | `neon-poker-club__expired-reservation.png` | 霓虹扑克俱乐部 / 预约过期最长备选 | ✔ 第 8 行完整 | ✔ 4 个按钮 | ✔ 本批**最长一行**「传感器盲区走廊：费用 20，弃现金 0，弃贵重物 0，预计到账 340」单行未换行未裁切 | ✔ 确认禁用 | ✔ | PASS |

结构化版本见 `visual-matrix.csv`（12 行，列含 `venue,scenario,resolution,screenshot,result,issue_id,notes`）。

### 5.1 与弹窗几何的对照（支撑，不替代目视）

生产代码（`Godot/three_d/scripts/world.gd:385-390`）把 `run_panel` 固定为 `PRESET_CENTER`、偏移 ±350 / ±270，在 1376×768 视口下即 **700 × 540** 固定面板。实测内容最小尺寸：

| 状态 | `run_panel.get_combined_minimum_size()` | 面板实际尺寸 | 余量 |
|---|---|---|---|
| ① normal | 292 × 400 | 700 × 540 | 充裕 |
| ② short-cash | 582 × 448 | 700 × 540 | 充裕 |
| ③ expired-reservation（最长） | **633 × 528** | 700 × 540 | 横向 67px、**纵向仅 12px** |

③ 纵向余量只有 12px——当前**未溢出、未裁切**（目视确认第 8 行与「查看主动放弃本局的损失」都在面板内），但这是最紧的一格，后续若再增加一行备选路线或调大字号就会顶出面板。记录在此供主 Agent 判断，**不作为 issue**。

---

## 6. 四店背景重复范围（任务书要求注明）

`world.travel("tavern")` 对四家酒馆**进入同一个 `Tavern` 房间节点**（`Godot/three_d/scripts/world.gd:549-562`，只有 `title_label` 文本按 `SCENE_NAMES[scene_id]` 变化）。实测佐证：

- 四店同状态截图逐像素比对：差异约 1.1–1.4 万像素 / 105.7 万（≈1–1.3%，阈值 >16），且分布在全画面——属实时渲染的抖动/抗锯齿噪声；面板外区域取样完全一致（例：`neon-poker-club` 无弹窗图与有弹窗图在 `(150,450)` 均为 `(97,54,24)`）。
- 因此**同状态的 4 张图在布局上完全等价**，真实差异只有两处：左上角店名标签，以及弹窗内的**数值与路线名**（如 ③ 的 `后厨货梯接应/贵宾电梯/员工通道/数据节点闸门`）。

按任务书要求保留 12 张，并在 `visual-matrix.csv` 的 `notes` 逐行注明重复原因。

---

## 7. 逐张自检记录

- **非空/可打开**：12 张全部为 `1376×768`、`697–775 KB`、颜色数 ≥21268、灰度标准差 ≥21.5（非空白帧）。
- **互不重复**：12 个 MD5 互不相同。
- **确为对应状态**：12 张均**目视确认**——`normal` 显示「最终到账」且确认按钮亮；`short-cash` 显示「随身现金不足以支付费用」且确认按钮置灰、多出「查看主动放弃本局的损失」；`expired-reservation` 显示「预约已过期」+ 5 条已知可用路线。弹窗数值与该店口径一一对应（60/96/67/76 等），可据此排除张冠李戴。
- **日志**：`capture-12-shots.log` / `existing-fallback-test.log` / `probe-signage.log` 正文均**无 `SCRIPT ERROR` / `ERROR`**，退出码均为 0。首次超时的 `capture-extraction-12.log` 已如实保留。
- **弹窗区域放大复核**：`output/external-handoff/V1/crops/*.panel.png`（弹窗区域裁切）与 `zoom-*.png`（按钮区 2× 放大）为人工目视用的中间产物，放在诊断区、不属交付；12 张的弹窗区域都看过。

---

## 8. 观察（**不属于本任务 5 项判定范围**，未计入 issues）

- **O1 弹窗背景是半透明的**。`make_panel`（`Godot/three_d/scripts/world.gd:447-470`）未设置自定义 StyleBox，用 Godot 默认主题，实测底层 3D 画面约 55–67% 透出（`(400,600)`：无弹窗 `(66,38,19)` → 有弹窗 `(42,31,23)`）。本批 12 张全部可读，未见因透出导致的不可读；但弹窗盖在**明亮墙面/吊灯**上时正文对比度会下降，这属于设计取舍，交由主 Agent 判断。
- **O2 顶部 HUD 与弹窗数字在本诊断构造下不同步**。例：`smoky-den__normal.png` 左上角仍是「随身 19 · 风声 5 / 6」，而弹窗写「现金 300」。**这是诊断构造的产物**：测试与本脚本都直接改 `session.cash`/`heat` 字段而不经过 `world.refresh_economy()`。真实玩法中现金变化都伴随 `refresh_economy()`，但本任务**没有**验证过真实路径下的同步性，请勿把这张图当成"发现 UI 数字不一致"。
- **O3 3D 房间墙面路牌会列出"未获得"的路线名，但用的是通用名**。`refresh_route_labels`（`Godot/three_d/scripts/world.gd:1111-1119`）在状态②下打印的路牌为：`{"kind":"directions","text":"← 后厨楼梯    库房 ↑    装卸码头 →"}`、`{"kind":"emergency","text":"检修口 · 紧急撤离"}`、`{"kind":"fixed","text":"后厨货梯接应"}`、`{"kind":"service-stairs","text":"后厨楼梯"}`、`{"kind":"river-launch","text":"装卸码头"}`；此时 `service-stairs`/`river-launch` 的 `route_known()=false`，而它们在该店（如 high-rise-suite）的真实名是「维修电梯/地下车库」，路牌显示的是 `visible_route_name()` 的通用兜底名。**弹窗内没有泄露**（本任务判定项已满足）；房间路牌属环境指路信息，是否算泄露超出本任务范围，仅记录。

---

## 9. 局限

1. **诊断构造 ≠ 真实玩家操作路径**。脚本直接 `world.run_game = session` 并直接调用 `world.show_run_panel(action)`，**没有**走玩家交互（走到出口按 E / 点告示 / 点击按钮）。因此本批只证明"生产代码这样构造时弹窗长这样"，不能证明"玩家真的一步步走到这一步时弹窗长这样"。
2. **未覆盖 `preview_only` 分支**（`show_run_panel(action, true)`，会追加"大厅入口门旁。"等方位提示并把确认按钮改成"到实际入口按 E 撤离"），也未覆盖 `abandon` / `transfer` / `enter` 三种面板态。任务只要求三态，故未扩展。
3. **`travel("tavern")` 是直接调用**，绕过了 `confirm_run_action()`，因此**未写 `PLAYTEST_TRACE`**（`playtest-traces/` 为空）——符合"不读写正式存档"的约束。
4. 四店背景房间相同（见第 6 节），本批 12 张的画面差异有限。
5. 本环境单次运行**出现过一次 240s 超时**（第 3.1 节），原因未完全定位；虽然最终 12 张在 4.2s 内一次跑成且重复两次内容一致，仍如实记录。
6. 未做像素级"字号最小可读"的判定（例如最小字号 19px 在 1376×768 下是否满足某种无障碍标准），只记录"目视可读"。

---

## 10. issues

**未发现**（无裁切、重叠、字号过小、按钮覆盖、错误路线）。故本目录**未产出 `docs/3d-production/external-handoff/V1-extraction-visual/issues.md`**（该文件按任务书要求不存在，不是遗漏）。

第 8 节三条观察已写明，均不属任务书列出的问题类型。

> **2026-09-24 补充取证更新**：原 12 格**画面**结论仍为「未发现」。补充取证新增了 `issues.md`，其中记录一条**测试断言假通过**（非 UI 缺陷，见 §12.3 与 `issues.md` 的 `ISSUE-S1`）；此非原 12 格范围内的问题。

---

## 11. 文件清单

交付目录 `docs/3d-production/external-handoff/V1-extraction-visual/`：

- `README.md` —— 本文件
- `visual-matrix.csv` —— 12 行逐格矩阵
- `screenshots/` —— **12 张真实渲染 PNG**（唯一硬产出）
  - `smoky-den__{normal,short-cash,expired-reservation}.png`
  - `high-rise-suite__{normal,short-cash,expired-reservation}.png`
  - `rooftop-club__{normal,short-cash,expired-reservation}.png`
  - `neon-poker-club__{normal,short-cash,expired-reservation}.png`
- `repro/capture_extraction_states.gd` —— 12 张截图的诊断脚本（**环境/状态复现探针，不是真实玩家操作路径**）
- `repro/probe_tavern_signage.gd` —— 无弹窗房间原貌探针（**同上，不是真实玩家操作路径**）

补充取证新增（2026-09-24，见 §12）：

- `screenshots-supplement/` —— **4 张备份面板路线对比行 PNG**（每店 1 张，`<venue>__bag-expired-routes.png`）
- `visual-matrix-supplement.csv` —— 4 行逐格矩阵（字段同 `visual-matrix.csv`）
- `repro/capture_services_panel.gd` —— 备份面板取证脚本（**状态复现探针，不是真实玩家操作路径**）
- `issues.md` —— 补充取证新增；记录 `ISSUE-S1`（测试断言假通过，非 UI 缺陷）
- `repro/verify_visual.py` —— **可重复自检脚本**（2026-09-24 补，见 §13）；只读，重推 16 张 PNG 与两矩阵的一致性

诊断区（不属交付）`output/external-handoff/V1/`：

- `run_godot.py` —— 共享执行器（带墙钟超时 + 杀进程组），沿用，未改
- `capture-12-shots.log` —— **权威运行日志**（12 张的来源）
- `diag-timing.log` —— 同脚本第二次运行 + 各阶段耗时（12 张）
- `capture-extraction-12.log` —— 首次 240s 超时的失败日志
- `existing-fallback-test.log` —— 既有 `Godot/three_d/tests/extraction_fallback_ui_test.gd` 的原始输出
- `probe-signage.log`、`signage/*.png` —— 无弹窗房间原貌探针
- `crops/*.png` —— 人工目视用的弹窗/按钮区放大裁切
- `verify_v1_result.json` —— 自检脚本结果（含 16 张 PNG 的 sha256 清单）
- `probe-windowed.log`、`probe-render.png` —— **上一轮（其他 Agent）的环境能力探针**，保留未动

已按任务书要求删除上一轮遗留的临时探针（原路径 docs/3d-production/external-handoff/V1-extraction-visual/repro/probe_window.gd，**该文件已删除、现不存在**，故此处按本项目惯例不以反引号写成"可打开的引用"形式；其产物 `output/external-handoff/V1/probe-render.png` 已挪至诊断区）。

补充取证新增的诊断区文件（2026-09-24）：

- `supplement-fallback-test.log` —— 当前 `39cb971a` 下重跑既有测试（`checks 60 / failed 0`）
- `capture-services-panel.log` —— 备份面板取证运行日志（含 `PROBE_A` 与 `CAPTURE_ROW`）
- `services-bag-initial/<venue>__bag-initial.png` —— **初始态**备份面板对照图（证明未知路线未泄露），非交付

---

## 12. 基线漂移与补充取证（2026-09-24）

本节的取证**只针对原交付之后发生的基线漂移做增量**，不推翻、不覆盖原 12 张交付。

### 12.1 漂移事实

- 原交付基线 `HEAD = 07f22459ffb341a0d5246818c5e9f3270c7d5bac`；当前 `HEAD = 39cb971a0f0b9cb92547cad0a8e1391cf639d26c`（开工前 `git rev-parse HEAD` 实测）。
- `07f22459..39cb971a` 共 **16 个提交**（`git rev-list --count` = 16），由**并行进程**（GitHub 账号 `spring10-15`，即主 Agent 侧）在 2026-09-23 23:13:25 起陆续提交，**不是本任务所为**。本任务全程未 commit / 未 push，未改动任何受版本控制的文件。
- 16 个提交（`git log --oneline 07f22459..HEAD`）：

  ```
  39cb971 Make opponent pattern probe distinguish its trigger
  8f50620 Verify first-run route quotes in the backpack
  8aa48e4 Compare live AI evening paths with viable exits
  2810462 Compare known extraction routes in inventory
  3205ddf Show call exposure and resulting pot at the table
  30f19f9 Expand difficulty probe to twelve paired seeds
  e869b40 Probe table difficulty across seeds and player policies
  0c873b5 Record per-table chip outcomes in roster regression
  c257bd9 Make calling station continue with weak hands
  bda173a Differentiate shark opponents with situational value raises
  082a789 Document opponent policy sensitivity probe
  47164d1 Audit opponent choices on matched live table states
  e689ae2 Measure opponent policy similarity under identical choices
  214db5f Verify completed first run survives restart
  d986f03 Verify seeded reservation ledger through two tables
  31918ba Expand extraction conservation boundary matrix
  ```

### 12.2 逐文件核验：原 12 张所依赖的生产源码 UNCHANGED

漂移区间 `git diff --stat` 显示 19 个文件变更。确认**原 12 张图所依赖的两个生产源码文件不在其中**，并用 blob hash 双向核验：

| 文件 | `07f22459` blob | `39cb971a` blob | 结论 |
|---|---|---|---|
| `Godot/three_d/scripts/world.gd` | `ee9ae8b2926d935c790c3dc4a716d9245427b533` | 同左 | **UNCHANGED** |
| `Godot/three_d/scenes/main.tscn` | `6bc49d52fc900de0b1cdb952e8fc1a8e22bb35fb` | 同左 | **UNCHANGED** |

`git diff 07f22459..HEAD -- <以上两文件>` 输出均为**空**。
→ **原 12 张截图的画面结论在当前 HEAD 下仍然成立**（未重新生成、未覆盖任何原图）。

### 12.3 情境基准 `extraction_fallback_ui_test.gd` 的漂移：+12 行 / −0 行

`git diff --numstat 07f22459..HEAD -- Godot/three_d/tests/extraction_fallback_ui_test.gd` = `12	0`，且 `git diff` 全为 `+` 行——**纯新增，未删除/未修改任何原有构造行**（三个状态 ① 正常 / ② 费用不足 / ③ 最长备选的构造代码均未变）。新增分三处：

1. **`:34-36`**：状态② 前，对 `session.service_view("bag")` 中 `kind=="route"` 的行断言：存在 `id=="dropbag-cash"` 一行、`label` 含 `费用 %d / 弃现 %d / 弃物 %d / 到账 %d`，且**不含** `service-stairs`（未知路线不得泄露到背包）。
2. **`:52-54`**：断言 `id=="general"` 的当前通用报价行存在且 `label` 含报价。
3. **`:61-66`**：断言 `id=="fixed"` 存在「暂不可用：预约已过期」预览行（`reason` 为空）；随后 `world.open_services()` + `await process_frame`，**对 `services_panel.rows` 做宽度断言**（`<= services_panel.size.x - 36`），再 `close_services()`。

**影响**：测试 `checks` 由 **44 → 60**（每场景 +4 断言 × 4 场景 = +16），`failed` 仍为 0（见 12.4）。
**其中第 3 处的宽度断言为"假通过"**：测试在 `:55` 刚 `world.show_run_panel("extract")` 后**未关面板**就在 `:63` 调 `world.open_services()`，而 `open_services()` 有守卫 `if paused or run_panel.visible: return`（`Godot/three_d/scripts/world.gd:887-889`），于是 `services_panel` **未 refresh、未 show**，断言实际求值的是空 `rows` 的 `0.0 <= 844.0`。**背包面板这一新可视界面，此前既无画面证据，也无有效测试保护**——这正是本次补充取证的由来。详见 `issues.md` 的 `ISSUE-S1`。

### 12.4 重跑当前测试（对照原 `44/0`）

```bash
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/supplement-fallback-test.log --timeout 180 --windowed \
  -- --script res://three_d/tests/extraction_fallback_ui_test.gd -- --test
```

- `exit_code=0`、`elapsed_s=1.7`；日志 `output/external-handoff/V1/supplement-fallback-test.log`；正文**无 `SCRIPT ERROR` / `ERROR`**。
- 正文：`EXTRACTION_FALLBACK_UI {"checks":60,"failed":0,"failures":[]}` —— 对比原 `44/0`，**`checks` +16**（与原记录 44 + 新增 4 断言 × 4 场景吻合），`failed` 仍 0。
- 环境：`Metal 4.0 - Forward+ - Using Device #0: Apple - Apple M5 (Apple9)`（与原记录一致）。

### 12.5 补充取证：备份（背包）面板的路线对比行（4 张）

复现脚本 `repro/capture_services_panel.gd`（**状态复现探针，不是真实玩家操作路径**）。状态严格照抄当前测试的同一会话变更顺序（`completed+=["cargo-table"]` / `public_exit=true` / `heat=5→0` / `cash=19→0→19→300` / `inventory+=["ivory-chip"]` / `route_flags={"service-stairs":true,"river-launch":true}` / `reservation=route_offer().duplicate(true)` / `reservation.expiresAfterSearch=1` / `search_index=2`）。

```bash
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/capture-services-panel.log --timeout 180 --windowed \
  -- --script "<仓库根>/docs/3d-production/external-handoff/V1-extraction-visual/repro/capture_services_panel.gd" -- --test
```

- `exit_code=0`、`elapsed_s=3.8`、`CAPTURE_DONE delivery=4 diagnostic=4`；正文**无 `SCRIPT ERROR` / `ERROR`**；**首次即跑成，未超时**（无需重跑）。
- 环境与原 V1 一致：`window=1376×768`、`screen_size=3024×1964`、`screen_scale=2.0`、`Metal 4.0 / Forward+ / Apple M5`。

> **忠实性说明（必须点明）**：本脚本先输出 `PROBE_A` 复现测试 `:55→:63` 的调用顺序，实证 `open_services()` 因 `run_panel` 仍可见而早退（`services_panel_visible=false`、`rows_child_count=0`、`rows_min=[0,0]`）。**因此要让背包真实显示，必须先 `world.close_run_panel()` 再 `world.open_services()`**——本脚本正是这么做的，所以 4 张交付图是**背包面板真的渲染出来**的画面，而非测试里那个未显示的面板。

4 张交付图逐张**人工目视**结论：

| # | 截图（`screenshots-supplement/`） | 酒馆 | 行数 | 末行完整 | 数字可读 | 裁切/重叠 | 过期预览行 | 未知路线泄露 |
|---|---|---|---|---|---|---|---|---|
| S1 | `smoky-den__bag-expired-routes.png` | 烟雾酒馆 | 8 | ✔「返回游戏（B / Esc）」 | ✔ | 无 | ✔「后厨货梯接应 · 暂不可用：预约已过期」 | 无 |
| S2 | `high-rise-suite__bag-expired-routes.png` | 高层套房 | 8 | ✔ | ✔ | 无 | ✔「贵宾电梯 · 暂不可用：预约已过期」 | 无 |
| S3 | `rooftop-club__bag-expired-routes.png` | 屋顶会所 | 8 | ✔ | ✔ | 无 | ✔「员工通道 · 暂不可用：预约已过期」 | 无 |
| S4 | `neon-poker-club__bag-expired-routes.png` | 霓虹扑克俱乐部 | 8 | ✔ | ✔ | 无 | ✔「数据节点闸门 · 暂不可用：预约已过期」 | 无 |

- **末行完整 / 裁切 / 重叠**：每张 8 行（标题 + 6 路线行 + 「返回游戏（B / Esc）」）全部完整；每行 `size_x = 844`（= 面板内框宽 `880-36`），最长按钮文本 `min_x = 500`（`neon-poker-club` 的「查看路线 · 紧急出口 · 丢贵重物 · 费用 10 / 弃现 0 / 弃物 60 / 到账 290」）单行不换行、未裁切；行间距 8px，无重叠。
- **数字可读**：费用/弃现/弃物/到账四元组逐行可读（逐店数值见 `visual-matrix-supplement.csv`）。
- **未知路线是否泄露**：**未泄露**。「多行 + 预约过期」态里 `service-stairs` / `river-launch` 出现，是因为该态 `route_flags` 已把二者置真（`route_known()=true`），属**合法可见**；而在**初始态**（`route_flags` 为空）备份面板只有 4 行路线、**无** `service-stairs`/`river-launch`——诊断图 `output/external-handoff/V1/services-bag-initial/<venue>__bag-initial.png` 逐张目视确认。
- **宽度余量**：`rows.get_combined_minimum_size().x = 760`（由标题 `custom_minimum_size.x=760` 主导，**非按钮**；按钮最宽 500），面板内框 `844` → **横向真余量 84px**；纵向 `rows` 高 `469 < 504`（`540-36`）→ **纵余 35px**。即该宽度断言的**真值（若被真正执行）会通过**，但原测试并未真正执行到它（见 12.3）。

### 12.6 测试行号新旧对照（内容锚点重定位）

§4 表中的行号已按 `39cb971a` 用**内容锚点**重定位（非简单加偏移）：

| 内容锚点 | `07f22459` | `39cb971a` |
|---|---|---|
| `session.completed.append("cargo-table")` 起（`public_exit` / `heat` / `cash`） | `:25-28` | `:25-28`（未变） |
| 状态② `world.show_run_panel("extract")` | `:34` | `:37` |
| `session.inventory.append("ivory-chip")` | `:43` | `:46` |
| 状态① `session.cash = 300` / `session.heat = 0` | `:47-48` | `:50-51` |
| 状态① `world.show_run_panel("extract")` | `:49` | `:55` |
| 状态③ `route_flags` … `search_index = 2` | `:51-54` | `:57-60` |
| 状态③ `world.show_run_panel("route:fixed")` | `:55` | `:67` |
| 新增：背包 `dropbag-cash` 报价断言 | — | `:34-36` |
| 新增：背包 `general` 报价断言 | — | `:52-54` |
| 新增：过期预览 + 开背包 + 宽度断言 | — | `:61-66` |

### 12.7 对原交付的改动范围（只增不改口径）

- **未动** `screenshots/` 的 12 张 PNG（mtime 仍为 2026-09-23 17:48；MD5 未变）。
- **未动** `visual-matrix.csv` 的 12 行结构与内容。
- **新增**：`screenshots-supplement/`（4 张）、`visual-matrix-supplement.csv`（4 行）、`repro/capture_services_panel.gd`、`issues.md`。
- 本 README：§4 的测试行号按 `39cb971a` 重定位并加注；§10 追加说明；§11 追加新增文件；新增本节。**原 12 格的结论口径未改**（依据：生产源码 UNCHANGED，见 12.2）。

### 12.8 局限（补充取证）

1. 与 §9 同：本批仍是**诊断构造 ≠ 真实玩家操作路径**（直接改 `session` 字段 + 直接调 `world.open_services()`，未走玩家按 B 键路径）。
2. 备份面板的多行态**只覆盖「已知 6 条路线 + 预约过期预览」这一种**；未覆盖 `route_flags` 部分为空、`fixed` 未预约、`dropbag-valuables` 无可弃贵重物等其它背包行组合（初始态对照图覆盖了其中一部分）。
3. 宽度余量 84px / 纵余 35px 为**本环境 1376×768（显示缩放 2.0）**实测；更大字号或更长路线名下的行为未测。

---

## 13. 可重复自检脚本（2026-09-24 补）

§7 与 §12.5 的逐张自检当时在会话内完成，但**没有把脚本交出来**，复核者无法重跑。
本轮补上 `repro/verify_visual.py`：只读，从**真实 PNG 字节 / 两个矩阵 CSV / 诊断日志**重新推导，
逐项打 `CONFIRM` / `REFUTE`，结果写 `output/external-handoff/V1/verify_v1_result.json`。
**判定只认 `exit 0 且 REFUTE 0`**。当前 `CONFIRM=14  REFUTE=0`。

| 检查 | 内容 |
| --- | --- |
| 矩阵列齐全 / 行数 | 主矩阵 12 行、补充矩阵 4 行；字段 ⊇ `venue,scenario,resolution,screenshot,result,issue_id,notes` |
| 覆盖完整性 | 主矩阵恰好是 4 店 × 3 状态的 12 格，无缺格、无越界组合 |
| 截图可解析 | 每个 `screenshot` 引用都能在对应目录找到，且**真的是 PNG**（校验 8 字节 magic 与 `IHDR` 块），不是只判"文件存在" |
| 尺寸一致 | 每张 PNG 的 IHDR 实际宽高 == 矩阵 `resolution` 列 |
| 非空白帧 | 每张 ≥ 50 000 字节（有效帧实测 680–780 KB；空白帧远小于此阈值） |
| 张冠李戴检测 | 同状态下四店图**不得字节相同**（各店店名与金额不同）；主图与补充图之间亦不得字节相同 |
| 日志 | 8 个诊断日志均无 `SCRIPT ERROR` / `ERROR` 行；非 0 退出码必须在脚本内的**显式豁免表**里登记并给出理由，未登记即 `REFUTE` |
| 豁免不空头 | 豁免表里登记的日志必须真实存在（防"豁免了一个不存在的文件"） |

**顺带产出**：JSON 里带 **16 张 PNG 的 sha256 清单**。后续轮次重跑即可检出
「原 12 张是否被人覆盖」——本轮 12 张的 sha256 已固定，可作为 §12 所述基线漂移检查的延续。

**未覆盖**：本脚本只核"文件与矩阵自洽"，**不核画面内容**（文字是否被裁切、按钮是否被遮挡）。
后者是 §5 / `issues.md` 的人工目视结论，无法脚本化——这正是任务书「尺寸断言不能替代画面」的另一面。
