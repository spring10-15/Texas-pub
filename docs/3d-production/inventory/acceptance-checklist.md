# 验收清单 / Acceptance Checklist

> 适用于《德扑酒馆：赢了就撤!》浏览器版可执行检查清单。
> 3D 迁移前只验证当前浏览器游戏功能；3D 迁移后本清单需相应更新。
> 默认状态 = "未执行"；实际结果与证据位置由 QA 填写。

---

## 一、场景进入与返回 / Scene Entry & Return

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-MENU-001 | menu | 初始加载 | 1. 打开游戏页面 | 菜单画面显示标题、Start / Load / Exit 按钮 |  | 未执行 |  |
| AC-MENU-002 | menu | 初始加载 | 1. 点击 Start Game | 消耗 vault 金额，进入 search 模式，run 状态正确初始化 |  | 未执行 |  |
| AC-MENU-003 | menu | 有已保存 run | 1. 点击 Load Game | 正确恢复存档状态（search 或 table 模式） |  | 未执行 |  |
| AC-MENU-004 | menu | 无存档 | 1. 点击 Load Game | 留在菜单，不报错，不崩溃 |  | 未执行 |  |
| AC-STASH-001 | stash | search 模式，floor 未 enter | 1. 进入 search 模式 | 首次 landing 为藏匿点场景，显示个人资产、服务弹窗入口、文件夹入口 |  | 未执行 |  |
| AC-STASH-002 | stash | stash 场景 | 1. 点击服务入口 | 打开服务 modal（购买/出售/降热/预订撤离） |  | 未执行 |  |
| AC-STASH-003 | stash | stash 场景 | 1. 点击文件夹入口 | 打开文件夹 modal（情报/笔记） |  | 未执行 |  |
| AC-STASH-004 | stash | stash 场景 | 1. 点击 "Hit the Tavern" | 进入 tavern 场景，floorEntered 标记为 true |  | 未执行 |  |
| AC-STASH-005 | stash→tavern | 已 enter floor | 1. 从 stash 点击 "Hit the Tavern" | 不能返回 stash-only 状态；stash-cash 不可用 |  | 未执行 |  |
| AC-TAVERN-001 | tavern | search 模式，floor 已 enter | 1. 从 stash 进入 tavern floor | 显示酒馆场景，4 个热点可交互（台桌、吧台、门口、货架） |  | 未执行 |  |
| AC-TAVERN-002 | tavern | tavern 场景 | 1. 点击各个热点 | 各自弹出对应的 modal（台桌入口、服务、撤离、文件夹等） |  | 未执行 |  |
| AC-TAVERN-003 | tavern | tavern 场景 | 1. 点击撤离路线卡片 | 弹出撤离路线详情，可预订或确认出发 |  | 未执行 |  |
| AC-TAVERN-004 | tavern | tavern 场景 | 1. 点击 "Join Game" 某张台桌 | 检查解锁条件，满足则进入牌桌，不满足则提示 |  | 未执行 |  |
| AC-TAVERN-005 | tavern→table | 进入牌桌成功 | 1. 从 tavern 选择可进入的台桌 | 切换到牌桌场景，消耗 buy-in，显示手牌 |  | 未执行 |  |
| AC-TABLE-EXIT-001 | table→tavern | 牌桌完成（全部手数） | 1. 最后一手牌结束 | 自动返回 tavern search 模式，显示上一手结果 |  | 未执行 |  |
| AC-EXTRACT-001 | extraction | 撤离成功 | 1. 选择任意撤离路线并确认 | 进入 summary 场景，显示成功结算 |  | 未执行 |  |
| AC-EXTRACT-002 | extraction | heat=6 时尝试通用出口 | 1. 在 heat=6 状态下尝试通用出口 | notify 提示 generalExtractionShut，cashOnHand 未扣，未进入 summary 场景 |  | 未执行 |  |
| AC-EXTRACT-003 | extraction | 现金不足支付 general extraction fee | 1. 现金不足以支付 fee 时尝试通用出口 | notify 提示 notEnoughForGeneralExtractionFee，未进入 summary 场景 |  | 未执行 |  |
| AC-EXTRACT-004 | extraction | 撤离失败演出 | 1. 触发 extraction-failure 路径（具体条件待代码核实） | 进入 summary 场景并播放 extraction-failure.mp4 |  | 未执行 |  |

---

## 二、角色卡墙/穿墙/出生位置 / Character Collision & Spawn

