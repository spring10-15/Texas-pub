# A8 工作底稿：Run 入口映射（未完成审计）

本文件仅记录主 Agent 对 `Run` 模块公开入口的初步盘点，供后续完整审计复用。它不是 A8 最终报告，也不证明 382 个目录 ID 是全局分母。

## 基线

- 审计基线：`74128bf0ceca97b1eeeeff1389f609d1b8e40a42`
- Godot：`4.7.2.stable.official.ed1daf0bf`
- 跟踪文件状态：干净；工作区存在多份未跟踪的外部协作交付，审计期间未修改或清理。
- 目录：382 个已登记 ID，状态 `incomplete_catalog`；当前三个 `pending_families` 数组为空。全局分母仍需源码驱动审计确认。

## 初步入口映射

下表只确认公开状态入口在目录中有对应 `entry`。A8 仍须逐个函数体拆出所有接受、拒绝、动作时机和互斥结果，再核验相应测试的后继状态断言与证据报告。

| Run 入口 | 源码行 | 当前目录 entry | ID 数 | 对应登记 ID 前缀 | 当前证据套件候选 |
|---|---:|---|---:|---|---|
| `start` | 51 | `start` | 5 | `start.*` | `lifecycle_coverage_test.gd` |
| `transfer_venue` | 100 | `transfer_venue` | 12 | `transfer.*` | `transfer_coverage_test.gd` |
| `enter_table` | 165 | `enter_table` | 12 | `entry.*` | `entry_coverage_test.gd` |
| `settle_table` | 183 | `settle_table` | 21 | `settlement.*` | `settlement_coverage_test.gd` |
| `discover_exit` | 219 | `discover_exit` | 4 | `discover.*` | `lifecycle_coverage_test.gd` |
| `extract` | 229 | `extract` | 8 | `extract.*` | `lifecycle_coverage_test.gd` |
| `reset_demo` | 242 | `reset_demo` | 4 | `reset.*` | `lifecycle_coverage_test.gd` |
| `service_action`（基础服务） | 315 | `service_action` | 21 | `service.*` | `service_coverage_test.gd` |
| `service_action`（牌桌工具） | 315 | `service_action(lens/sleeve)` | 15 | `tool.*` | `tool_coverage_test.gd` |
| `service_action`（物理搜索选择） | 315 | `service_action(search)` | 20 | `search.*` | `search_coverage_test.gd` |
| `abandon` | 481 | `abandon` | 5 | `abandon.*` | `lifecycle_coverage_test.gd` |
| `enforce_pressure` | 512 | `enforce_pressure` | 5 | `pressure.*` | `lifecycle_coverage_test.gd` |

基础服务之外的 `Advanced.apply()`、`SearchEvents.apply()` 及其 reason 分支仍须回到各自函数体审计；这里把它们列为 `service_action` 的状态入口分派，不把 helper 数量算作转移分母。

## 暂定排除项

以下方法在本轮初查中属于查询、预览或展示，不作为独立权威状态转移入口：`transfer_quote`、`table_blocked_reason`、`room_requirements`、`room_blocked_reason`、`table_definition`、`extraction_quote`、`slots_used`、`service_reason`、`shop_stock`、`service_view`、`sale_value`、`valuable_total`、`reward_for_table`、`table_reward_pool`、`abandon_quote`、`route_offer`、名称/描述读取方法、`route_known` 与 `reserve_fee`。A8 最终审计仍需检查这些 helper 是否有隐含副作用，以及 UI/游戏调度入口是否都回到被列入的公开命令。

## 未完成事项

- 尚未对上述入口逐分支确认源码后继状态与目录 ID 的一一映射。
- 尚未核验候选测试是否对每条结果断言权威 Run 状态及拒绝原子性。
- 尚未为这些分支填写当前源码行、测试、报告、证据强度和可达性 CSV。
- 尚未审计 Table、扑克/对手、服务 helper、路线/事件/变体、存档及 World 物理入口。
- 尚未分析目录外的可达结果；不能据本底稿推导覆盖百分比或 Phase 1 通过。
