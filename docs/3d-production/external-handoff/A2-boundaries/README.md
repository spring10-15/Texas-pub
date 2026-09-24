# A2 边界问题复现与回归补录（README）

执行日期：2026-09-21 夜间跨 09-22 上午。任务依据：`../主Agent验收与返修任务-2026-09-21.md` 第 3 节。

> **主 Agent 当前复核（2026-09-25）**：以下数据是旧基线 `d44a1dd` 的历史取证，不代表当前缺陷仍存在。L-3 的 NaN/越界姿态和非法 `props` 半恢复均由后续正式恢复校验修复，当前 `world_restore_atomic_test.gd` 检查拒绝后完整世界快照不变；L-2 的折扣按“玩家实付减少、下注目标仍按牌桌规则设置”实现，专测验证合法行动预览、扣款与一次性消耗一致；精确筹码跟注后全押已纳入 48 个扑克队列座位变体。当前全回归 59/59、登记证据 357/357，但覆盖分母、真人试玩和完整局计时仍未完成。原始日志与 findings 保留历史结论供追溯。

---

## 1. 执行环境与代码版本

| 项 | 值 |
|---|---|
| HEAD | **`d44a1dd`** `fix: reject invalid run checkpoint ranges and inventory capacity`（2026-09-21 22:04:42） |
| 相对 A 轮基线 | A 轮为 `b158491`；本轮期间主 Agent 新增 4 个提交，见下表 |
| 引擎 | Godot `4.7.2.stable.official.ed1daf0bf`，`/Applications/Godot.app/Contents/MacOS/Godot` |
| 工作目录 | 项目根（`--path Godot`） |
| 工作区状态 | 受跟踪文件**无改动**（`git status --short` 只有 `??` 未跟踪项）；本轮未修改任何生产代码 |
| 调用约定 | 一律带 `-- --test`（避免 `world.gd:580` 失焦自动暂停、`world.gd:99` 读取真实存档） |

`b158491` 之后主 Agent 的提交（本轮全部结果都在 `d44a1dd` 上跑）：

```
d44a1dd fix: reject invalid run checkpoint ranges and inventory capacity
d05fe9e fix: rotate heads-up dealer among funded seats
0eb8445 test: verify signal strength and active opponent branches
2dc6adb test: register queue transitions with chip and deck invariants
4580734 test: align interaction regressions with seeded content and review handoff
```

> **重要**：`d05fe9e` 与 `d44a1dd` 恰好分别修掉了 A 报告的 L-1 与部分 L-3 边界，
> 因此本轮多个线索的结论是"**未复现/已修复**"，而不是"缺陷仍在"。详见 `findings.md`。

---

## 2. 执行方式

```sh
cd "/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安"

# 全量串行：2 个本轮修正套件 + 2 个新增套件 + 3 个 A2 诊断脚本
# （逐项硬超时 240s，超时杀整个进程组；每个脚本一份原始日志）
/Users/springwater/.workbuddy/binaries/python/versions/3.13.12/bin/python3 output/external-handoff/A2/run_a2.py

# 只跑某一项（子串匹配）
/Users/springwater/.workbuddy/binaries/python/versions/3.13.12/bin/python3 output/external-handoff/A2/run_a2.py spatial
```

诊断脚本也可单独手跑（脚本在交付目录内，无需拷进 `Godot/`）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot \
  --script "$PWD/docs/3d-production/external-handoff/A2-boundaries/repro/<脚本名>" -- --test
```

---

## 3. 汇总结论

| 脚本 | 断言数 | 退出码 | 结果 |
|---|---:|---:|---|
| `spatial_interaction_test.gd` | 41 | 0 | **PASS**（主 Agent 修正后） |
| `two_tables.gd` | 27 | 0 | **PASS**（产 A 轮此处 1 项失败，已修） |
| `dealer_rotation_test.gd` | 304 | 0 | **PASS**（`d05fe9e` 新增） |
| `run_restore_bounds_test.gd` | 29 | 0 | **PASS**（`d44a1dd` 新增） |
| `repro/diag_dealer_rotation.gd` | 168 | 0 | **L-1 未复现**（轮换、盲注、首行动者全部符合规则来源） |
| `repro/diag_first_discount.gd` | 52 | 0 | **L-2 行为符合预期**；另出 2 条设计语义疑问 |
| `repro/diag_save_recovery.gd` | 35 | 0 | **L-3 复现 3 项缺口**（详见 `findings.md`） |

**按要求的三种口径分别统计（不混用）**

| 口径 | 数值 | 说明 |
|---|---:|---|
| **脚本数** | **7** | 4 个回归套件 + 3 个诊断脚本。**截图工具不计入**（`capture.gd` / `capture_table.gd` 本轮未执行，见第 6 节） |
| **断言数** | **656** | 7 个脚本 `checks` 之和（41+27+304+29+168+52+35）。**这只是断言条数，不等于覆盖率** |
| **语义结果数** | **61** | 仅诊断脚本可拆出的独立场景数：轮换 18（16 手 + 2 个守卫用例）、优惠 10（6 用例 / 10 子场景）、存档 33（组1 19 + 组2 6 + 组3 6 + 组4 2）。**纯断言套件记「—」**，因为它们的断言不构成独立场景 |

> 口径示例（任务书原文）：`ending` 的 **7 个语义结果**不等于其内部断言数。本报告严格分开列示，不做跨脚本加总后宣称任何覆盖率。

`diag_save_recovery.log` 里有 **3 行 `ERROR`**，是**故意触发**的：
非法 `props` 类型 2 次（缺口 3 的复现，`world.gd:912` 抛 SCRIPT ERROR）、
截断文件 1 次（引擎 `get_var` 的常规报错）。**这 3 行不是诊断失败**；
按 A 轮判定规则，它们是"不得当作通过"的证据本身，已在 `findings.md` 逐条归类。

---

## 4. 隔离与边界（真实存档未被读写）

| 项 | 证据 |
|---|---|
| 真实存档 `user://three-d-checkpoint.save` | mtime 仍为 **2026-09-09 15:31:13**，1416 字节，`sha256 = 773a5918f7789120de1da44543a9e845abf1a99a05e397b8dca1028006ec4f6a` —— 早于本轮全部执行时间 |
| 落点 | `~/Library/Application Support/Godot/app_userdata/Godot德扑酒馆/` |
| 文件层用例的专用文件 | `user://a2-boundary-probe.save`，脚本末尾自动删除；已确认 `user://` 下**无残留**（含 `.tmp`） |
| 世界层用例 | 只在内存中构造存档，**从未调用 `save_checkpoint()`** |
| 生产代码 | 本轮**零改动**：未改规则、未改测试断言、未改覆盖统计目录、未生成模型/贴图 |