> **浏览器版不适用，3D 迁移后启用。**
> 当前浏览器游戏无自由移动角色，无碰撞检测。

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-PHYS-001 | 全局 | N/A | N/A | 浏览器版不适用：游戏为面板点击操作，无自由移动角色 |  | N/A |  |
| AC-PHYS-002 | menu→stash | 首次进入 stash | 1. 从 menu 点击进入 stash | 第一帧视角与地面/桌面/墙体无穿插，出生点无穿插 |  | 未执行 |  |
| AC-PHYS-003 | stash | stash 场景 | 1. 镜头靠近门/窗/桌角 | 镜头靠近门/窗/桌角时不穿模 |  | 未执行 |  |
| AC-PHYS-004 | stash | stash 场景 | 1. 观察入口门 | 进入时门是否旋转/打开（未集成则 N/A） |  | 未执行 |  |
| AC-PHYS-005 | tavern | 进入酒馆 | 1. 从 stash 进入各酒馆 | 视角与桌椅/吧台无穿插 |  | 未执行 |  |
| AC-PHYS-006 | tavern | tavern 场景 | 1. 镜头靠近酒馆墙体 | 镜头靠近酒馆墙体不穿模 |  | 未执行 |  |
| AC-PHYS-007 | tavern | tavern 场景 | 1. 接近台桌/吧台/撤离门热点 | 接近台桌/吧台/撤离门热点时显示可交互提示 |  | 未执行 |  |
| AC-PHYS-008 | poker-table-{tableId} | 入座后 | 1. 入座后检查视角 | 视角与牌桌/椅子/其他对手模型无穿插 |  | 未执行 |  |
| AC-PHYS-009 | poker-table | 牌桌行动中 | 1. 第一人称转视角环视 | 牌桌行动时可环视（第一人称转视角）不穿模 |  | 未执行 |  |
| AC-PHYS-010 | extraction-success | 撤离成功演出 | 1. 触发撤离成功路径 | 撤离成功演出视角与角色/警车/巷道无穿插 |  | 未执行 |  |
| AC-PHYS-011 | extraction-failure | 撤离失败演出 | 1. 触发 extraction-failure 路径 | 撤离失败演出视角与角色/抓捕者无穿插 |  | 未执行 |  |
| AC-PHYS-012 | 全局 | 场景切换 | 1. 执行 stash↔tavern、tavern↔table、table→summary 切换 | 场景切换有短过渡，不出现黑帧 |  | 未执行 |  |
| AC-PHYS-013 | stash/tavern | 持有物品时 | 1. 持有物时使用道具 | 使用道具不与场景物体穿插 |  | 未执行 |  |

---

## 三、可交互物件提示/误操作 / Interactive Object Hints & Misoperation

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-HOTSPOT-001 | stash | stash 场景 | 1. 鼠标悬停在各热点上 | 显示对应提示（服务、文件夹、前往酒馆） |  | 未执行 |  |
| AC-HOTSPOT-002 | tavern | tavern 场景 | 1. 鼠标悬停在各热点上 | 显示热点描述（台桌/服务/撤离/文件夹） |  | 未执行 |  |
| AC-HOTSPOT-003 | stash/tavern | modal 已打开 | 1. 点击 modal 外部区域或按 Esc | 关闭 modal，回到主场景 |  | 未执行 |  |
| AC-HOTSPOT-004 | stash/tavern | modal 已打开 | 1. 再次点击同一热点 | 不重复打开，避免误叠加 |  | 未执行 |  |
| AC-HOTSPOT-005 | tavern | tavern 场景 | 1. 尝试点击被其他元素遮挡的热点 | 遮挡热点不可点击，或有视觉提示不可交互 |  | 未执行 |  |
| AC-HOTSPOT-006 | stash/tavern | 热点正在动画 | 1. 热点动画过程中点击 | 动画不干扰点击区域判定 |  | 未执行 |  |

---

## 四、面板开关鼠标/移动状态 / Panel Open/Close Mouse & Movement State

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-PANEL-001 | stash | 无 modal 打开 | 1. 点击服务入口 | modal 打开，鼠标变为可点击 modal 内元素 |  | 未执行 |  |
| AC-PANEL-002 | stash | modal 打开 | 1. 按 Esc 或点击外部 | modal 关闭，鼠标恢复场景交互 |  | 未执行 |  |
| AC-PANEL-003 | tavern | 无 modal 打开 | 1. 点击热点打开 modal | modal 打开，背景热点暂时不可交互 |  | 未执行 |  |
| AC-PANEL-004 | table | table 场景 | 1. 打开玩家信息面板（点击座位） | 面板打开，不遮挡底部的动作按钮 |  | 未执行 |  |
| AC-PANEL-005 | table | 玩家信息面板打开 | 1. 再次点击座位或按 Esc | 面板关闭，动作按钮恢复 |  | 未执行 |  |
| AC-PANEL-006 | extraction | 路线审查 modal 打开 | 1. 点击路线卡片查看详情 | 详情 modal 打开，不影响路线列表 |  | 未执行 |  |
| AC-PANEL-007 | extraction | 路线详情 modal 打开 | 1. 确认撤离或取消 | modal 关闭，进入对应目标场景 |  | 未执行 |  |

---

