# 世界位置与持久化入口源码核对

2026-10-03。局部审计，不冻结全局状态转移分母。

| 入口 | 实际状态结果与归属 | 证据边界 |
|---|---|---|
| travel | 更新房间、活动桌、玩家落点/朝向、速度与镜头；同步人物和货架、刷新信息 | world.travel_landing / room_entry 及房间门分支；只验证既有空间，不证明新建筑所有落点安全 |
| leave_seat | 暂停、未入座、未完成牌桌时拒绝；已完成桌先结算，失败早退；成功清理桌面、恢复探索与返回位置，随后检查强制撤离 | world.leave_*；结算失败继承 Run.settle_table 拒绝结果，不应重复新增一个经济状态 ID |
| check_pressure | enforce_pressure 成功后关闭服务面板并回藏匿点；否则不转场 | 世界测试把 heat 直接设为 6，证明 forced 结算后置条件，未证明正常玩家行为累积风声到该触发点。规则层择优路线样本不自动补足世界层自然可达性 |
| save_checkpoint | 固定种子试玩拒绝保存；状态未变且磁盘内容一致则复用；磁盘缺失/损坏时重写；写失败保持 last_saved、显示错误；成功更新缓存 | persistence_restore.playtest_save_blocked / save_repaired_from_memory / missing_checkpoint_recovered 与文件 I/O 族；写缓存变化不是新的资金结果 |
| load_checkpoint | 固定种子试玩跳过；缺档启用保存；文件错误或语义恢复失败禁用覆盖并保留文件；有效恢复启用保存、暂停等待继续 | corrupt_load_preserved / unsupported_version_preserved 与同版跨进程恢复；不证明历史版本迁移 |
| restore_checkpoint 拒绝 | 外层字段类型、有限坐标、俯仰范围、房间包络、入座返回位置、道具字典/布尔值、Run 恢复、房间与 active 对应、活动牌桌入座、解锁条件和桌 ID 对应均在权威对象替换前检查 | invalid_transform / outside_room / invalid_props / active_in_stash / active_table_not_seated / locked_room / table_id_mismatch 及规则恢复子图；多个输入守卫可以归同一“不变拒绝”结果，不按 if 数量膨胀分母 |
| restore_checkpoint 接受 | 替换 Run，恢复道具/皮箱、位置/视角/返回位置/入座/活动桌；清理旧 UI 和延迟，按 paused 与 seated 恢复控制和镜头 | valid / seated / replace_live_table / paused_seated / legacy_props / legacy_run_fields；缺少 props 默认空字典，不表示任意缺字段兼容 |
| checkpoint_position_valid | 仅做房间 AABB 范围检查，包含上层后厨和下层码头 | 不是碰撞查询；可能在包络内落进墙体或家具。最终建筑批次必须用真实旧档验证恢复位置，不能凭 outside_room 测试宣布安全生成点已完成 |

## 当前执行证据

完整回归 output/3d/regression/20261003-122501/report.json：66/66 Godot 套件，Python 18/18；coverage 汇总 380/380 已登记结果有效，全局覆盖率 unavailable。此次仅审计现行源码，不增加 ID、不修改玩法、不修改另一模型的美术工作。

## 锚点

- Godot/three_d/scripts/world.gd SHA256：`31c4f6864e244ead9e04ecd7b211b9684be18154b60d52f8e83aaddca4250e90`
- Godot/three_d/tests/world_coverage_test.gd SHA256：`4d713bbed65121355b41a8b94238ee73b38024b0c3d16d76e87450a71b3bf79e`
- Godot/three_d/tests/world_restore_atomic_test.gd SHA256：`6ee0e259fd8d2a238215bff28445605cf122ae78ccf3b08b6ede531c117cb9c6`

上述对应目录结果只说明已审查入口的归属，不证明其他入口、复合条件输入空间或自然玩家路径已穷尽。

## 2026-10-03：补充自然触发样本

新增 natural_pressure_exit_test.gd：正常 start(屋顶酒馆, seed=41)，通过真实准星入座和 World.start_table 买入，依次推进货运桌、账房、镜厅的合法牌局动作，再由 World.leave_seat 结算。没有直接赋值 heat/completed/cash，也没有改桌规或强制牌局结束。前两桌仍活动，第三桌入桌风声封顶到 6，离座后实际强制撤离回藏匿点，检查 forced 标识、清空随身现金和金库增量等于撤离 net；42 项检查、0 失败、退出码 0。

这补足一条既有世界触发的正常操作可达性，不增加目录 ID。固定样本对手采用合法弃牌策略，不代表生产 AI 分布、所有牌局结果、第一人称连续行走或真人按键。上表原有 heat=6 夹具的边界仍成立，但“没有任何自然触发证据”已由本补充修正。全局覆盖分母仍未冻结。
