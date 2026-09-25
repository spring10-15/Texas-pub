# Content-Map: 游戏内容与场景对应关系

## 范围与方法

本文件以 `src/data.js`、`src/game.js`、`src/main.js`、场景渲染函数及 `assets/videos/manifest.json` 为唯一证据源，整理游戏当前代码中实际存在的内容映射。所有条目均标注代码位置，无法确认的条目标记为"待确认"，不混入已验证内容。

---

## 1. 酒馆表

| ID | name (英文) | BGM (文件名) | bgImage (场景图) | uiTone | atmosphere | heatReductionCost | generalExtractionFlatFee | generalExtractionRate | lockdownSurcharge | entryHeatBonus | intelBonus | forcedExitLossFactor | hiddenRouteRevealDiscount | 专属路线数 | 证据位置 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| smoky-den | Smoky Den | tavern-floor.ogg | tavern-smoky-den-bg.png | warm | A dimly lit den filled with smoke and the sound of chips clinking. | 24 | 24 | 0.12 | 45 | 0 | 0 | 0.75 | 0 | 4 (2固定+2特殊) | `src/data.js:33-50` TAVERN_SCENES["smoky-den"] |
| high-rise-suite | High-Rise Suite | tavern-high-rise-suite.ogg | tavern-high-rise-suite-bg.png | cool | A private suite above the city where money talks softly and pressure lingers. | 36 | 42 | 0.18 | 70 | 0 | 0 | 0.88 | 0 | 4 (2固定+2特殊) | `src/data.js:51-68` TAVERN_SCENES["high-rise-suite"] |
| rooftop-club | Rooftop Club | tavern-rooftop-club.ogg | tavern-rooftop-club-bg.png | good | A social rooftop game where style, risk, and noise blur together. | 30 | 28 | 0.13 | 60 | 1 | 0 | 0.68 | 5 | 4 (2固定+2特殊) | `src/data.js:69-86` TAVERN_SCENES["rooftop-club"] |
| neon-poker-club | Neon Poker Club | tavern-neon-poker-club.ogg | tavern-neon-poker-club-bg.png | warn | A synthetic late-night club where reads feel digital and every move leaves a trace. | 30 | 34 | 0.14 | 55 | 0 | 1 | 0.72 | 10 | 4 (2固定+2特殊) | `src/data.js:87-104` TAVERN_SCENES["neon-poker-club"] |

**BGM 映射说明**：主菜单 BGM 为 `menu-theme.ogg`（非酒馆专属）。进入酒馆后根据 tavernSceneId 切换对应 BGM（`tavern-smoky-den`、`tavern-high-rise-suite`、`tavern-rooftop-club`、`tavern-neon-poker-club`），离开酒馆后切 `table-pressure.ogg`。证据：`src/main.js:54-65` BGM_TRACKS。

**视频背景**：4 个酒馆均有对应视频背景（`tavern-smoky-den-bg.mp4`、`tavern-high-rise-suite-bg.mp4`、`tavern-rooftop-club-bg.mp4`、`tavern-neon-poker-club-bg.mp4`），证据：`assets/videos/manifest.json:3-21`。

---

## 2. 牌桌表

