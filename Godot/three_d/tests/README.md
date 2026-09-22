# Godot 3D 回归入口

在项目根目录执行：

```sh
python3 Godot/three_d/tests/run_regression.py
```

默认使用 PATH 中的 godot，或 macOS 的标准安装路径 `/Applications/Godot.app/Contents/MacOS/Godot`。其他环境可指定：

```sh
python3 Godot/three_d/tests/run_regression.py --godot /path/to/Godot --timeout 90
```

运行范围：自动发现本目录全部 `*_test.gd`，并纳入 smoke、table_integration、table_parity、two_tables。capture/capture_table 是截图工具，明确排除；新出现而未分类的 GDScript 会阻止执行，要求先明确用途。每套件顺序执行一次，携带 `-- --test`，不启用截图。现有写盘测试使用独立测试文件，世界测试禁用玩家自动读写存档；新增测试也必须遵守该约定。

通过要求同时包含：退出码为 0、日志无脚本/解析错误、存在明确成功摘要。单套件超时会终止该测试并记 TIMEOUT，其余测试继续，以便一次收集问题。最后执行 Python 汇总器与运行器判定单元测试，检查执行期间规则、脚本、场景、测试和覆盖目录是否变化；变化则整轮不能判通过。

原始日志和 `report.json` 位于 `output/3d/regression/时间戳/`，包含命令、退出码、耗时、状态和源码哈希。以本轮日志为准，不复用旧 PASS。不要与另一轮回归同时执行，以免覆盖各套件共享的 coverage 报告。

2026-09-22 首轮统一执行通过，实际套件数以报告为准。回归通过不等于状态转移完整分母 ≥95%，也不证明真人节奏、美术性能或阶段整体完成。
