# 牌桌状态入口源码结果核对

2026-09-29 局部审计。`Godot/three_d/rules/table.gd` SHA-256：`d248b457389321750dab5366c13da7b6ce346f933516ea2fd0dd6b3aed56217e`。本表从 `Table.start_hand`、`act`、`advance`、`next_hand` 的守卫和状态写入出发，核对当前 `transitions.json` 中以 `table.gd` 为来源的 **58 个已登记 ID**。它们包含同一成功路径内的附加结果，不能把 58 当作互斥的状态数，也不能换算为全游戏覆盖率。

| 源码入口与分支 | 已登记结果 | 2026-09-29 定向执行证据 |
|---|---:|---|
| `start_hand`：轮换庄位、短筹码盲注、按种子洗牌发牌、首次进攻折扣复位；不足两名有筹码玩家或玩家破产时结束 | 3 个直接归属；结束条件另归 `ending.*` | `poker_blind_coverage_test.gd` 1/1、`poker_discount_coverage_test.gd` 4/4、`table_test.gd` 1881 项 |
| `act`：revision/动作名/回合/座位/筹码及合法性拒绝；弃牌、过牌、跟注、开注、加注、全押和金额下限；行动队列重开或结束 | 35 个直接归属；结束条件另归 `ending.*` | `poker_guard_coverage_test.gd` 15/15、`poker_action_coverage_test.gd` 9/9、`short_stack_queue_test.gd` 590 项、`table_test.gd` 1881 项 |
| `advance`：拒绝未轮到街道推进和过期 revision；翻牌/转牌/河牌、摊牌派奖，单一有筹码座位自动跑牌 | 2 个直接归属、10 个与 `next_hand` 共属；结束条件另归 `ending.*` | `poker_progress_coverage_test.gd` 12/12、`short_stack_queue_test.gd` 590 项 |
| `next_hand`：仅在 `hand_over` 且 revision 匹配时进入下一手；重新发牌并处理单挑庄位 | 1 个直接归属，并共享上述推进结果 | `poker_progress_coverage_test.gd` 12/12、`table_endings_test.gd` 7/7 |
| `act`/`advance`/`next_hand` 共同到达 `finish_hand`：弃牌直接派奖、手数上限、可继续下一手、已弃牌玩家下手回归、仅余一名有筹码玩家、玩家破产 | 7 个 `ending.*` 结果 | `table_endings_test.gd` 7/7 |

`legal_actions` 只计算当前可选动作；`commit`、`set_queue` 和 `finish_hand` 是上述入口的内部写入步骤，`public_state` 是只读视图。其条件结果已按调用入口或队列/结束结果归属，不能因为这些方法没有单独 ID 就把它们当作漏测，也不能仅凭方法清单断言没有漏掉其它可达语义后继。

上述八个套件均以 Godot 4.7.2 `--headless --test` 在当前工作树执行，退出码为 0、报告无失败。审计只覆盖纯牌桌规则层；`Run` 买入/结算、世界层输入、存档恢复、对手 AI 和真实玩家决策另有入口。尤其是这些测试的通过不能证明所有牌局状态组合可达、账目任一路径误差为零或全局状态转移分母已经闭合。源码或目录变化后须重新核对本表。

2026-09-30 增补路径采样：`table_conservation_paths_test.gd` 用四种正式桌规各 64 个种子走完 256 桌，合法动作包含弃牌、过牌、跟注、加注和全押；每次入盲、行动、街道推进和进入下一手后都核对桌内筹码总额及非负栈。实测 6,821 项检查、0 失败。该测试补足固定行动剧本的路径组合，但有限种子与随机策略仍不是“任一路径零误差”的穷尽证明。