| ID | name | role | buyIn | risk | heatGain | smallBlind | openBet | raiseIncrement | hands | unlocksAfter | opponentIds | publicInfo | hiddenInfo | 特殊规则 | 证据位置 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cargo-table | Cargo Table | Onboarding, first profit, first meaningful read | 60 | Low | 1 | 10 | 20 | 20 | 2 | null | dock-braggart, ledger-clerk | buyIn:60, risk:Low | 首个激进行动便宜10 | firstAggressionDiscount:10 | `src/data.js:110-135` TABLES["cargo-table"] |
| ledger-cellar | Ledger Cellar | Mid-stakes pressure room with quieter opponents and tighter reads | 90 | Medium | 1 | 15 | 30 | 30 | 2 | cargo-table | river-shark, velvet-rook | buyIn:90, risk:Medium | 每次使用牌桌工具额外+1热度 | tableToolHeatBonus:1 | `src/data.js:136-161` TABLES["ledger-cellar"] |
| mirror-hall | Mirror Hall | Main risk-reward table for the slice | 120 | Medium-High | 2 | 20 | 40 | 40 | 3 | ledger-cellar | calm-widow, smiling-knife | buyIn:120, risk:Medium-High | 抵押物规则：最终手胜利解锁最佳奖励 | allowCollateral:true | `src/data.js:162-187` TABLES["mirror-hall"] |
| embers-table | Embers Table | Late-run high stakes room where collateral and exposed goods both matter | 160 | High | 2 | 25 | 50 | 50 | 3 | mirror-hall | house-viper, ash-smuggler | buyIn:160, risk:High | 盈利收桌结算前降1热度 | allowCollateral:true, winHeatRelief:1 | `src/data.js:188-215` TABLES["embers-table"] |

**解锁顺序**：`cargo-table`(null) → `ledger-cellar`(cargo-table) → `mirror-hall`(ledger-cellar) → `embers-table`(mirror-hall)。证据：`src/data.js:19` RUN_STRUCTURE.demoTablePath 及各 table 的 unlocksAfter 字段。

**全部 4 张牌桌均支持 all-in**：代码中 `player-raise-to` dispatch 可触发 all-in（当 stack 不足支付 raise 时自动降级为 all-in，`src/game.js:1524-1549`），AI 决策中也包含 all-in 选项（`src/ai.js:31-71`）。`verify_full_game_flow.mjs:631` 存在"all-in commits the full stack"场景。

---

## 3. 对手表

| ID | name | seatLabel | archetype | intro | profile (aggression/caution/bluff/finalHandSpike/patternPunish) | 所属牌桌 | 角色立绘? | 证据位置 |
|---|---|---|---|---|---|---|---|---|
| dock-braggart | Dock Braggart | Dock Braggart | Maniac | Too loud for the cards he is actually holding. | 0.76/0.18/0.24/0.02/0.0 | cargo-table | **未发现角色立绘** | `src/data.js:218-231` OPPONENTS["dock-braggart"] |
| ledger-clerk | Ledger Clerk | Ledger Clerk | Nit | Counts the room twice before he risks one chip. | 0.28/0.74/0.05/0.0/0.0 | cargo-table | **未发现角色立绘** | `src/data.js:232-245` OPPONENTS["ledger-clerk"] |
| river-shark | River Shark | River Shark | Shark | Looks passive until the pot starts smelling like a sure thing. | 0.5/0.42/0.09/0.06/0.05 | ledger-cellar | **未发现角色立绘** | `src/data.js:274-287` OPPONENTS["river-shark"] |
| velvet-rook | Velvet Rook | Velvet Rook | Calling Station | Protects small edges and only turns sharp once the room gets narrow. | 0.34/0.6/0.1/0.05/0.07 | ledger-cellar | **未发现角色立绘** | `src/data.js:288-301` OPPONENTS["velvet-rook"] |
| calm-widow | Calm Widow | Calm Widow | Shark | Patient, precise, and excellent at noticing repetition. | 0.48/0.62/0.08/0.12/0.18 | mirror-hall | **未发现角色立绘** | `src/data.js:246-259` OPPONENTS["calm-widow"] |
| smiling-knife | Smiling Knife | Smiling Knife | Shark | Coasts early, then leans on the table when the pot matters. | 0.5/0.42/0.12/0.24/0.06 | mirror-hall | **未发现角色立绘** | `src/data.js:260-273` OPPONENTS["smiling-knife"] |
| house-viper | House Viper | House Viper | Shark | Never looks rushed, but the room tightens when he finally presses. | 0.51/0.5/0.08/0.11/0.08 | embers-table | **未发现角色立绘** | `src/data.js:302-315` OPPONENTS["house-viper"] |
| ash-smuggler | Ash Smuggler | Ash Smuggler | Fish | Hides under smoke and only shows teeth when the line looks soft. | 0.42/0.46/0.15/0.07/0.06 | embers-table | **未发现角色立绘** | `src/data.js:316-329` OPPONENTS["ash-smuggler"] |

