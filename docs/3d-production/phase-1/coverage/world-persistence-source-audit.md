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

自然触发专项进一步核对独立账本：结算前现金加玩家剩余筹码必须等于实际撤离现金；既有贵重物加已发奖励的变现值，连同现金，必须等于到账净额、费用、丢现金和丢贵重物之和。撤离后背包清空，再次 check_pressure/leave_seat 不得改变完整世界快照或二次入账。46 项检查、0 失败、退出码 0；玩法源码未改。

## 2026-10-03：默认落点碰撞证据

新增 landing_collision_test.gd，用真实 PlayerController 胶囊、碰撞掩码和 PhysicsDirectSpaceState3D.intersect_shape 检查初次出生位置以及 travel 的五空间默认落点，排除玩家自身；六处均没有实体重叠。以藏匿点墙内位置作负向对照，确认同一查询能检出墙体。专项 7 项、0 失败、退出码 0。角色物理过程在测量时暂停，避免自动滑出墙体掩盖重叠；仅关闭自动过程，不修改碰撞几何。

这是现有默认落点的空间回归，不是任意存档位置安全证明，也不验证地面支撑、可步行连通性或未来精细建筑。默认落点测试调用 travel 只检查几何，不宣称未解锁房间可被正常玩家进入。建筑碰撞改动后应重跑，并补真实旧档采样。

默认落点专项扩展为 19 项：出生点和五个 travel 落点均有近距离向下射线命中的可步行地面（法线符合 Player.floor_max_angle）；每个落点恢复真实角色重力运行 30 个物理帧，均落地且高度变化低于 0.15 米。脚下无地面的反例正确拒绝；墙体重叠反例保留。19 项零失败、退出码 0。查询近地支撑与实际重力落地补齐默认落点的地面证据，仍不证明任意旧档或连续行走连通性。


## 2026-10-03：五空间入口至交互点的连续行走

新增 `room_walkability_test.gd`，SHA-256：`2cb6b428ba9db8778adbeb731216e0cf5f6c02a5acacd3fa1f1d5627bca32e13`。藏匿点通过正式 `travel` 落点进入，再用 `Input.action_press("move_forward")` 驱动真实 PlayerController 的移动、重力和 `move_and_slide`，走到皮箱及出门位置。四个牌桌空间同样从正式落点依次走过前侧走道、牌桌、吧台、左侧走道、搜索柜和返回门；路径中不直接赋值玩家位置。

每段检查在有限帧内抵达目标、角色仍落地且高度在地面附近。交互点以真实相机朝向和射线检查能否聚焦对应锚点。专项 74 项检查、0 失败、退出码 0。它验证现有建筑碰撞下的一组连续可行路线，不修改规则或增加状态转移 ID。

边界：各房间以 `travel` 作为几何测试入口，不绕过解锁规则作正常通关声明；自动朝向和移动输入不代表真人 WASD/鼠标体验。后厨楼梯、库房货梯和码头的行走仍由既有 `spatial_interaction_test.gd` 独立验证，本新增套件没有把大厅到后场的整段路径串起来，也不证明所有任意位置或未来精细建筑的连通性。

本轮完整回归：`output/3d/regression/20261003-131158/report.json`，69/69 个 Godot 套件与 20/20 个 Python 测试通过，运行期间源码、测试及运行资产指纹保持不变。未读取正式玩家存档。


## 2026-10-03：大厅至全部后场撤离点的连续往返

`room_walkability_test.gd` 扩展到 111 项，专项退出码 0、无失败。玩家从大厅正常落点，经牌桌、吧台、搜索柜后的左侧通道绕到大厅后门，连续走进后场；检修口的现金/贵重物两个锚点、后厨高处出口、库房货梯和低处码头均能被真实射线聚焦。后厨上行及返回、码头下行及返回全部用 PlayerController 移动输入，路径中没有赋值玩家位置或调用 travel。

每个目的地检查在 300 个物理帧以内抵达、角色落地及脚部高度与该层地面相差小于 0.15 米：后厨高层 1.2 米、大厅/货梯 0 米、码头 -1.2 米。最终原路回到大厅返回门，其余三个牌桌空间与藏匿点的原检查保留。

执行：`Godot --headless --path Godot --script res://three_d/tests/room_walkability_test.gd -- --test`。本次专项源码 SHA-256：`e99c846e4a3f6456af4128539cd31b37ad97c49a6f72f9025ee7b0f1f1a48261`。与全量报告 `20261003-131158` 的指纹对比，仅此测试文件改变；所有被记录的游戏源码和运行资产均未变。上节 69 套件全量报告针对 74 项旧版行走检查，本扩展的 111 项是后续独立专项，不能将旧报告重述为新套件全量通过。

这些证据补齐一条入口连接全部后场撤离点的往返物理路线，仍不替代带预约/费用/风声状态的实际撤离、真人按键体验、任意路径或最终高精度资产验收。
