# 16 条路线参考图筛查

2026-09-29。逐张查看 `assets/scene-plates/` 中四店各四张路线图，并对照 `Godot/three_d/rules/content.json` 的当前 16 条路线。下表评估的是**建模概念适配度**，不是图片授权或可发行性；图内文字、人物和装置不可直接复制为游戏贴图。路线 ID/名称以 `content.json` 为准，旧图片文件名不修改玩法。

| 酒馆 | 当前路线 ID 与名称 | 可参考的现有图 | 筛查结论 |
|---|---|---|---|
| 烟雾酒馆 | `kitchen-backlift` 后厨货梯接应 | `tavern-smoky-den-route-kitchen-backlift-bg.png` | 部分匹配：厨房瓷砖、蒸汽、服务门可借鉴；图内未明确货梯，需在模型中补实体货梯和接应位置 |
| 烟雾酒馆 | `linen-cart` 布草车接应 | 无专门图 | 缺直接参考；可沿用同店后厨服务通道的材料语言，布草车需单独设计 |
| 烟雾酒馆 | `service-stairs` 后厨楼梯 | 后厨货梯图仅供材料；`tavern-smoky-den-route-tunnel-bg.png` 仅供阴暗通道氛围 | 缺楼梯直接参考；必须遵循现有上行台阶与平台的交互位置 |
| 烟雾酒馆 | `river-launch` 河边接驳 | 无专门图 | 缺码头直接参考；保持现有下行坡道、水边平台和可达出口 |
| 高层套房 | `vip-elevator` 贵宾电梯 | `tavern-smoky-den-route-vip-elevator-bg.png` | 概念匹配但归档在烟雾酒馆、装饰语言偏复古；应按套房石材/金属/冷夜窗景重新设计，不能直接共用原布景 |
| 高层套房 | `laundry-trolley` 洗衣推车 | 无专门图 | 缺直接参考；服务走廊与推车需能和贵宾电梯形成视觉反差 |
| 高层套房 | `service-stairs` 维修电梯 | `tavern-high-rise-suite-route-service-elevator-bg.png` | 基本匹配：设备电梯、磨损金属和冷白灯；仍要核对模型与目前上行翼拓扑的关系 |
| 高层套房 | `river-launch` 地下车库 | `tavern-high-rise-suite-route-basement-bg.png` | 部分匹配：地下管线走廊；图内没有车库、车或接应点，需补终点空间 |
| 屋顶会所 | `staff-door` 员工通道 | `tavern-rooftop-club-route-staff-door-bg.png` | 部分匹配：后勤门与前台区；图片是白天办公楼大厅，与同晚屋顶会所氛围冲突，须转为夜景并避免复制公共大厅 |
| 屋顶会所 | `valet-loop` 代客泊车接应 | `tavern-rooftop-club-route-valet-bg.png` | 基本匹配：夜间车、代客泊车与露台结构；动线需落到可达接应位置 |
| 屋顶会所 | `service-stairs` 消防楼梯 | `tavern-rooftop-club-route-emergency-exit-bg.png` | 部分匹配：屋顶消防门、梯笼和湿地；图片不展示内部楼梯，需补阶梯及上下层关系 |
| 屋顶会所 | `river-launch` 停机坪接应 | `tavern-high-rise-suite-route-heliport-bg.png` | 概念匹配但图归档在高层套房且为黄昏；可借鉴停机坪结构，改为同一晚的夜间城市环境 |
| 霓虹扑克俱乐部 | `data-node-gate` 数据节点闸门 | `tavern-neon-poker-club-route-data-node-bg.png` | 部分匹配：发光节点与门禁语言；图中光圈/武装人物不能替代「闸门」的实体路线，需保留可识别门框和交互点 |
| 霓虹扑克俱乐部 | `hack-door` 伪装员工门禁 | `tavern-neon-poker-club-route-hack-door-bg.png` | 部分匹配：门禁、屏幕与线路；必须让玩家清楚看出是员工门，而非另一座保险库 |
| 霓虹扑克俱乐部 | `service-stairs` 传感器盲区走廊 | 无直接走廊图；`tavern-neon-poker-club-route-neural-jammer-bg.png` 只有色光参考 | 缺直接参考；用局部失效传感器、遮蔽带和可走廊道表达，不能用传送门替代 |
| 霓虹扑克俱乐部 | `river-launch` 后台传送门 | `tavern-neon-poker-club-route-neural-jammer-bg.png` 的发光环；`tavern-neon-poker-club-route-quantum-portal-bg.png` 的数据氛围 | 规则**确有传送门**，不能在美术阶段擅自删去；两张图都只有概念氛围，实际模型仍须匹配当前下行翼和出口交互 |

另有 `tavern-smoky-den-route-old-friend-bg.png`、`tavern-rooftop-club-route-parachute-bg.png`、`tavern-high-rise-suite-route-fake-id-bg.png` 等旧图，内容分别是白天接应人、黄昏跳伞、白天办公楼。它们与当前 16 条路线没有一对一 ID，**不得把它们当作待新增玩法或建模清单**。烟雾酒馆的 `vip-elevator` 图和高层套房的 `heliport` 图可跨目录作为概念参考，但当前归档位置与实际配置不一致；制作时以表中路线 ID 为准。

此筛查显示 `linen-cart`、`river-launch`（烟雾酒馆）、`laundry-trolley`、霓虹俱乐部传感器盲区走廊等缺直接参考。先用现有建筑源和 `content.json` 设计实体空间；若高级模型判断必须新增参考图，应逐件说明缺口、为何现有图不够、生成用途与预期数量，获得健哥确认后才调用 image2.5。当前没有生成任何新图。