**archetype 字段存在于 OPPONENTS 字典中**，无需推测。`patternPunish` 字段控制 AI 对玩家模式重复行为的反制力度，`finalHandSpike` 控制终局手加压力度。

**角色立绘状态**：搜索 `assets/scene-plates/`、`Godot/`、`output/` 均未发现任何对手角色立绘 PNG/JPG。`output/cargo-opponents-pass4.png` 经查为组合式 UI 截图，非角色立绘。当前浏览器版使用文字标签（`seatLabel`）和性格参数，无独立角色模型。**建议 3D 阶段优先确认是否需要角色立绘模型**。

---

## 4. 物品表

共 **19 项**（9 usable + 10 valuable）——与参考值一致。

### 4a. Usable 物品（9项）

| ID | name | kind | phase | buy | sell | slots | heat | value | collateral | unlockRoute | description | 建议3D模型独立性 | 证据位置 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| marked-lens | Marked Lens | usable | table | 40 | 20 | 1 | 1 | — | — | — | Peek one unrevealed community card once per table. | **建议独立**：桌面透视/读牌类道具，有独特使用动画 | `src/data.js:333-343` |
| signal-lighter | Signal Lighter | usable | table | 35 | 15 | 1 | 0 | — | — | — | Read one opponent's current hand pressure as weak/medium/strong. | **建议独立**：桌面读人道具 | `src/data.js:344-354` |
| player-notes | Player Notes | usable | table | 50 | 25 | 1 | 0 | — | — | — | Reveal one opponent's playing style archetype. (phase:table，用于揭示对手性格标签) | **建议独立**：情报类道具 | `src/data.js:355-365` |
| steadying-drink | Steadying Drink | usable | search | 30 | 10 | 1 | 0 | — | — | — | Reduce heat by 1 in the search phase. | **建议独立**：降热度消耗品 | `src/data.js:366-376` |
| disposable-phone | Disposable Phone | usable | search | 50 | 20 | 1 | 0 | — | — | — | Reveal every hidden layer of one table or refresh the fixed route offer. | **建议独立**：情报刷新道具 | `src/data.js:377-387` |
| kitchen-pass | Kitchen Pass | usable | search | 45 | 20 | 1 | 0 | — | — | **service-stairs** | Flash it upstairs to reveal the service stairs extraction line. | **建议独立**：解锁隐藏路线的关键道具 | `src/data.js:388-399` |
| dock-passkey | Dock Passkey | usable | search | 55 | 25 | 1 | 0 | — | — | **river-launch** | Signals a hidden river launch route that never appears on the public board. | **建议独立**：解锁隐藏路线关键道具 | `src/data.js:400-411` |
| false-bottom-wallet | False-Bottom Wallet | usable | passive | 70 | 30 | 1 | 0 | — | — | — | On run failure, preserve the first 80 cash. | **建议独立**：被动生效，道具本身需要存在感 | `src/data.js:412-422` |
| sleeve-clip | Sleeve Clip | usable | table | 80 | 30 | 1 | 2 | — | — | — | Replace one hole card before the first betting decision of a hand. | **建议独立**：桌面换牌工具 | `src/data.js:423-433` |

### 4b. Valuable 物品（10项）