---

## 5. 一个测量陷阱（本轮踩到，记录以免复用者误报）

首轮全量跑时 `spatial_interaction_test` 的挂钟耗时被记成 **2081 秒**，但同脚本单跑只需 **19.5 秒**。
原因是该次运行横跨了机器休眠，**挂钟时间把睡眠也计入了**。已单独重测并在全量重跑中取干净计时（`test-results.csv` 记 19.46s）。

> 教训：长跑批次的"耗时"字段要能区分 CPU 时间与挂钟时间；跨休眠的批次不可直接引用耗时。本报告所有耗时均取自重跑后的干净日志。

另有一条**守恒式测量陷阱**（与 C1 第 7 条同源，详 `findings.md` 末节）：
`state.pot` 在一手结束后不清零，故"全桌财富守恒"不能统一用 `Σstack + pot`；
必须**分手进行中 / 手刚结束两个时点**分别取口径。

---

## 6. 未执行项（明确列出）

| 未执行 | 原因 |
|---|---|
| 改动生产规则或正式测试 | 任务书第 3 节边界：只做诊断 |
| 回放 `b158491` 的旧 `table.gd` 以实测旧轮换行为 | 需改生产代码或另拷贝规则文件；本轮改为**按 `git show d05fe9e` 的 diff 推导**，并在 `findings.md` 明确标注"推导，非实测" |
| 截图工具（`capture.gd` / `capture_table.gd`） | 需真实渲染窗口；且按 A 轮结论它们不是断言测试，不计入套件数 |
| 真人试玩 / 性能与计时 | 属任务 C 与主 Agent |
| 安全隔离之外的存档测试 | `user://` 下若无法隔离则标记未执行；本轮隔离成功，故全部执行 |
| 修改或删除首攻优惠 | 任务书明确要求：语义疑问单列，不自行决定 |

---

## 7. 交付文件

| 文件 | 内容 |
|---|---|
| `docs/3d-production/external-handoff/A2-boundaries/README.md` | 本文件 |
| `docs/3d-production/external-handoff/A2-boundaries/findings.md` | 三条线索的逐条结论：预期规则来源 / 实际结果 / 最短复现 / 稳定性 / 语义疑问 |
| `docs/3d-production/external-handoff/A2-boundaries/test-results.csv` | `脚本,类型,命令,退出码,耗时秒,断言数,语义结果数,结果,日志路径,备注` |
| `docs/3d-production/external-handoff/A2-boundaries/repro/` | 3 个可运行诊断脚本（见下表） |
| `output/external-handoff/A2/logs/` | 7 份原始日志（含命令、耗时、退出码、stdout、stderr、ERROR 行数） |
| `output/external-handoff/A2/run_a2.py` | 串行运行器（硬超时 + 进程组清理 + 日志留档） |

### 诊断脚本清单（都在交付目录内，不改主仓库）

| 脚本 | 对应线索 | 用途 |
|---|---|---|
| `repro/diag_dealer_rotation.gd` | L-1 | 两种夹具 × 出局座位 1/2/0，逐手记录庄家/小盲/大盲/翻前与翻后首行动者；显式分离 FIXTURE 与 ACTION |
| `repro/diag_first_discount.gd` | L-2 | 6 用例 / 10 子场景：首攻、同手第二次、下一手复位、对手使用、余额边界、非优惠桌对照 |
| `repro/diag_save_recovery.gd` | L-3 | 组1 纯规则 / 组2 文件层 / 组3 世界层 / 组4 RNG；含"半恢复"探针 |

---

## 8. 验收自查（对照任务书第 3 节验收标准）

| 验收要求 | 自查 |
|---|---|
| 三条线索逐条有结论及可重跑证据 | ✅ L-1 未复现、L-2 符合预期（附 2 条语义疑问）、L-3 复现 3 项缺口；每条都有可重跑脚本 + 原始日志 |
| 日志扫描脚本错误，不能只看退出码 | ✅ 运行器逐份统计 `ERROR` 行数并写入日志头；`diag_save_recovery` 的 3 行 ERROR 已逐条归因 |
| 断言数 / 语义结果数 / 脚本数分别统计 | ✅ 三种口径分列于第 3 节，未混用、未加总成覆盖率 |
| 需要主 Agent 决定的优惠语义单列 | ✅ `findings.md` L-2 节"需主 Agent 决定的语义项"，未代替决定 |
| 复现失败也交证据 | ✅ L-1 属"未复现"，同样给了实测记录 + 旧代码推导（并标注推导非实测） |
| 只写自己的目录，不改生产代码、不生模型、不提交推送 | ✅ 只新增 `A2-boundaries/` 与 `output/external-handoff/A2/`；未 `git commit` / `git push` |