## 五、入座/离座/牌面/金额显示 / Sit/Leave/Hand/Amount Display

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-TABLE-001 | table | 进入牌桌成功 | 1. 查看初始界面 | 显示：手牌（2张）、公共牌区（空或已发）、当前 pot、current bet、自己的 stack |  | 未执行 |  |
| AC-TABLE-002 | table | 初始状态 | 1. 查看对手显示 | 显示两个对手的座位、stack；隐藏的手牌显示为背面 |  | 未执行 |  |
| AC-TABLE-003 | table | 翻牌前 | 1. 查看手牌和对手 | 手牌正确显示（2张）；对手各显示2张背面牌 |  | 未执行 |  |
| AC-TABLE-004 | table | 翻牌后 | 1. 查看公共牌区 | 显示3张公共牌（flop），格式正确（花色+点数） |  | 未执行 |  |
| AC-TABLE-005 | table | 转牌后 | 1. 查看公共牌区 | 显示4张公共牌（含转牌） |  | 未执行 |  |
| AC-TABLE-006 | table | 河牌后 | 1. 查看公共牌区 | 显示5张公共牌（含河牌） |  | 未执行 |  |
| AC-TABLE-007 | table | 任意时刻 | 1. 查看 pot 和 call 金额 | pot 金额正确显示；当前 call 金额正确显示 |  | 未执行 |  |
| AC-TABLE-008 | table | 任意时刻 | 1. 查看自己的 stack | 自己的剩余 stack 实时更新 |  | 未执行 |  |
| AC-TABLE-009 | table | 任意时刻 | 1. 查看手牌 | 手牌显示正确花色符号（♠♥♦♣）和点数 |  | 未执行 |  |
| AC-TABLE-010 | table | 显示手牌时 | 1. 查看 face card | J/Q/K/A 正确显示为人头牌标识，非数字 |  | 未执行 |  |
| AC-TABLE-011 | table | 最后一手结束 | 1. 查看结算信息 | 显示：各玩家手牌、底池归属、胜负结果 |  | 未执行 |  |
| AC-TABLE-012 | table | 手牌结算后 | 1. 等待自动返回 tavern | 正确返回 search 模式，显示上一手结果和奖励信息 |  | 未执行 |  |

---

## 六、牌桌动作合法性 / Poker Action Legality

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-TABLE-013 | table | 轮到玩家行动 | 1. 尝试执行非法动作（如 all-in 不可用时点击 all-in） | 非法动作按钮禁用或点击无效，不改变游戏状态 |  | 未执行 |  |
| AC-TABLE-014 | table | 有 current bet | 1. 只能选择 fold / call / raise（check 不可用） | 正确显示可用动作，fold/call/raise 可用 |  | 未执行 |  |
| AC-TABLE-015 | table | 无 current bet | 1. 只能选择 check / raise（fold 不可用） | 正确显示可用动作，check/raise 可用 |  | 未执行 |  |
| AC-TABLE-016 | table | call 金额超过玩家 stack | 1. 尝试 call | 触发 all-in 处理，stack 全部进入 pot |  | 未执行 |  |
| AC-TABLE-017 | table | raise 可用 | 1. 尝试 raise | raise 金额为当前 table 规定的 increment，不超过玩家 stack |  | 未执行 |  |
| AC-TABLE-018 | table | fold | 1. 点击 fold | 玩家放弃当前手牌，pot 归胜者，记录 fold 类型 lastHandSummary |  | 未执行 |  |
| AC-TABLE-019 | table | check | 1. 在无 bet 时点击 check | 行动传递到下一位玩家，不改变 pot |  | 未执行 |  |
| AC-TABLE-020 | table | all-in | 1. 在 all-in 可用时点击 | 全部 stack 押入 pot，手牌继续参与对抗 |  | 未执行 |  |

---

## 七、道具使用条件/库存/消耗 / Item Usage Conditions/Inventory/Consumption

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-ITEM-001 | search | inventory 未满，AP 充足 | 1. 从服务 modal 购买道具 | 消耗 cash，增加 inventory 记录，AP -1 |  | 未执行 |  |
| AC-ITEM-002 | search | inventory 已满 | 1. 尝试购买道具 | 购买失败，cash 不变，inventory 不变 |  | 未执行 |  |
| AC-ITEM-003 | search | inventory 有 valuables | 1. 出售全部 valuables | valuables 转为 cash on hand，inventory 清空，AP -1 |  | 未执行 |  |
| AC-ITEM-004 | search | inventory 有可消耗道具 | 1. 使用 steadying drink（heat > 0） | heat -1，道具从 inventory 移除 |  | 未执行 |  |
| AC-ITEM-005 | search | heat = 0 | 1. 使用 steadying drink | 道具保留，heat 不变（无法降低） |  | 未执行 |  |
| AC-ITEM-006 | search | 已用过 reduce-heat | 1. 再次尝试 reduce-heat | 本次 search phase 不能再降低 heat（per-phase 限制） |  | 未执行 |  |
| AC-ITEM-007 | search | 持有 disposable phone | 1. 使用 phone intent=refresh-route | 固定撤离路线轮换，消耗道具 |  | 未执行 |  |
| AC-ITEM-008 | search | 持有 disposable phone | 1. 使用 phone intent=reveal tableId | 指定 table 全部 intel 层解锁，消耗道具 |  | 未执行 |  |
| AC-ITEM-009 | search | inventory 有可出售道具 | 1. 单独出售一个道具 | 获得 sell 价格对应现金，道具从 inventory 移除 |  | 未执行 |  |
| AC-ITEM-010 | table | 持有 marked lens，本桌未用过 | 1. 在 flop 后、turn 前使用 | 显示1张未揭示公共牌内容，道具移除，heat +1 |  | 未执行 |  |
| AC-ITEM-011 | table | 持有 signal lighter，本桌未用过 | 1. 使用 signal lighter | 停留在 inventory，直到选择目标对手 |  | 未执行 |  |
| AC-ITEM-012 | table | signal lighter 已选目标 | 1. 选择对手座位 | 显示该对手当前压力（weak/medium/strong），道具移除 |  | 未执行 |  |
| AC-ITEM-013 | table | 持有 sleeve clip，preflop 阶段 | 1. 使用 sleeve clip | 换第二张手牌，道具移除，heat +2 |  | 未执行 |  |
| AC-ITEM-014 | table | 持有 sleeve clip，非 preflop | 1. 尝试使用 sleeve clip | 使用无效，道具保留 |  | 未执行 |  |
| AC-ITEM-015 | table | marked lens 已使用过 | 1. 再次尝试使用 marked lens | 本桌不可重复使用 |  | 未执行 |  |
| AC-ITEM-016 | table | marked lens peek 后用 sleeve clip | 1. 顺序使用两个道具 | peek 结果不受 sleeve clip 影响（同一公共牌） |  | 未执行 |  |