| ID | name | kind | phase | buy | sell | slots | heat | value | collateral | unlockRoute | description | 建议3D模型独立性 | 证据位置 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| old-silver-lighter | Old Silver Lighter | valuable | — | — | — | 1 | — | 45 | true | — | A low-tier trophy that still moves well in the back room. | **建议独立**：小型摆件，1格 | `src/data.js:434-442` |
| ivory-chip | Ivory Chip | valuable | — | — | — | 1 | — | 60 | true | — | The cargo floor's favorite marker. Modest value, sharp symbolism. | **建议独立**：筹码类，1格 | `src/data.js:443-451` |
| ruby-cufflink | Ruby Cufflink | valuable | — | — | — | 1 | — | 90 | true | — | A neat mid-tier pawn piece that still feels painful to lose. | **建议独立**：首饰类，1格 | `src/data.js:452-460` |
| pearl-necklace | Pearl Necklace | valuable | — | — | — | 1 | — | 95 | true | — | A graceful luxury piece that pawns cleanly in the right room. | **建议独立**：项链类，1格 | `src/data.js:488-496` |
| emerald-brooch | Emerald Brooch | valuable | — | — | — | 1 | — | 125 | true | — | A rich green piece that holds its nerve as collateral. | **建议独立**：胸针类，1格 | `src/data.js:497-505` |
| gold-cased-watch | Gold-Cased Watch | valuable | — | — | — | 1 | — | 120 | true | — | A stable high-value carry with no special trigger attached. | **建议独立**：手表类，1格 | `src/data.js:461-469` |
| antique-coin | Antique Commemorative Coin | valuable | — | — | — | 1 | — | 140 | true | — | Mirror Hall's signature take-home reward. | **建议独立**：硬币/徽章类，1格 | `src/data.js:470-478` |
| sealed-bond | Sealed Bond | valuable | — | — | — | 2 | — | 180 | true | — | A bulky paper prize that pays well if you can carry it out. | **建议独立**：纸质文件，占2格，体积感 | `src/data.js:479-487` |
| obsidian-idol | Obsidian Idol | valuable | — | — | — | 2 | — | 150 | true | — | Heavy, awkward, and worth real money if you can still walk with it. | **建议独立**：雕像类，占2格，笨重感 | `src/data.js:506-514` |
| vault-promissory | Vault Promissory | valuable | — | — | — | 2 | — | 210 | true | — | A private-room paper that lenders will honor if the room believes you survived. | **建议独立**：纸质证券，占2格 | `src/data.js:515-524` |

**注**：`kitchen-pass` 的 `unlockRoute: "service-stairs"` 和 `dock-passkey` 的 `unlockRoute: "river-launch"` 字段表明这两个道具分别揭示两个不同的隐藏路线（各酒馆均有一套 service-stairs 和一套 river-launch，内容各异）。`player-notes` 的 `phase: table` 且描述为"reveal opponent archetype"，说明它在桌面阶段揭示对手性格分类。

---

## 5. 路线表

### 5a. Smoky Den 路线

| 配置键 (specialRoutes key) | 实际 route.id | name | reserveCost | finalCost | maxHeat | flavor | 参考图 (scene-plates) | 映射疑点 |
|---|---|---|---|---|---|---|---|---|
| (fixed) | kitchen-backlift | Kitchen Backlift | 50 | 10 | 4 | A flour-dusted runner opens the service gate for one clean exit. | `tavern-smoky-den-route-kitchen-backlift-bg.png` | 无 |
| (fixed) | linen-cart | Linen Cart | 50 | 10 | 4 | You leave under folded cloth, if the hallway still belongs to the staff. | 未发现精确匹配图 | 旧图存在 `old-friend`、`tunnel` 图片，命名与代码不符 |
| service-stairs | service-stairs | Service Stairs | — | 25 | 5 | A kitchen runner holds the stairwell open long enough for a clean exit if you move quickly. | 未发现 | 配置键==实际id，但无独立图片 |
| river-launch | river-launch | River Launch | — | 40 | 4 | A silent launch waits below the loading docks, but only for someone already holding the right key. | 未发现 | 配置键==实际id，但无独立图片 |

### 5b. High-Rise Suite 路线

