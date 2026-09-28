# 跨酒馆转场的源码结果核对

2026-09-28 当前树局部审计。`run.gd` SHA-256：`2cd7ca0596ae84e32f83a707cf509361c002862b69e45f2fc96dfcc1d9d2c4ca`；`transfer_coverage_test.gd`：`1acca93dc6c13f1aca24891fd11c6fab6865f911c08d3929a85217e21d898bb0`。执行证据为 `output/3d/transfer-coverage.json`、完整回归 `output/3d/regression/20260928-222303/report.json`，以及同一回归内 `venue_order_test.gd`、`venue_transfer_test.gd` 和 Python 跨进程套件。

本表从 `Run.transfer_quote()` 和 `Run.transfer_venue()` 的条件、写入出发。报价读取普通出口结果，因出口未知或风声 6 被拒绝时沿用报价原因；普通出口内部费用与守卫已在[路线源码审计](route-source-audit.md)中核对，不重复计入转场局部分母。

| 源码条件或写入 | 对应目录结果 | 后继证据 |
|---|---|---|
| 旧 revision；未出发；仍在牌桌；目的地不存在或本晚已到访 | `transfer.stale_revision`、`inactive`、`table_active`、`unknown_destination`、`already_visited` | 报价或执行拒绝，完整 Run checkpoint 不变 |
| 本店还没完成一桌；四桌已完成；行动力不足；现金不够支付普通出口费加 15 车费 | `transfer.no_local_completion`、`evening_complete`、`no_action_points`、`insufficient_cash` | 边界费用在报价中可见，执行拒绝不扣费 |
| 普通出口未发现或已因风声 6 封锁 | `transfer.exit_unknown`、`exit_locked` | 转场复用普通出口的拒绝原因，不绕过出口守卫 |
| 转场成功 | `transfer.success` | 一次扣报价费用和 1 行动力，记录源/目标与完成桌数；保留整晚牌桌种子、对手、事件、房间图、背包与已完成桌；生成目标酒馆货架和初始接应方案，清空本地出口线索与预约并更新到店完成数、revision |

局部目录为 **12 个语义结果，12 个有当前后继证据**。`transfer_coverage_test.gd` 还核对无计划及 v1 计划的兼容后继；`venue_transfer_test.gd` 覆盖四酒馆的 12 个有序转场对、真实牌桌后付费转场及 UI 确认；`venue_order_test.gd` 用固定策略覆盖 24 种四酒馆访问顺序。`test_process_restart.py` 现有一条无解锁夹具的四酒馆三次转场样本：第三家酒馆牌局中途退出，第二进程恢复后完成第四桌、第三次转场和撤离，逐段财富及最终金库相符。受控弃牌和有限种子不证明所有策略或物品组合；12/12 不代表全局 ≥95%。源码或测试哈希变化后须重新核对。