---

## 八、情报收集 / Intel Gathering

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-INTEL-001 | search | AP >= 1 | 1. 对 cargo-table 收集 rule 层 intel | rule 层标记为 true，AP -1，cash 不变 |  | 未执行 |  |
| AC-INTEL-002 | search | intel 已收集 | 1. 重复收集同一层 intel | 不消耗 AP，intel 保持 true |  | 未执行 |  |
| AC-INTEL-003 | search | AP = 0 | 1. 尝试收集 intel | 收集失败，AP 保持 0 |  | 未执行 |  |
| AC-INTEL-004 | search | AP = 1 | 1. 连续收集 intel（两次不同层） | 第一次成功 AP 归 0，第二次失败 |  | 未执行 |  |
| AC-INTEL-005 | search | 持有 disposable phone | 1. 对未解锁 table 使用 reveal | 全部 intel 层解锁 |  | 未执行 |  |

---

## 九、撤离条件/扣款/损失说明/结算 / Extraction Conditions/Deduction/Loss/Settlement

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-EXTRACT-GEN-001 | extraction | heat < 6，cash 充足，public exit 已解锁 | 1. 选择 general extraction 并确认 | 扣除 fee + rate% + lockdown surcharge（如 heat=5），进入 summary success |  | 未执行 |  |
| AC-EXTRACT-GEN-002 | extraction | heat = 6 | 1. 尝试 general extraction | 失败，留在 search |  | 未执行 |  |
| AC-EXTRACT-GEN-003 | extraction | cash 不足支付 general extraction fee | 1. 尝试 general extraction | 失败，触发死局，进入 summary failure（caught=true） |  | 未执行 |  |
| AC-EXTRACT-GEN-004 | extraction | heat = 5 | 1. general extraction | 收取额外 lockdown surcharge |  | 未执行 |  |
| AC-EXTRACT-FIXED-001 | extraction | 有有效固定路线预订，heat 满足，cash 充足 | 1. extract-fixed | 扣除 finalCost，进入 summary success |  | 未执行 |  |
| AC-EXTRACT-FIXED-002 | extraction | 无固定路线预订 | 1. 尝试 extract-fixed | 失败，留在 search |  | 未执行 |  |
| AC-EXTRACT-FIXED-003 | extraction | 固定路线过期（expiresAfterSearch 耗尽） | 1. 尝试 extract-fixed | 失败，预订清除 |  | 未执行 |  |
| AC-EXTRACT-FIXED-004 | extraction | heat 超出 maxHeat | 1. 尝试 extract-fixed | 失败，留在 search |  | 未执行 |  |
| AC-EXTRACT-FIXED-005 | extraction | cash 不足以支付 finalCost | 1. 尝试 extract-fixed | 失败，留在 search |  | 未执行 |  |
| AC-EXTRACT-DROPBAG-001 | extraction | 已预订 emergency 路线，cash 充足 | 1. extract-dropbag-cash | 扣除 10，丢失 40% cash on hand，进入 summary success |  | 未执行 |  |
| AC-EXTRACT-DROPBAG-002 | extraction | 已预订 emergency 路线，持有 valuables | 1. extract-dropbag-valuables | 扣除 10，丢失全部 valuables，进入 summary success |  | 未执行 |  |
| AC-EXTRACT-DROPBAG-003 | extraction | 无 valuables 但选 valuables 路线 | 1. 尝试 extract-dropbag-valuables | 失败，留在 search |  | 未执行 |  |
| AC-EXTRACT-SERVICE-001 | extraction | 已解锁 service-stairs，cash 充足 | 1. 路线已解锁且 heat<=5 | 可使用 service-stairs，扣除 finalCost |  | 未执行 |  |
| AC-EXTRACT-RIVER-001 | extraction | 已解锁 river-launch，cash 充足 | 1. 路线已解锁且 heat<=4 | 可使用 river-launch，扣除 finalCost |  | 未执行 |  |
| AC-SETTLE-001 | summary | 成功撤离 | 1. 查看 summary 界面 | 显示：totalSettled、stashedCash 扣费后金额、carried valuables 结算金额 |  | 未执行 |  |
| AC-SETTLE-002 | summary | 失败撤离 | 1. 查看 summary 界面 | 显示：salvaged（wallet 保护）、seizedCash（被抓） |  | 未执行 |  |
| AC-SETTLE-003 | summary | 失败撤离，无 false-bottom wallet | 1. 查看 summary 界面 | salvaged = 0，seizedCash = 全部 cash on hand |  | 未执行 |  |
| AC-SETTLE-004 | summary | 失败撤离，有 false-bottom wallet | 1. 查看 summary 界面 | salvaged = min(80, cash on hand)，seizedCash = 剩余 |  | 未执行 |  |