| 配置键 (specialRoutes key) | 实际 route.id | name | reserveCost | finalCost | maxHeat | flavor | 参考图 (scene-plates) | 映射疑点 |
|---|---|---|---|---|---|---|---|---|
| (fixed) | vip-elevator | VIP Elevator | 60 | 20 | 4 | A concierge keeps the service elevator unlocked for one exact descent. | `tavern-smoky-den-route-vip-elevator-bg.png` | **图片文件名错误**：存放在 smoky-den 目录下但内容是 high-rise 的路线 |
| (fixed) | laundry-trolley | Laundry Trolley | 55 | 15 | 4 | You disappear with pressed linens and a bored porter who never asks names. | 未发现精确匹配图 | 旧图存在 `fake-id` 图片，命名与代码不符 |
| service-stairs | service-elevator | Service Elevator | — | 30 | 5 | The maintenance shaft only stays open if the kitchen stamp is real. | `tavern-high-rise-suite-route-service-elevator-bg.png` | 配置键 `service-stairs` ≠ 实际 id `service-elevator` |
| river-launch | basement-garage | Basement Garage | — | 45 | 4 | A quiet car waits under the tower, but only for someone carrying the right coded key. | `tavern-high-rise-suite-route-basement-bg.png` | 配置键 `river-launch` ≠ 实际 id `basement-garage` |

### 5c. Rooftop Club 路线

| 配置键 (specialRoutes key) | 实际 route.id | name | reserveCost | finalCost | maxHeat | flavor | 参考图 (scene-plates) | 映射疑点 |
|---|---|---|---|---|---|---|---|---|
| (fixed) | staff-door | Staff Door | 45 | 15 | 4 | A bartender palms you a staff badge and points to the back stairs. | `tavern-rooftop-club-route-staff-door-bg.png` | 无 |
| (fixed) | valet-loop | Valet Loop | 55 | 20 | 4 | The valet stand folds you into the traffic before the rooftop buzz catches up. | `tavern-rooftop-club-route-valet-bg.png` | 无 |
| service-stairs | emergency-exit | Emergency Exit | — | 20 | 5 | A fire stair hidden behind the bottle wall opens only if the stamped pass checks out. | `tavern-rooftop-club-route-emergency-exit-bg.png` | 配置键 `service-stairs` ≠ 实际 id `emergency-exit` |
| river-launch | helipad-drop | Helipad Drop | — | 50 | 4 | A charter pilot takes you off the roof if the access chip still reads green. | `tavern-rooftop-club-route-heliport-bg.png` | 屋顶撤离路线没有专属 heliport/helipad 图片（rooftop-club-route-heliport-bg.png 不存在）；仅 high-rise-suite-route-heliport-bg.png 存在，作为其他酒馆的视觉类比参考，不要把它当作屋顶路线的绑定参考。配置键 `river-launch` ≠ 实际 id `helipad-drop` |

### 5d. Neon Poker Club 路线

| 配置键 (specialRoutes key) | 实际 route.id | name | reserveCost | finalCost | maxHeat | flavor | 参考图 (scene-plates) | 映射疑点 |
|---|---|---|---|---|---|---|---|---|
| (fixed) | data-node-gate | Data Node Gate | 50 | 20 | 4 | A coded maintenance gate blinks open for one clean exit window. | `tavern-neon-poker-club-route-data-node-bg.png` | 无 |
| (fixed) | hack-door | Hack Door | 60 | 25 | 4 | A spoofed employee route gives you twenty seconds before the club catches up. | `tavern-neon-poker-club-route-hack-door-bg.png` | 无 |
| service-stairs | neural-jammer | Neural Jammer Corridor | — | 30 | 5 | A dead sensor lane appears only when the right utility token trips the jammer. | `tavern-neon-poker-club-route-neural-jammer-bg.png` | 配置键 `service-stairs` ≠ 实际 id `neural-jammer` |
| river-launch | quantum-portal | Quantum Portal | — | 55 | 4 | The back-end portal only resolves for runners carrying a synced dock key. | `tavern-neon-poker-club-route-quantum-portal-bg.png` | 配置键 `river-launch` ≠ 实际 id `quantum-portal` |

