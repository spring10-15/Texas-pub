# 普通服务与牌桌道具的源码结果核对

2026-09-28 当前树局部审计。`Godot/three_d/rules/run.gd` SHA-256：`2cd7ca0596ae84e32f83a707cf509361c002862b69e45f2fc96dfcc1d9d2c4ca`；`service_coverage_test.gd`：`18bcc2f7e4825efb3673c46cba428f028cd17f3a7015de7c926751f01dc4fa7a`；`tool_coverage_test.gd`：`922e68f7a571b6c7bcb5b1634b07d8e51e5b90467bc2e5070c74c3ebd6726da7`。执行证据为 `output/3d/service-coverage.json`、`output/3d/tool-coverage.json` 及完整回归 `output/3d/regression/20260928-221245/report.json`。

本表只核对 `Run.service_reason()` 和 `Run.service_action()` 内的普通服务与牌桌道具。`search` 在入口处交给 `SearchEvents`，`Advanced.KINDS` 交给 `Advanced`；它们的内部条件不计入这份局部分母。一个 ID 表示一种有区别的状态后继或拒绝原因，若多个输入共享同一拒绝与不变状态，则复用同一 ID。

| 源码条件或写入 | 对应目录结果 | 后继证据 |
|---|---|---|
| 旧 revision；未出发；道具动作与物品不匹配 | `service.stale_revision`、`tool.stale_revision`；`service.inactive`、`tool.inactive`；`service.mismatch`、`tool.mismatch` | 各测试分别比较拒绝前后的完整 Run checkpoint |
| 桌外服务遇到活动牌桌；行动力为零 | `service.table_active`、`service.no_actions` | 拒绝且完整状态不变 |
| 购买：未上架或不受支持、现金不足、背包槽位不足；成功扣价并入包 | `service.not_stocked`、`service.buy_cash`、`service.full_bag`、`service.buy` | 每种拒绝状态不变；成功按价格、物品、行动力、revision 核对 |
| 出售：物品不在背包；成功移除并按 `sale_value()` 加现金 | `service.sell_unowned`、`service.sell` | 成功路径另逐一核对 10 件贵重物的售价与总财富守恒 |
| 降风声：本轮已降或风声为零、缺镇定酒、酒保降风声现金不足；成功消耗酒或场景费用并降低风声 | `service.cool_unavailable`、`service.drink_unowned`、`service.cool_cash`、`service.drink`、`service.cool` | 两种不可用输入复用同一结果；成功核对风声、资源和行动力 |
| 查桌规：未知或已知；成功加入已知规则；未知动作 | `service.intel_unavailable`、`service.intel`、`service.unknown_action` | 两种不可用输入复用同一结果；成功与拒绝均核对 checkpoint |
| 道具使用前：非进行中牌桌、未持有、同桌已用；镜片在 river；袖口夹非翻牌前、已行动或非玩家回合 | `tool.no_table`、`tool.finished`、`tool.unowned`、`tool.used`、`tool.river`、`tool.after_preflop`、`tool.after_action`、`tool.other_actor` | 分别验证拒绝原因和完整 checkpoint 不变 |
| 镜片预览、袖口夹换牌、保留已预览牌、热度封顶 | `tool.lens`、`tool.sleeve`、`tool.preserve_preview`、`tool.heat_cap` | 核对牌堆、手牌、预览、物品消耗、桌面/Run revision 与热度 |

当前目录在此局部为 **34 个语义结果，34 个有当前后继证据**（普通服务 19、牌桌道具 15）。服务派发的两类外部实现、世界 UI 入口、这些动作与撤离的任意组合，以及全部可达状态条件，均不由本表证明。源码或测试哈希变化后须重新核对；不能把 34/34 换算为全游戏 ≥95% 状态转移覆盖率。