---

## 十、路线预订 / Route Reservation

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-ROUTE-001 | search | AP >= 1，cash 充足 | 1. 预订固定撤离路线 | 消耗 AP 和 reserveCost，固定路线预订生效 |  | 未执行 |  |
| AC-ROUTE-002 | search | 已有固定路线预订 | 1. 再次预订固定路线 | 替换已有预订，不累积 |  | 未执行 |  |
| AC-ROUTE-003 | search | 预订后返回 search 但未使用 | 1. 预订后不触发撤离，搜索两次后回来 | 固定路线过期，预订清除 |  | 未执行 |  |
| AC-ROUTE-004 | search | 持有 kitchen-pass | 1. 购买 kitchen-pass 并使用 | 解锁 service-stairs 路线（需在正确酒馆） |  | 未执行 |  |
| AC-ROUTE-005 | search | 持有 dock-passkey | 1. 购买 dock-passkey 并使用 | 解锁 river-launch 路线（需在正确酒馆） |  | 未执行 |  |

---

## 十一、特定台桌规则 / Specific Table Rules

### Cargo Table

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-TABLE-CARGO-001 | cargo-table | 进入 cargo table | 1. 查看台桌信息 | 显示：buy-in=60，risk=Low，heatGain=+1 |  | 未执行 |  |
| AC-TABLE-CARGO-002 | cargo-table | 第一手第一 raise | 1. 执行第一笔 aggressive action | 实际 raise 金额少 10（first aggression discount） |  | 未执行 |  |
| AC-TABLE-CARGO-003 | cargo-table | 完成全部手数，正向结果 | 1. 盈利状态完成牌桌 | 获得 reward：Ivory Chip（60 value）或其他 low/mid-tier valuable |  | 未执行 |  |
| AC-TABLE-CARGO-004 | cargo-table | inventory 已满时完成 | 1. 满 inventory 状态盈利完成 | reward 无法添加，rewardAdded=false |  | 未执行 |  |

### Ledger Cellar

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-TABLE-LEDGER-001 | ledger-cellar | 进入 ledger cellar | 1. 查看台桌信息 | 显示：buy-in=90，risk=Medium，需 cargo-table 完成解锁 |  | 未执行 |  |
| AC-TABLE-LEDGER-002 | ledger-cellar | 使用任意 table tool | 1. 在 ledger cellar 使用 marked lens | heat +1（额外 tableToolHeatBonus） |  | 未执行 |  |

### Mirror Hall

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-TABLE-MIRROR-001 | mirror-hall | 进入 mirror hall | 1. 查看台桌信息 | 显示：buy-in=120，risk=Medium-High，allowCollateral=true |  | 未执行 |  |
| AC-TABLE-MIRROR-002 | mirror-hall | 进入时携带 collateral | 1. 选择一个 valuable 作为 collateral 进入 | collateral 附加到手牌，最终手有额外 reward 线 |  | 未执行 |  |
| AC-TABLE-MIRROR-003 | mirror-hall | 最终手获胜， collateral 有效 | 1. 完成盈利最终手 | collateral 退回，获得 Antique Coin（140）奖励 |  | 未执行 |  |
| AC-TABLE-MIRROR-004 | mirror-hall | 最终手失败，collateral 有效 | 1. 完成亏损最终手 | collateral 丢失，标记 collateralLost=true |  | 未执行 |  |
| AC-TABLE-MIRROR-005 | mirror-hall | 未携带 collateral 完成 | 1. 无 collateral 进入，完成盈利 | 获得普通 reward，无 premium reward |  | 未执行 |  |

### Embers Table

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-TABLE-EMBERS-001 | embers-table | 进入 embers table | 1. 查看台桌信息 | 显示：buy-in=160，risk=High，heatGain=+2 |  | 未执行 |  |
| AC-TABLE-EMBERS-002 | embers-table | 盈利关闭牌桌 | 1. 完成盈利状态关闭 | heat -1（winHeatRelief） |  | 未执行 |  |

---

## 十二、成功/失败后能否进入下一步 / Post-Outcome Progression

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-PROG-001 | summary | success summary | 1. 在 summary 界面点击继续 | 回到菜单，显示 run 结果计入 persistent vault |  | 未执行 |  |
| AC-PROG-002 | summary | failure summary | 1. 在 summary 界面点击继续 | 回到菜单，vault 不变，runCount 记录 |  | 未执行 |  |
| AC-PROG-003 | summary | success summary | 1. 点击开始新 run | 从 vault 扣取 bankroll，新 run 开始 |  | 未执行 |  |
| AC-PROG-004 | table→summary | 完成牌桌后触发死局（cash=0 且 heat>=6） | 1. 牌桌结束后状态 | 直接进入 failure summary，不留 search 停留 |  | 未执行 |  |

---

