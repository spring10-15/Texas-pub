# 状态转移覆盖：目录与执行证据

2026-09-14。transitions.json 是逐步审查中的语义转移目录，当前 status=incomplete_catalog。pending_families 明确保留未拆分的生命周期、服务、搜索、扑克、世界交互和持久化范围；不得把当前数组长度当作全游戏分母。

一个 ID 表示一次公开入口的成功结果或拒绝原因。多个输入命中同一结果只计一次。拒绝是同一状态上的自环，必须同时验证完整状态未变；只检查返回 false 不构成充分证据。子条件的短路求值覆盖、各种冲突条件的优先级、所有经济数值组合不由这份语义覆盖率替代，仍需要对应边界测试。

首批 transfer.* 共 12 项：成功、旧 revision、无活动局、活动牌桌、未知目的地、已经访问、本店尚未完成新桌、本晚结束、无行动力、现金不足、出口未发现、出口封锁。来源是 run.gd 的 transfer_quote/transfer_venue 和 routes.gd 的普通出口条件。返回原因的优先级可能使同时失效的条件被另一个原因覆盖，本批用例分别隔离各条件。

执行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
```

报告 output/3d/transfer-coverage.json 保存每个真实命中 ID、执行结果、所有规则文件、测试脚本与目录 SHA-256、缺失项及失败项。本轮 12/12；这是转场子图的结果。overall_state_transition_coverage 明确为 null。测试出现任何脚本错误，即使进程退出码为 0 也不得记通过。

后续工作：逐一审查 pending_families 的实际入口与内部结果，增补稳定 ID；在验证后继状态的测试中记录命中，再汇总同一源码版本的证据。全目录审查完成以前不计算 ≥95% 总覆盖率。已有大量断言与测试文件不自动转换成覆盖命中。

## 生命周期与防过期汇总（2026-09-14）

新增 start/reset/discover/extract/abandon/pressure 六组共 31 个具名结果。验证出发金库转移、120 门槛、六类撤离的现金/贵重物等式、重复到账拒绝、夹层钱包保留 80、封锁时可撤离与无路可走的失败分支。各拒绝结果检查完整 checkpoint 不变。路线报价内部守卫仍列在 pending_families.route_quotes，不能因 extract.rejected_quote 命中一例就将它们全部记通过。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/lifecycle_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
python3 Godot/three_d/tests/collect_coverage.py
python3 Godot/three_d/tests/test_collect_coverage.py
```

两份执行报告核对当前目录、所有规则文件及各自测试脚本的摘要。汇总器拒绝过期来源、已有失败、缺失或杜撰命中、夸大计数；3 个单元测试（含 7 个缺陷子情境）通过，缺陷只在内存中注入，不改真实证据文件。摘要文件 output/3d/coverage-summary.json 显示 43 个已登记结果均有当前证据，全局覆盖率仍为 null，未枚举的状态族保持显式待办。

## 撤离守卫与边界（2026-09-14）

route_guard.* 新增 24 个具名结果：20 个拒绝结果与 4 个允许边界（风声 5 的普通出口附加费、预约有效期最后一轮、两种特殊出口最高允许风声）。测试通过实际 Run.extract 入口执行，报价前后不变，拒绝后完整 checkpoint 不变，成功时校验独立计算的费用与到账。四酒馆 × 两个预约方案 × 24 个结果共 192 个情境通过；这些样本只贡献 24 个语义命中。

“丢贵重物但紧急出口未知”不作为独立最终结果：有贵重物时 emergency_known 为真；无贵重物时最终原因是“没有可舍弃的贵重物”。源码中的条件存在并不代表可到达一个额外的独立拒绝状态。复杂条件重叠时的优先级仍不等同于本批隔离守卫覆盖。

本批完成初始 pending_families.route_quotes 的拆分；总目录仍因其它状态族未完整枚举而未封板。现在 67 个已登记结果均有当前证据，整体百分比依旧为空。

更新汇总前，先运行新增套件及原两套件，避免目录摘要过期：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/route_guard_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/lifecycle_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
python3 Godot/three_d/tests/collect_coverage.py
python3 Godot/three_d/tests/test_collect_coverage.py
```
