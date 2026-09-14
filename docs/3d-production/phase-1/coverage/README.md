# 状态转移覆盖：目录与执行证据

2026-09-14。transitions.json 是逐步审查中的语义转移目录，当前 status=incomplete_catalog。pending_families 明确保留未拆分的生命周期、服务、搜索、扑克、世界交互和持久化范围；不得把当前数组长度当作全游戏分母。

一个 ID 表示一次公开入口的成功结果或拒绝原因。多个输入命中同一结果只计一次。拒绝是同一状态上的自环，必须同时验证完整状态未变；只检查返回 false 不构成充分证据。子条件的短路求值覆盖、各种冲突条件的优先级、所有经济数值组合不由这份语义覆盖率替代，仍需要对应边界测试。

首批 transfer.* 共 12 项：成功、旧 revision、无活动局、活动牌桌、未知目的地、已经访问、本店尚未完成新桌、本晚结束、无行动力、现金不足、出口未发现、出口封锁。来源是 run.gd 的 transfer_quote/transfer_venue 和 routes.gd 的普通出口条件。返回原因的优先级可能使同时失效的条件被另一个原因覆盖，本批用例分别隔离各条件。

执行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
```

报告 output/3d/transfer-coverage.json 保存每个真实命中 ID、执行结果、run.gd 与目录 SHA-256、缺失项及失败项。本轮 12/12；这是转场子图的结果。overall_state_transition_coverage 明确为 null。测试出现任何脚本错误，即使进程退出码为 0 也不得记通过。

后续工作：逐一审查 pending_families 的实际入口与内部结果，增补稳定 ID；在验证后继状态的测试中记录命中，再汇总同一源码版本的证据。全目录审查完成以前不计算 ≥95% 总覆盖率。已有大量断言与测试文件不自动转换成覆盖命中。