## 十三、保存/恢复 / Save & Load

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-SAVE-001 | search | 任意 search 状态 | 1. 正常游戏（无需手动触发，自动按操作节点保存） | 每次状态变化后 localStorage 有对应 RUN_SAVE_KEY 快照 |  | 未执行 |  |
| AC-SAVE-002 | search | search 状态已保存 | 1. 刷新页面 | 刷新后 load-run 可恢复 cashOnHand、inventory、heat、stashedCash |  | 未执行 |  |
| AC-SAVE-003 | table | table 状态中 | 1. 刷新页面 | 刷新后 load-run 恢复到 table 模式，当前 table 内容完整 |  | 未执行 |  |
| AC-SAVE-004 | search | 已进入 floor | 1. 保存后加载 | floorEntered 状态保持 true，stash-cash 不可用 |  | 未执行 |  |
| AC-SAVE-005 | load | 无存档 | 1. 在菜单点击 Load Game | 留在菜单，不崩溃，不报错 |  | 未执行 |  |
| AC-SAVE-006 | search | 有存档，vault 不一致 | 1. 存档 vault=300，刷新页面，重新加载 | load-run 后 cashOnHand 和 vault 关系正确 |  | 未执行 |  |
| AC-RESET-001 | 全局 | 任意状态 | 1. 手动清除 localStorage | 游戏回到初始菜单状态，无残留状态 |  | 未执行 |  |

---

## 十四、中英文切换 / i18n Language Toggle

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-I18N-001 | menu | 初始状态 | 1. 点击语言切换 | 菜单所有 UI 文字切换为对应语言 |  | 未执行 |  |
| AC-I18N-002 | search | 语言已切换 | 1. 进入 search/stash/tavern | 所有可见文本（面板标题、按钮、提示）均为目标语言 |  | 未执行 |  |
| AC-I18N-003 | table | 语言已切换 | 1. 进入牌桌 | 手牌显示、动作按钮、pot 信息、对手名称均为目标语言 |  | 未执行 |  |
| AC-I18N-004 | extraction | 语言已切换 | 1. 进入撤离/总结 | 路线名称、费用说明、summary 字段均为目标语言 |  | 未执行 |  |
| AC-I18N-005 | 全局 | 切换语言后 | 1. 刷新页面 | 语言设置通过 localStorage 持久化，重启后保持 |  | 未执行 |  |
| AC-I18N-006 | 全局 | 游戏中途切换 | 1. 在 search 或 table 途中切换语言 | 当前场景 UI 立即更新，不中断游戏状态 |  | 未执行 |  |

---

## 十五、BGM 按场景切换 / BGM Per Mode

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-AUDIO-001 | 全局 | 游戏启动 | 1. 打开游戏页面 | 菜单有对应 BGM 播放（menu.ogg 或场景指定 bgm） |  | 未执行 |  |
| AC-AUDIO-002 | stash/tavern | 进入 search 场景 | 1. 进入 stash 或 tavern | 播放对应场景 BGM（如 tavern-smoky-den.ogg） |  | 未执行 |  |
| AC-AUDIO-003 | table | 进入牌桌 | 1. 进入任意牌桌 | 播放 table BGM（场景关联） |  | 未执行 |  |
| AC-AUDIO-004 | extraction | 进入 summary | 1. 进入 summary | 播放 extraction/summary BGM |  | 未执行 |  |
| AC-AUDIO-005 | 全局 | 场景切换 | 1. 从 tavern 进入 table | tavern BGM 停止，table BGM 开始 |  | 未执行 |  |
| AC-AUDIO-006 | 全局 | 静音/静音恢复 | 1. 切换标签页后回来 | BGM 继续播放（或根据标签页可见性暂停/恢复） |  | 未执行 |  |

---

## 十六、视频背景 manifest 回退 / Video Background Manifest Fallback

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-VIDEO-001 | 全局 | manifest.json 可用 | 1. 检查 assets/videos/manifest.json | 各场景视频路径正确配置 |  | 未执行 |  |
| AC-VIDEO-002 | 全局 | manifest.json 缺失或损坏 | 1. 临时移除 manifest.json 或破坏格式 | 游戏使用静态背景图（scene plate）回退，不崩溃 |  | 未执行 |  |
| AC-VIDEO-003 | 全局 | 视频文件缺失 | 1. 场景配置的视频文件不存在 | 游戏使用回退图片，不白屏，不报错 |  | 未执行 |  |

---

## 十七、缺贴图/画面问题 / Missing Texture / Visual Issues

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-VISUAL-001 | 全局 | 初始加载 | 1. 加载游戏，检查所有场景 | 无缺贴图（broken image icon）、无模型闪烁、无错误图标 |  | 未执行 |  |
| AC-VISUAL-002 | table | 牌桌显示 | 1. 检查手牌和公共牌 | 扑克牌 PNG 正确加载，无透明背景被场景色污染 |  | 未执行 |  |
| AC-VISUAL-003 | table | 手牌翻转 | 1. 查看手牌从背面到正面 | 翻转动画完整，无闪烁或残影 |  | 未执行 |  |
| AC-VISUAL-004 | search | 热点悬停 | 1. 悬停在各热点上 | hover 状态有视觉反馈，不卡顿 |  | 未执行 |  |
| AC-VISUAL-005 | 全局 | 窗口缩放 | 1. 调整浏览器窗口大小 | UI 响应式布局，无溢出、无裁剪、无重叠 |  | 未执行 |  |
| AC-VISUAL-006 | 全局 | 快速切换场景 | 1. 快速在场景间切换（stash↔tavern↔table） | 无场景残留、无动画叠加、无状态混乱 |  | 未执行 |  |
| AC-VISUAL-007 | 全局 | 低配设备/老旧浏览器 | 1. 在老旧浏览器或低性能设备测试 | 无白屏、无 JS 崩溃、降级优雅 |  | 未执行 |  |

