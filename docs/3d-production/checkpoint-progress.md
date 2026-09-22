# 存档基础模块进展

本轮发现开始前已有 run.gd、content.json 和 sync_content.mjs 的搜索、库存与道具改动，用户已明确允许接手。本轮已复核并集成，完整状态见 services-save-migration.md。

- `rules/save_store.gd`：版本化本地二进制存档，保留整数及向量类型；禁止对象反序列化；完整性校验；临时文件写入、验证后替换旧档。校验用于发现文件损坏，不是反作弊机制。
- `rules/table_checkpoint.gd`：保存牌桌内部状态、动作版本和随机数进度，恢复时不重新发牌或再次执行结算。
- `tests/save_store_test.gd`：8 项检查，包含首次保存、覆盖、类型保留、校验失败及版本不支持。
- `tests/table_checkpoint_test.gd`：2,021 项检查，两张桌各 10 个种子，在每个动作节点实际写入、读回、恢复，并比较下一步牌序、资金、行动队列及终局状态。

测试文件名包含测试进程 ID，测试完成后删除，不触碰玩家存档。

已完成完整出局与库存快照、玩家位置恢复和主场景自动保存；读取失败时保留原文件并暂停覆盖，界面显示原因。系统强杀、磁盘写满和跨平台存档尚未验收。

运行：在项目根目录执行 Godot 的 --headless --path Godot --script 参数，分别指定 res://three_d/tests/save_store_test.gd 和 res://three_d/tests/table_checkpoint_test.gd。

## 2026-09-22：拒绝世界存档时保持原状态

外部 A2 的 `findings.md` 指出：props 类型错误时，world.restore_checkpoint 已替换 run_game，随后才在 props.restore 抛错；NaN/Infinity 姿态也会被接受。主 Agent 用 `world_restore_atomic_test.gd` 独立复现，修复前 14 项检查中 11 项失败，日志见 `output/3d/world-restore-review/before.log`。

现在在替换运行对象之前校验玩家/返回位置和视角为有限值、props 为字典且状态值为布尔值。非法输入不得先修改现金、房间、道具状态；缺少 props 的旧快照仍按默认关闭状态恢复。修复后 14 项检查通过（同目录 after.log），测试仅用内存世界快照和 `-- --test`，不操作玩家真实存档。

此修复处理 A2 的非有限姿态与 props 半恢复问题；有限但远离场景的坐标尚未增加房间边界验证，预约和其他嵌套字段也仍待审查。不能据此宣称全部非法存档都已安全拒绝。A2 对庄位与基础存档范围的复核已记录当前修复有效；优惠语义等其他结论尚未完成主 Agent 验收。
