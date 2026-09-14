# 状态转移覆盖：目录与执行证据

2026-09-14。transitions.json 是逐步审查中的语义转移目录，当前 status=incomplete_catalog。pending_families 明确保留未拆分的生命周期、服务、搜索、扑克、世界交互和持久化范围；不得把当前数组长度当作全游戏分母。

一个 ID 表示一次公开入口的成功结果或拒绝原因。多个输入命中同一结果只计一次。拒绝是同一状态上的自环，必须同时验证完整状态未变；只检查返回 false 不构成充分证据。子条件的短路求值覆盖、各种冲突条件的优先级、所有经济数值组合不由这份语义覆盖率替代，仍需要对应边界测试。

首批 transfer.* 共 12 项：成功、旧 revision、无活动局、活动牌桌、未知目的地、已经访问、本店尚未完成新桌、本晚结束、无行动力、现金不足、出口未发现、出口封锁。来源是 run.gd 的 transfer_quote/transfer_venue 和 routes.gd 的普通出口条件。返回原因的优先级可能使同时失效的条件被另一个原因覆盖，本批用例分别隔离各条件。

执行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
```

报告 output/3d/transfer-coverage.json 保存每个真实命中 ID、执行结果、所有规则文件、测试脚本与目录 SHA-256、缺失项及失败项。本轮 12/12；这是转场子图的结果。overall_state_transition_coverage 明确为 null。测试出现任何脚本错误，即使进程退出码为 0 也不得记通过。

后续工作：逐一审查 pending_families 的实际入口与内部结果，增补稳定 ID；在验证后继状态的测试中记录命中，再汇总同一源码版本的证据。全目录审查完成以前不计算 ≥95% 总覆盖率。已有大量断言与测试文件不自动转换成覆盖命中。

## 生命周期与防过期汇总（2026-09-14）

新增 start/reset/discover/extract/abandon/pressure 六组共 31 个具名结果。验证出发金库转移、120 门槛、六类撤离的现金/贵重物等式、重复到账拒绝、夹层钱包保留 80、封锁时可撤离与无路可走的失败分支。各拒绝结果检查完整 checkpoint 不变。路线报价内部守卫仍列在 pending_families.route_quotes，不能因 extract.rejected_quote 命中一例就将它们全部记通过。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/lifecycle_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
python3 Godot/three_d/tests/collect_coverage.py
python3 Godot/three_d/tests/test_collect_coverage.py
```

两份执行报告核对当前目录、所有规则文件及各自测试脚本的摘要。汇总器拒绝过期来源、已有失败、缺失或杜撰命中、夸大计数；3 个单元测试（含 7 个缺陷子情境）通过，缺陷只在内存中注入，不改真实证据文件。摘要文件 output/3d/coverage-summary.json 显示 43 个已登记结果均有当前证据，全局覆盖率仍为 null，未枚举的状态族保持显式待办。

## 撤离守卫与边界（2026-09-14）

route_guard.* 新增 24 个具名结果：20 个拒绝结果与 4 个允许边界（风声 5 的普通出口附加费、预约有效期最后一轮、两种特殊出口最高允许风声）。测试通过实际 Run.extract 入口执行，报价前后不变，拒绝后完整 checkpoint 不变，成功时校验独立计算的费用与到账。四酒馆 × 两个预约方案 × 24 个结果共 192 个情境通过；这些样本只贡献 24 个语义命中。

“丢贵重物但紧急出口未知”不作为独立最终结果：有贵重物时 emergency_known 为真；无贵重物时最终原因是“没有可舍弃的贵重物”。源码中的条件存在并不代表可到达一个额外的独立拒绝状态。复杂条件重叠时的优先级仍不等同于本批隔离守卫覆盖。

本批完成初始 pending_families.route_quotes 的拆分；总目录仍因其它状态族未完整枚举而未封板。现在 67 个已登记结果均有当前证据，整体百分比依旧为空。