---

## 十八、对手 AI 行为 / Opponent AI Behavior

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-OPPONENT-001 | table | 任意牌桌 | 1. 观察两个对手的行为 | 对手按各自 archetype 风格行动（maniac/nit/shark/calling-station/fish） |  | 未执行 |  |
| AC-OPPONENT-002 | table | Mirror Hall 最终手 | 1. 在 Mirror Hall 观察 Smiling Knife | finalHandSpike=0.24，最终手压力上升 |  | 未执行 |  |
| AC-OPPONENT-003 | table | Mirror Hall | 1. 观察 Calm Widow | patternPunish=0.18，重复策略会被惩罚 |  | 未执行 |  |
| AC-OPPONENT-004 | table | Cargo Table | 1. 观察 Dock Braggart | aggression=0.76，bluff=0.24，偏激进 |  | 未执行 |  |
| AC-OPPONENT-005 | table | Cargo Table | 1. 观察 Ledger Clerk | caution=0.74，tight 风格，不轻易下注 |  | 未执行 |  |
| AC-OPPONENT-006 | table | 任意对手 | 1. 对手行动后 | 及时响应，无长时间无响应卡顿 |  | 未执行 |  |

---

## 十九、台桌解锁顺序 / Table Unlock Sequence

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-UNLOCK-001 | tavern | 初始状态 | 1. 查看可进入的台桌 | 只有 cargo-table 可选；mirror-hall/embers 锁定 |  | 未执行 |  |
| AC-UNLOCK-002 | tavern | cargo-table 完成 | 1. 进入 ledger-cellar | ledger-cellar 解锁，可进入 |  | 未执行 |  |
| AC-UNLOCK-003 | tavern | ledger-cellar 完成 | 1. 进入 mirror-hall | mirror-hall 解锁，可进入 |  | 未执行 |  |
| AC-UNLOCK-004 | tavern | mirror-hall 完成 | 1. 进入 embers-table | embers-table 解锁，可进入 |  | 未执行 |  |
| AC-UNLOCK-005 | tavern | cash 不足 | 1. buy-in 超过 cash on hand 时尝试进入 | 进入失败，留在 search |  | 未执行 |  |

---

## 二十、热量（Heat）系统 / Heat System

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-HEAT-001 | 全局 | 初始状态 | 1. 查看 heat 值 | heat = 0 |  | 未执行 |  |
| AC-HEAT-002 | table | 进入任意牌桌 | 1. 进入 Cargo Table | heat += 1 |  | 未执行 |  |
| AC-HEAT-003 | table | 进入 Mirror Hall | 1. 进入 Mirror Hall | heat += 2 |  | 未执行 |  |
| AC-HEAT-004 | search | 使用 marked lens | 1. 在 search 使用 marked lens（非 search phase item，但 heat 相关） | heat +1 |  | 未执行 |  |
| AC-HEAT-005 | search | 使用 sleeve clip | 1. 在 table 使用 sleeve clip | heat +2 |  | 未执行 |  |
| AC-HEAT-006 | search | 成功 reduce-heat | 1. 消耗 AP + cash 降低 heat | heat -= 1（按当前酒馆配置扣费） |  | 未执行 |  |
| AC-HEAT-007 | 全局 | heat = 5 | 1. 查看当前状态 | 显示 dangerous 状态，general extraction 有额外 surcharge |  | 未执行 |  |
| AC-HEAT-008 | 全局 | heat = 6 | 1. 查看当前状态 | 显示 lockdown 状态，general extraction 不可用 |  | 未执行 |  |

---

## 二十一、仓库（Stash）规则 / Stash Rules

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-STASH-006 | stash | floor 未 enter | 1. 在藏匿点尝试 stash-cash | 本版本已禁用，cash 不转移，stashedCash=0 |  | 未执行 |  |
| AC-STASH-007 | search | floor 已 enter，AP >= 1 | 1. 在 tavern 尝试 stash-cash | 本版本已禁用，stashedCash=0 |  | 未执行 |  |
| AC-STASH-008 | extraction | 成功撤离 | 1. 查看 summary 中 stashedCash 处理 | stashedCash 按 fee band 扣费后计入 totalSettled |  | 未执行 |  |
| AC-STASH-009 | extraction | 撤离失败 | 1. 查看 summary | stashedCash 不结算，不计入 salvaged |  | 未执行 |  |

---

## 二十二、存钱桶（Vault）规则 / Vault Rules

