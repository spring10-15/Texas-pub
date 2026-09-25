# A8 源码函数入口普查

日期：2026-09-25。此普查建立全量 GDScript 方法的职责边界，为之后逐入口枚举守卫与后继做索引；它本身不是全局状态转移分母，也不产生覆盖率结论。

## 结果

`python3 output/external-handoff/A8/source_function_sweep.py` 扫描 `Godot/three_d/rules/` 与 `Godot/three_d/scripts/` 的全部 20 个运行时 GDScript 文件，共识别 177 个方法：

- 120 个方法在 A8 当前树分支清单中有函数入口；
- 57 个方法按方法名逐项列入显式排除表，理由为只读查询/报价、内容标签、确定性生成辅助，或纯场景/UI 构建与呈现；
- 0 个未分类方法，0 个失效排除项。

方法清单、定义行、源码哈希和逐项排除理由保存在 `output/external-handoff/A8/source-function-sweep.json`。未来新增、删除或改名方法后必须重跑；新增未归类方法会使命令失败。

## 范围限制

函数出现在 A8 清单只证明入口归属已登记，不证明该函数内每个守卫、合取条件、循环结果、回调或玩家可达性都已枚举。显式排除也只排除独立玩家状态结果：例如 `Run.service_reason()` 与路线报价是只读判定，其拒绝后继需在实际 `service_action()` / `extract()` 调用链归属；`run_variants.shuffled()` 的局部随机数消费需随 `generate()` 产出的持久计划核验。下一步仍须逐个权威状态写入者拆出接受/拒绝后继，特别保留多结果分支与组合守卫；只有经人工复核其去重语义与覆盖证据后，才可将目录状态改为完整并计算 ≥95%。

## 复现

```sh
python3 output/external-handoff/A8/source_function_sweep.py
```

此检查只验证方法级边界，不能替代全量回归、A8 当前树对账或 Phase 1 真人验收。