更新汇总前，先运行新增套件及原两套件，避免目录摘要过期：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/route_guard_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/lifecycle_coverage_test.gd -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/transfer_coverage_test.gd -- --test
python3 Godot/three_d/tests/collect_coverage.py
python3 Godot/three_d/tests/test_collect_coverage.py
```

## 搜索结果与拒绝守卫（2026-09-14）

search.* 新增 20 个结果：物品、路线、现金、付费情报、免费情报、降风声六类成功，以及未知选择、非活动局、活动牌桌、房间未解锁、重复处理、无行动力、现金不足、背包满、路线已知、情报目标桌已完成、情报已知、已经降过风声、无需降风声、旧 revision 十四类拒绝。测试走公开 service_action(search) 入口，先核对查询原因且查询不改变状态；成功用独立预期的完整 checkpoint 对比，拒绝要求完整 checkpoint 不变。消息内容仅要求非空且与领取记录一致，不把文案本身当作经济状态证明。

本套件固定烟雾酒馆和种子 0，以隔离语义结果。它不替代现有 search_events/event_pool 的事件置换、其他物品奖励、存档及物理交互测试，也不声称覆盖所有边界与守卫冲突组合。初始 search 待拆分族已列入目录；其他待拆分族仍保留。

执行 search_coverage_test.gd 以及上述三个覆盖套件，再运行 collect_coverage.py 和 test_collect_coverage.py。本轮四套件全部通过，汇总器 3 个测试通过：87 个登记结果均有当前证据。全局状态转移分母尚未完成，不能据此宣布达到 95% 或完成 Phase 1。

## 入座与抵押守卫（2026-09-14）

entry.* 新增 12 个结果：普通入座、抵押入座，以及旧 revision、未知牌桌、非活动局、已有牌桌、已经完成、房间未解锁、买入不足、不允许抵押、未持有抵押物、抵押物非贵重物十类拒绝。真实 enter_table 入口执行；成功检查现金扣款、风声、金库、revision、抵押物归属、完成记录、行动力与牌桌创建，拒绝检查完整 checkpoint 不变。固定种子 0、烟雾酒馆隔离入口条件；发牌、盲注、RNG 与多酒馆风声边界仍由其他专用测试负责，未在本套件声称完整覆盖。

新增执行 entry_coverage_test.gd 后，重跑四个既有覆盖套件，再运行汇总和汇总器测试。本轮 99 个已登记结果均有当前证据，3 个汇总器测试通过。settle_table 仍明确保留在 pending_families.run_lifecycle，入座通过不能替代结算奖励、抵押归还和重复到账的验证。全局覆盖率仍未计算。

## 结算奖励与抵押归属（2026-09-14）

settlement.* 新增 21 个具名结果：十种奖励选择、保本、亏损、背包满、抵押失去、主池平分归还、只赢边池不归还、旧格式 awards 归还，以及旧 revision、非活动局、无牌桌、未结束牌桌四种拒绝。奖励选择中 antique 同时验证主池胜利后归还抵押。所有成功情境再次调用结算，要求拒绝且完整状态不变；重复调用归入 no_table 守卫，不重复计数。

测试真实入座后注入 finished 结果夹具，再通过 settle_table 执行。这是结算边界测试，不声称这些结果由该套件实际打牌产生。独立断言现金增加量、金库不变、物品列表、奖励结果、风声缓解、完成记录、行动力重置、出口发现和 revision。四种拒绝均比较完整 checkpoint。初始生命周期待拆分项已经枚举，但扑克、服务、世界和持久化仍待完成。

运行 settlement_coverage_test.gd 与五个原覆盖套件后，汇总为 120 个登记结果具备当前证据；汇总器 3 个测试通过。全局分母仍未封板，不能宣布达到 Phase 1 的 95% 门槛。

## 离桌基础服务（2026-09-14）

service.* 新增 21 个结果：购买、出售、喝镇定酒、付费降风声、查明规则五种成功，以及旧 revision、非活动局、道具动作不匹配、活动牌桌、无行动力、未上架、购买现金不足、满背包、出售未持有物、已经降风声、风声为零、没有镇定酒、降风声现金不足、规则已知、未知牌桌、未知动作十六类拒绝。每例先验证 service_reason 与查询无副作用，再通过 service_action 执行。成功用独立现金/物品/风声/规则/行动力/revision 预期对比完整 checkpoint；拒绝要求完整 checkpoint 不变。

本套件固定烟雾酒馆、种子 0、镇定酒交易，分别使用买价 30、卖价 10、降风声费用 24 的独立预期。四酒馆费率、其它物品与货架池组合由专用测试覆盖，不在此扩大宣称。lens/sleeve 与高级道具、预约仍留在 pending_families.services；共享的 mismatch 守卫本例仅用 drink 隔离，不能替代其他动作的专用边界。

运行 service_coverage_test.gd 和六个原覆盖套件后，141 个登记结果均有当前证据，汇总器 3 个测试通过。全局状态转移目录仍未完成，整体覆盖率保持为空。

## 透镜与袖夹（2026-09-14）

tool.* 新增 15 个结果：透镜预览、袖夹换牌、先预览再换牌保留牌堆顶、风声上限四种成功，以及旧 revision、非活动局、道具不匹配、无牌桌、牌桌结束、未持有、本桌已用、河牌无法预览、翻牌后无法换牌、首次行动后无法换牌、非玩家行动无法换牌十一种拒绝。成功验证物品消耗、used_tools、两层 revision、资金与行动力不变、风声、手牌及剩余牌堆；拒绝比较完整 checkpoint。组合用例先真实调用透镜，再调用袖夹，验证抽走的是牌堆倒数第二张且顶部预览保留。

固定烟雾酒馆与首桌；阶段和行动时机的拒绝条件使用隔离夹具。该套件不替代实际打牌推进、跨桌额外风声和存档重放测试。运行 tool_coverage_test.gd 与七个既有覆盖套件，156 个登记结果具备当前证据，汇总器 3 个测试通过。全局目录仍不完整，服务中的高级道具与预约继续保留待办。

## 情报重复消耗修复（2026-09-14）

审查高级服务发现手机可消耗在已知完整情报或已完成的牌桌，笔记可重复消耗在已记录的同一对手。新增 redundant_intel_test.gd：修复前 7 项中 4 项失败（包含第二份笔记被浪费后无法记录另一对手的连带失败），修复后 7 项通过。手机仍允许把“仅规则已知”升级成完整情报，另一位对手仍可消耗第二份笔记记录。新增拒绝理由由现有 service_reason 驱动，拒绝时完整 checkpoint 不变。

routes_items_test.gd 的 54 项通过；规则摘要变化后重跑八个覆盖套件，156 项证据更新有效，汇总器 3 项通过。此次 7 项专用回归没有自动计入语义覆盖目录，高级服务族仍待完整枚举。

## 预约费用与条件快照（2026-09-14）

reservation.* 新增 11 个结果：首次预约、过期重订、手机更新候选后保留原预约，以及旧 revision、非活动局、错误物品、活动牌桌、无行动力、接应未知、已有有效预约、预付款不足八类拒绝。四酒馆 × 两个方案 × 十一个结果共 88 个情境，计 11 个具名结果。成功预约用独立公式构造完整预期 checkpoint，验证预付折扣/最低费用、尾款快照、有效期、行动力与 revision；过期重订照常再次付费。手机更新仅改变候选，原预约与撤离报价尾款保留；拒绝比较完整 checkpoint。

本轮 reservation_coverage_test.gd 与八个原覆盖套件通过，167 个登记结果证据有效，汇总器 3 个测试通过。phone-route 的无预约状态及其他高级物品仍待枚举，故不从服务待办中移除 phone-route。全局目录未封板，不报告全局覆盖百分比。

## 高级道具入口与拒绝结果（2026-09-14）

advanced.* 新增 26 个结果：手机更新候选、完整情报、新增规则基础上的完整情报、两种通行证、对手笔记、已弃牌对手笔记、信号八种成功，以及非活动、未持有、道具不匹配、活动牌桌、无行动力、未知/已完成/已知情报牌桌、非通行证、路线已知、无牌桌、已结束牌桌、未知/自己/已弃牌信号目标、信号已用、笔记已知、旧 revision 十八类拒绝。成功构造完整 checkpoint 预期，包含牌桌 revision，但牌堆、手牌与 RNG 应不变；拒绝要求完整状态不变。

信号成功仅检查三档格式、物品和风声消耗、不泄露底牌；其强/中/弱阈值及有效对手计数新增为 pending_families.signal_analysis，尚未证明。初始 services 入口已拆分，不能将它误读成全部服务内部计算已经覆盖。固定烟雾酒馆与首桌的用例也不代表全部多酒馆组合。

本轮 advanced_coverage_test.gd 与九个原覆盖套件通过，193 个登记结果具备当前证据，汇总器 3 个测试通过。扑克、世界、持久化和信号分析仍待完成，全局分母未封板。

## 非正式动作名跳过扣款修复（2026-09-14）

审查 Table.act 发现 legal_actions 的 UI 字段 allIn 可被当作命令名传入：合法性检查为真，但执行分支只识别 all-in，造成不扣筹码仍推进 turnCounter、revision 和队列。入口现限定 fold/check/call/raise/all-in 五种正式命令。action_name_test.gd 在四桌分别验证 allIn、空值、未知值及大写值拒绝且完整牌桌快照不变，并验证正式 all-in 将全部筹码加入底池。修复前 20 项有 4 项失败，修复后全部通过。

table_test.gd 1879 项、table_checkpoint_test.gd 2021 项通过。规则摘要变化后十个覆盖套件重跑，193 个登记结果证据有效，汇总器 3 项通过。新增专用回归尚未转换为扑克语义目录命中，扑克族继续保留待办。