| 检查编号 | 适用场景 | 前置条件 | 操作步骤 | 预期结果 | 实际结果 | 通过/失败/未执行 | 证据位置 |
|---|---|---|---|---|---|---|---|
| AC-VAULT-001 | menu | 初始状态 | 1. 查看 vault 金额 | vault = 1200（默认值） |  | 未执行 |  |
| AC-VAULT-002 | menu | 点击 Start Game | 1. 查看 vault 变化 | vault -= 300，cashOnHand = 300 |  | 未执行 |  |
| AC-VAULT-003 | summary | 成功撤离 | 1. 查看 vault 变化 | vault += totalSettled |  | 未执行 |  |
| AC-VAULT-004 | summary | 失败撤离 | 1. 查看 vault 变化 | vault 不变 |  | 未执行 |  |
| AC-VAULT-005 | 全局 | 多次 run | 1. 连续完成多个 run | vault 累积，runCount 累积，winCount 仅成功撤离时增加 |  | 未执行 |  |

---

## 二十三、未覆盖项目 / Out of Scope

以下项目属于未来 3D 迁移或 Milestone 3/4 范围，本清单暂不覆盖：

| 未覆盖项目 | 原因 | 何时纳入 |
|---|---|---|
| 3D 自由移动 / 碰撞检测 | 当前为浏览器面板游戏，无 3D 场景；3D 迁移后启用角色卡墙/穿墙/出生点检查 | 3D 迁移完成后 |
| 自由探索导航 | 浏览器版为 hotspot 点击，无自由移动；3D 第一人称探索在 Milestone 2 | 3D Blender 场景完成 |
| 多人联机 / 联网对战 | 当前为单-player；联网功能在 Milestone 4 范围外 | 明确规划联机时 |
| 战斗系统 | 无战斗；射击/动作类玩法不在本游戏设计内 | 不适用 |
| 驾驶系统 | 无驾驶载具 | 不适用 |
| roguelike 随机池（Milestone 3） | 当前为固定 authored 路径；Milestone 3 才启用 seeded pools | Milestone 3 启动前 |
| 新增台桌/对手/道具（Milestone 4） | 当前 scope 为 vertical slice 验证；内容扩张在 Milestone 4 | Milestone 4 启动前 |
| 音效（Sound Effects） | 仅 BGM 在 scope 内；音效在 visual-direction.md deferred 列表 | 音效规划时 |
| 自定义最终角色渲染 | visual-direction.md deferred；等 scene grammar 锁定后才引入 | scene grammar 锁定后 |
| 动画电影/过场动画 | visual-direction.md deferred | 内容扩充时 |
| 动态物品定价 | design-baseline.md 明确固定价格；早期版本无动态市场 | 明确规划经济系统时 |
| all-in 侧池 / 分池 | design-baseline.md 明确 vertical slice 不支持；仅单池 all-in 在 scope | 完整 Hold'em 规则引入时 |
| 非 TIHX Hold'em 规则变体 | 当前仅支持 TIHX Hold'em | 明确规划德扑变体时 |

---

## 统计摘要 / Summary

| 分类 | 检查数量 |
|---|---|
| 场景进入与返回 | 16 |
| 角色卡墙/穿墙/出生位置 | 13 |
| 可交互物件提示/误操作 | 6 |
| 面板开关鼠标/移动状态 | 7 |
| 入座/离座/牌面/金额显示 | 12 |
| 牌桌动作合法性 | 8 |
| 道具使用条件/库存/消耗 | 16 |
| 情报收集 | 5 |
| 撤离条件/扣款/损失说明/结算 | 20 |
| 路线预订 | 5 |
| 特定台桌规则（Cargo/Ledger/Mirror/Embers） | 11 |
| 成功/失败后能否进入下一步 | 4 |
| 保存/恢复 | 7 |
| 中英文切换 | 6 |
| BGM 按场景切换 | 6 |
| 视频背景 manifest 回退 | 3 |
| 缺贴图/画面问题 | 7 |
| 对手 AI 行为 | 6 |
| 台桌解锁顺序 | 5 |
| 热量（Heat）系统 | 8 |
| 仓库（Stash）规则 | 4 |
| 仓库（Vault）规则 | 5 |
| **合计** | **183** |

> 注：角色卡墙/穿墙/出生位置共 13 条；其中 AC-PHYS-001 为 N/A，其余 12 条标注"3D 迁移后启用"。

---

## 重要范围说明 / Scope Notes

**当前实现范围（Milestone 1 + 部分 Milestone 2）：**
- 浏览器可执行游戏：menu → stash → tavern → poker → extraction → summary
- 4 张台桌：Cargo Table、Ledger Cellar、Mirror Hall、Embers Table
- 固定 authored 路径（无 roguelike 随机）
- noir illustration 2.5D 场景迁移进行中

**3D 迁移后必须更新的检查项：**
- AC-PHYS-001/013（角色碰撞/出生点）
- 热点点击 → 第一人称射击检测
- 场景切换动画 → Blender 场景过渡

**主 Agent 建议明确的事项：**
1. **删除范围**：Ledger Cellar 和 Embers Table 是否在当前 vertical slice 验证范围（design-baseline.md 提到 4 张台桌，但 development-plan.md demo path 只验证了 Cargo 和 Mirror Hall）
2. **添加范围**：Player Notes（data.js 中定义为 search phase intel 工具）在 verify_full_game_flow.mjs 中没有验证路径，建议补充验证或移除
3. **澄清范围**：Sleeve Clip 在 design-baseline.md 的 vertical slice 中标注"vertical slice does not support all-in"，但 verify_full_game_flow.mjs 中有 all-in 测试；当前清单包含 all-in 合法性检查，但不包含完整的 side-pot/split-pot 规则