### 5e. 通用撤离表

| key | name | 触发条件 | 费用 | 牺牲 | maxHeat | 说明 | 证据位置 |
|---|---|---|---|---|---|---|---|
| general | Taxed Walkout (通用撤离) | run.routeIntel.publicExit && heat < 6 | flatFee + cash×rate；heat=5时另加 lockdownSurcharge | 无 | 5 | 酒馆各有不同费率（见酒馆表）；公开路线 | `src/game.js:981-1000` attemptExtraction("general") |
| fixed | Runner Hand-Off (预定撤离) | run.routeIntel.fixedWhisper && 有预约且未过期 && heat ≤ maxHeat | 需先在 search 阶段预约并支付 reserveCost（src/game.js:838），撤离时再支付 finalCost（src/game.js:1024）。两次独立扣除现金，不互相抵扣。 | 无 | 4 | 需提前在搜索阶段预约并支付 reserveCost | `src/game.js:1001-1025` attemptExtraction("fixed") |
| dropbag-cash | Break Glass Exit / Cash (紧急撤离/丢现金) | run.routeIntel.emergency && 现金充足 | 10 | 40%现金 | 6 | 牺牲后剩余现金减 10； guaranteed success | `src/game.js:1026-1039` attemptExtraction("dropbag-cash") |
| dropbag-valuables | Break Glass Exit / Goods (紧急撤离/丢货) | run.routeIntel.emergency && 有贵重物 | 10 | 丢失全部贵重物 | 6 | 触发后贵重物清空； guaranteed success | `src/game.js:1040-1057` attemptExtraction("dropbag-valuables") |

**通用撤离图片引用**：通用路线图（route-general / route-fixed / route-dropbag-cash / route-dropbag-valuables）已通过 `scenes/extraction/style.css:166` 起与 `scenes/extraction/index.js:190` 起的 `routeClass` 字典在 DOM 中引用，作为路线卡的背景图。引用不等于已实跑。

---

## 6. 疑点与待确认事项

### 6.1 配置键 vs 实际 route.id 差异（关键）

| 酒馆 | 路线类型 | 配置键 (TAVERN_ROUTE_SETS[tavern].specialRoutes[*].id) | 实际 route.id | 差异影响 |
|---|---|---|---|
| high-rise-suite | service-stairs | `service-stairs` | `service-elevator` | dispatch key 和 route.id 不一致，需同时记录两者 |
| high-rise-suite | river-launch | `river-launch` | `basement-garage` | 同上 |
| rooftop-club | service-stairs | `service-stairs` | `emergency-exit` | 同上 |
| rooftop-club | river-launch | `river-launch` | `helipad-drop` | 同上；图片名为 `heliport` |
| neon-poker-club | service-stairs | `service-stairs` | `neural-jammer` | 同上 |
| neon-poker-club | river-launch | `river-launch` | `quantum-portal` | 同上 |

**smoky-den 例外**：配置键与实际 id 完全一致（均为 `service-stairs`、`river-launch`），无差异。

`src/game.js:1058-1075` 中 `attemptExtraction` 以 `type === "service-stairs" || type === "river-launch"` 直接 dispatch，路由逻辑依赖配置键（因为 specialRoutes 字典的 key 就是配置键），而提取展示使用 `routeName(route)` 即实际 id。**3D 制作需确认路线 ID 系统是否需要统一**。

### 6.2 与设计基线文档的过时描述冲突

1. **"Cargo Table and Mirror Hall are the current demo rooms"**（design-baseline.md 第226行）
   - 实际情况：`src/data.js:19` 定义 `demoTablePath: ["cargo-table","ledger-cellar","mirror-hall","embers-table"]`，共 4 张牌桌
   - design-baseline.md 只记录了前两张的详细信息（Table 1: Cargo Table, Table 2: Mirror Hall）
   - ledger-cellar 和 embers-table 在 design-baseline 中**无描述**
   - **影响**：设计文档严重过时，无法作为 3D 场景规划依据

