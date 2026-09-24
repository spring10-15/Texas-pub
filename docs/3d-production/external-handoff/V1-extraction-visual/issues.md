# V1 issues

> 原 V1 交付（基线 `07f22459`）的 12 格结论为「未发现」问题，故当时**未**产出本文件（见 `README.md` §10）。
> 本文件由 **2026-09-24 补充取证**新增。
>
> - **画面层面仍未发现**裁切 / 重叠 / 字号过小 / 未知路线泄露问题（4 张备份面板补充图逐张目视，见 `visual-matrix-supplement.csv`）。
> - 但发现一个**测试断言层面的问题（宽度断言假通过，非 UI 缺陷）**，按任务要求如实记录。
> - 本文件**不改 UI、不改生产代码、不改既有测试**；仅记录，修复由主 Agent 决定。

---

## ISSUE-S1（测试断言假通过，非 UI 缺陷）：备份面板宽度断言在一个**未刷新的空面板**上求值

**位置**：`Godot/three_d/tests/extraction_fallback_ui_test.gd:63-65`（当前 HEAD `39cb971a`）——即本次基线漂移新增 12 行中的最后 3 行：

```gdscript
63			world.open_services()
64			await process_frame
65			verify(world.services_panel.rows.get_combined_minimum_size().x <= world.services_panel.size.x - 36, scene + " route comparison fits bag width")
```

**根因**：`open_services()` 有守卫 `if paused or run_panel.visible: return`（`Godot/three_d/scripts/world.gd:887-889`）。
测试在 `:55` 刚调用 `world.show_run_panel("extract")`（`run_panel.show()`），**其后到 `:63` 之间没有任何 `close_run_panel()`**，
所以 `:63` 的 `open_services()` **立即早退**：`services_panel` 既没有 `refresh()` 也没有 `show()`。

**实际 vs 预期**：
| | 值 |
|---|---|
| 测试实际求值的 `rows.get_combined_minimum_size().x` | **0.0**（`rows` 无子节点，从未 refresh） |
| 右侧 `services_panel.size.x - 36` | 844.0 |
| 断言结果 | `0.0 <= 844.0` → **true（假通过，未触及背包几何）** |
| 真实背包几何（本补充取证实测，`run_panel` 关闭后真开面板） | `rows_min.x = 760.0 <= 844.0` → true（真值恰好也通过） |
| 相同 `verify(...)` 在其他店 | `640 / 4 场景` 全部因同一守卫假通过 |

即：**该断言恒为真，`checks` 数增加但未新增任何有效覆盖**。

**复现步骤**（只读；不改任何文件）：

```bash
cd "<仓库根>"
# 1) 跑既有测试：checks 由 44 升至 60，failed 0（断言"通过"）
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/supplement-fallback-test.log --timeout 180 --windowed \
  -- --script res://three_d/tests/extraction_fallback_ui_test.gd -- --test

# 2) 跑补充取证探针：忠实复现 :55→:63 的调用顺序并打印 services_panel 真实状态
python3 output/external-handoff/V1/run_godot.py \
  --log output/external-handoff/V1/capture-services-panel.log --timeout 180 --windowed \
  -- --script "<仓库根>/docs/3d-production/external-handoff/V1-extraction-visual/repro/capture_services_panel.gd" -- --test
```

**证据**（`output/external-handoff/V1/capture-services-panel.log`，smoky-den 首次进入，服务面板从未 refresh）：

```
PROBE_A_PRE  {"run_panel_visible":true,"services_panel_visible":false,"rows_child_count":0,"rows_min":[0.0,0.0],"venue":"smoky-den"}
PROBE_A_POST {"run_panel_visible":true,"services_panel_visible":false,"rows_child_count":0,"rows_min":[0.0,0.0],
              "width_assert_lhs":0.0,"width_assert_rhs":844.0,"width_assert_passes":true,"venue":"smoky-den"}
```

**影响**：`extraction_fallback_ui_test.gd` 中「备份面板路线对比行不超出面板宽度」这一条**目前没有任何测试保护**；
若未来背包路线行真的顶破面板宽度，该断言仍会通过。**画面本身当前无问题**（本补充取证已目视确认 4 店均 84px 横向余量），
故本项是**测试有效性问题**，不是 UI 缺陷。

**未做**：未修改该测试（任务硬约束：不改既有测试）。是否需要修（例如前置 `world.close_run_panel()` 再 `world.open_services()`）由主 Agent 判断。

---

## 未发现的问题（画面）

- 裁切：未发现（4 张补充图所有行 `size_x = 844`，`min_x ≤ 500 < 844`，无 `min_x > size_x`）。
- 重叠：未发现。
- 字号：未发现不可读；费用/弃现/弃物/到账数字目视清晰。
- 未知路线泄露：**未发现**。初始态（`route_flags` 为空）备份面板只有 4 行路线（普通出口 / 预约接应预览 / 紧急出口·丢现金 / 紧急出口·丢贵重物），
  **没有** `service-stairs`（后厨楼梯 / 维修电梯 / 消防楼梯 / 传感器盲区走廊）与 `river-launch`；见诊断图
  `output/external-handoff/V1/services-bag-initial/<venue>__bag-initial.png`。
  在「多行 + 预约过期」态中 `service-stairs` / `river-launch` 出现，是因为该态 `route_flags` 已把二者置真（`route_known()=true`），属**合法可见**，不是泄露。