2. **"Vertical slice does not support all-in actions"**（design-baseline.md 第288行）
   - 实际情况：`src/game.js:1268-1269`（legalActions 包含 `allIn`）、`src/game.js:1524-1549`（all-in 降级逻辑）、`src/ai.js:31-71`（AI all-in 决策）、`verify_full_game_flow.mjs:631`（all-in 测试场景）均证明 **all-in 已实现**
   - **影响**：设计文档中 all-in 规则描述不准确

### 6.3 场景图片命名与代码路由不匹配

`assets/scene-plates/` 中以下图片**无法确认对应代码路由**，可能为旧命名或废弃素材：
- `tavern-smoky-den-route-old-friend-bg.png` — 无对应代码路由
- `tavern-smoky-den-route-tunnel-bg.png` — 无对应代码路由
- `tavern-rooftop-club-route-parachute-bg.png` — 无对应代码路由（`helipad-drop` 对应 `route-heliport-bg.png`）
- `tavern-high-rise-suite-route-fake-id-bg.png` — 无对应代码路由

`tavern-smoky-den-route-vip-elevator-bg.png` 存放在 smoky-den 目录下，但 VIP Elevator 属于 high-rise-suite（代码证据：`src/data.js:607-612`）。**图片归属可能混乱**。

### 6.4 Grep 到但未在浏览器验证的功能（Found logic ≠ Tested）

- **all-in 完整流程**：代码中有完整逻辑，但 `verify_full_game_flow.mjs` 仅验证了 all-in 提交和记录，未验证 all-in 后手牌结算和 side-pot 逻辑
- **patternPunish AI 反制**：代码中已确认接入 —— `src/ai.js:12` 用于计算 patternPressure，`src/ai.js:125` 在 Shark archetype 调整其值。是否需要调优属主 Agent 决定；未经浏览器实测不同对手类型的实际反制强度。
- **tableToolHeatBonus（ledger-cellar +1 热）**：代码存在（`src/data.js:158`），但 `applyTableToolHeat` 函数（`src/game.js:2717-2724`）使用 `table.tableDef.tableToolHeatBonus ?? 0`，逻辑存在，**未在浏览器完整验证**
- **winHeatRelief（embers-table 盈利降 1 热）**：代码存在（`src/data.js:211`），调用点在 `src/game.js:1914-1919`，**未在浏览器完整验证**

### 6.5 缺失的角色立绘与道具模型

- **对手角色立绘**：全部 8 位对手**均无独立角色立绘文件**。搜索范围包括 `assets/scene-plates/`、`Godot/`、`output/`，未发现任何 opponent portrait PNG/JPG。当前浏览器版使用文字标签。**3D 阶段需确认是否需要 3D 角色模型或 2D 立绘**。
- **3D 道具模型**：所有 19 项物品目前无独立 3D 模型文件（`.glb`/`.gltf`）。valuables 的 `slots` 字段（1 或 2）表示占用格数，对应背包 UI。**3D 阶段需按 `src/data.js` ITEM_DEFS 逐项制作**。

### 6.6 其他映射疑点

- **routeIntel 条件触发**：4 个酒馆共用同一套 routeIntel 键（`publicExit`、`fixedWhisper`、`emergency`、`serviceStairs`、`riverLaunch`），但不同酒馆的 specialRoutes 内容完全不同。玩家在进入酒馆后通过完成牌桌、打出特定道具等方式触发路线可见性。**3D 制作需确认路线触发是否按酒馆隔离**。
- **Intel Bonus 字段**：neon-poker-club 的 `intelBonus: 1`，代码中未找到实际使用点（`getRunSceneDef` 等函数返回该字段但无消耗逻辑）。**待确认为遗留字段还是未实现功能**。
