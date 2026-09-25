# 《德扑酒馆》3D 制作 · 资料整理交付摘要

> 本目录是 3D 制作的前期资料整理结果，**不修改**任何源代码、场景、Godot 文件或原始素材。所有结论以代码、配置或本地 README/LICENSE 为唯一证据，证据不足或冲突时一律标注"待确认"。

## 一、扫描范围

### 已扫描

- **项目根目录**：`README.md`、`docs/3d-production/协作Agent任务书.md`
- **代码与数据**：`src/data.js`（TAVERN_SCENES / TABLES / OPPONENTS / ITEM_DEFS / TAVERN_ROUTE_SETS）、`src/game.js`、`src/main.js`、`scenes/*/index.js`
- **资源目录**：`assets/scene-plates/`、`assets/videos/`、`assets/blender/`、`assets/audio/bgm/`、`assets/cards/`
- **原型归档**：`Godot/`（含 `Godot/Cards/`、`Godot/three_d/`、`Godot/素材/`、`Godot/德扑牌桌场景/`）
- **样式**：仅查 `styles/foundation.css` 中字体声明（23–25 行）

### 未扫描 / 未深读

- `src/main.js`（4863 行）和 `src/game.js`（2977 行）仅按需抽样，重点引用 `data.js` 与场景层；未覆盖全部业务逻辑分支。
- `assets/blender/stash-noir/` 仅核实存在、说明与导出元数据，未读取 `.blend` 内部对象树。
- `output/`、`archive/` 仅按文件名识别，未纳入正式素材清单。
- `styles/foundation.css`（106 KB）仅看字体段；未审查整份样式。
- `scripts/verify_*.mjs` 仅用作功能存在性参考，未做完整路径覆盖。
- 全部 BGM、视频、场景图、衍生牌面 PNG 的实际作者与许可证信息（项目内无证据）。

## 二、内容数量（与代码核对）

| 维度 | 参考值 | 实测（src/data.js） | 状态 |
|---|---|---|---|
| 酒馆场景 | 4 | 4（smoky-den / high-rise-suite / rooftop-club / neon-poker-club，`src/data.js:33-104`） | ✅ 一致 |
| 牌桌关卡 | 4 | 4（cargo-table / ledger-cellar / mirror-hall / embers-table，`src/data.js:19,109-215`） | ✅ 一致 |
| 对手 | 8 | 8（cargo-table 2 / ledger-cellar 2 / mirror-hall 2 / embers-table 2，`src/data.js:217-329`） | ✅ 一致 |
| 物品 | 19（9 usable + 10 valuable） | 19（ITEM_DEFS 共 19 项；`src/data.js:332-524`） | ✅ 一致 |
| 酒馆专属撤离路线 | 16（4 酒馆 × 4 路线） | 16（每酒馆 2 fixed + 2 special，`src/data.js:565-718`） | ✅ 一致 |
| 通用撤离 | 4 类 | 4 类（general / fixed / dropbag-cash / dropbag-valuables，`src/game.js:981-1057`） | ✅ 一致 |

## 三、五份交付文件用途

| 文件 | 用途 | 主要读者 |
|---|---|---|
| `README.md`（本文件） | 交付摘要、范围、数量、缺失与待确认事项集中列表 | 主 Agent（健哥指定的另一个 Agent） |
| `assets.csv` | 40 条素材清点（SP-21 / VD-8 / BL-1 / GD-10），含路径、尺寸、引用证据、3D 参考价值 | 建模 Agent |
| `content-map.md` | 4 酒馆 / 4 牌桌 / 8 对手 / 19 物品 / 16 路线 + 4 通用撤离的代码对应关系；含疑点 6 节 | 开发 / 关卡设计 Agent |
| `licenses.md` | 6 类素材的本地证据（扑克牌 / 字体 / 模型 / 音频 / 视频 / 插画）；仅 2 类确认 | 主 Agent / 法务 / 发行 |
| `acceptance-checklist.md` | 183 条 QA 检查项（22 类，含 13 条 AC-PHYS 3D 占位 + 4 条 AC-EXTRACT 细分），默认状态"未执行"，由 QA 实际填写 | QA / 主 Agent |

## 四、最重要的缺失与映射疑点

> 不替主 Agent 作决策，仅汇总。所有疑点由对应 Agent 在其交付文件内展开。

### 4.1 许可证盲区（来自 `licenses.md`）

1. **全部 9 个 BGM OGG 文件**（`assets/audio/bgm/*.ogg`）—— 项目内无来源、无作者、无许可证。**P0：禁止进入正式发行素材清单。**
2. **全部 8 个 MP4 循环视频**（`assets/videos/*.mp4`）—— 项目内无来源、无许可证。**P0。**
3. **33 个场景图 PNG**（`assets/scene-plates/*.png`）—— 项目内无来源、无许可证。**P0。**
4. **stash-noir Blender 场景** —— README 自述"自制"，但无 LICENSE 文件；默认许可未声明，建议补充。
5. **扑克牌路径三重指向（已核实）**：`assets/cards/`（游戏实际加载路径，src/main.js:53 + 3620）、`Godot/Cards/`、`Godot/素材/playing-cards-assets-master/png/` 三处各 56 张 PNG，**MD5 已逐张验证完全一致**——同一套复制了 3 份。原始来源为 vector-playing-cards（public domain）+ MIT 处理工具；"去边框后是否仍属 public domain"仍为 **P1**；其他两处副本建议清理以避免许可范围混淆。

### 4.2 内容映射疑点（来自 `content-map.md` §6）

1. **`specialRoutes` 配置键 ≠ 实际 route.id**（仅 smoky-den 例外）：
   - high-rise-suite：`service-stairs` → `service-elevator`，`river-launch` → `basement-garage`
   - rooftop-club：`service-stairs` → `emergency-exit`，`river-launch` → `helipad-drop`（图片文件名 `heliport` 与代码 `helipad-drop` 也不同）
   - neon-poker-club：`service-stairs` → `neural-jammer`，`river-launch` → `quantum-portal`
   - 影响：dispatch key 与展示 id 不一致，3D 路线系统需主 Agent 决定是否统一。
2. **`design-baseline.md` 严重过时**：
   - 第 226 行只描述 2 张牌桌（Cargo Table、Mirror Hall），实际有 4 张（Ledger Cellar、Embers Table 在设计文档中无描述）。
   - 第 288 行声称"vertical slice does not support all-in"，但 all-in 在 `src/game.js:1268-1269 / 1524-1549`、`src/ai.js:31-71`、`verify_full_game_flow.mjs:631` 均已实现并测试。
3. **场景图片命名错配**（可能在 `assets/scene-plates/` 命名变更中遗留下来）：
   - `tavern-smoky-den-route-vip-elevator-bg.png` 存放在 smoky-den 目录，但 VIP Elevator 属 high-rise-suite
   - `tavern-smoky-den-route-old-friend-bg.png`、`tavern-smoky-den-route-tunnel-bg.png`、`tavern-high-rise-suite-route-fake-id-bg.png`、`tavern-rooftop-club-route-parachute-bg.png` —— 无对应代码路由
4. **Grep 到但未在浏览器验证**：
   - all-in 提交后手牌结算与 side-pot 完整流程未实测
   - ~~`patternPunish` AI 反制参数存在于 OPPONENTS 配置中，`src/ai.js` 未发现调用点~~（**已修正**：src/ai.js:12 已确认接入 patternPressure；src/ai.js:125 Shark archetype 调整其值；仅调优强度未经实测）
   - `tableToolHeatBonus`（Ledger Cellar +1 热）与 `winHeatRelief`（Embers Table 盈利 -1 热）代码存在但未浏览器实测
   - 通用出口在 heat=6 或现金不足时**仅 notify+return**（src/game.js:985-1000），**不进 summary**；实际"撤离失败 summary"触发路径在代码中未明确（`extraction-failure.mp4` 引用位置待主 Agent 确认）
5. **缺失的角色立绘**：8 位对手**全部无独立角色立绘**（`assets/scene-plates/`、`Godot/`、`output/` 均无）。当前浏览器版用文字 `seatLabel` 与性格参数。3D 阶段需主 Agent 决定是否要做。
6. **`intelBonus: 1`（neon-poker-club）**：字段返回但代码中未发现实际消费逻辑（**疑为遗留**）。

### 4.3 素材清点疑点（来自 `assets.csv`）

1. **三张超高分辨率场景图**（2816×1536，是其他场景图的 4 倍）：`德扑酒馆全貌.png`、`德扑牌桌视角.png`、`德扑撤离视角.png`、`酒馆酒保交易视角.png` —— 可能是多合一全景，是否适合做单点 3D 参考待主 Agent 判断。
2. **通用路线图引用已找到代码证据**（不再属于"无绑定"）：`route-general-bg.png`、`route-fixed-bg.png`、`route-dropbag-cash-bg.png`、`route-dropbag-valuables-bg.png` 已通过 `scenes/extraction/style.css:166` 起绑定 CSS 类，并由 `scenes/extraction/index.js:190` 起的 `routeClass` 字典按 `plan.key` 映射。**引用不等于已实跑。**
3. **5 张"未发现直接引用"** 的场景图：`酒馆酒保交易视角.png`、`酒馆厨房撤离视角.png`、`案件夹弹窗.png`、`个人资产弹窗.png` —— 可能是早期弹窗原型或路线图替代版本。
4. **Godot 3D 原型实际已集成（已核实）**：`Godot/project.godot:14` 设 `run/main_scene="res://three_d/scenes/main.tscn"`；`Godot/three_d/scripts/world.gd` 通过 `preload("res://three_d/assets/stash.glb")` 加载 GLB。`Godot/three_d/assets/stash.glb` 实测 **11,705,068 字节（约 11.7 MB）**，是 Godot 项目运行入口的主资源。HTML5 当前游戏未直接引用 `.tscn` / `.gd`，但 Godot 3D 原型已与 HTML5 游戏并存。
5. **`tavern-{id}-route-parachute-bg.png` 等命名遗留**：旧版路线（old-friend / tunnel / fake-id / parachute）在代码中无路由。
6. **屋顶撤离没有专属 heliport 图**：`tavern-rooftop-club-route-heliport-bg.png` 不存在；仅有 `tavern-high-rise-suite-route-heliport-bg.png`（high-rise 的 直升机坪），不能当作屋顶路线绑定参考。

## 五、已核实 vs 待确认（集中列表）

### 5.1 已核实（可作为 3D 制作依据）

- 4 酒馆 / 4 牌桌 / 8 对手 / 19 物品 / 16 路线的代码定义与 ID 完整可读
- 牌桌解锁链：`cargo-table → ledger-cellar → mirror-hall → embers-table`（`src/data.js:19`）
- 通用撤离 4 类与触发条件（`src/game.js:981-1057`）
- BGM 切换表（`src/main.js:54-65`）+ 视频背景清单（`assets/videos/manifest.json`）
- 8 个视频、4 个酒馆 BGM、藏匿点 / 牌桌 / 撤离场景图均确认引用
- `stash-noir.blend` 存在并通过 `build_scene.py` 重建验证（1479 objects，1115 meshes）
- 牌面资源：`assets/cards/*.png`（56 张，含 52 牌 + 2 鬼牌 + back + back@2x）—— 已确认 src 引用（`src/main.js:53, 3620`）；3D 牌桌可视情况复用或重做。同套文件另两处副本（`Godot/Cards/`、`Godot/素材/...`）MD5 完全一致。
- 扑克牌原始来源 = vector-playing-cards（public domain）+ MIT 处理工具

### 5.2 待确认（按优先级）

| 优先级 | 类别 | 待确认项 | 影响 | 证据需求 |
|---|---|---|---|---|
| **P0** | 许可 | 9 个 BGM OGG 文件来源与许可证 | 禁止正式发行 | 作曲/创作平台原始授权记录 |
| **P0** | 许可 | 8 个 MP4 视频来源与许可证 | 禁止正式发行 | 拍摄/生成记录或第三方许可证 |
| **P0** | 许可 | 33 个场景图 PNG 来源与许可证 | 禁止正式发行 | 创作/购买记录或 AI 生成证据 |
| **P0** | 文档 | `design-baseline.md` 是否仍可作为设计依据 | 影响关卡设计参考 | 主 Agent 决定是否重写设计基线 |
| **P0** | 文档 | `tavern-smoky-den-route-vip-elevator-bg.png` 等 4 张错配图是否复用 | 影响路线系统与场景资源对齐 | 主 Agent 决定图片归属或重新生成 |
| **P0** | 文档 | `specialRoutes` 配置键与实际 id 不统一是否修复 | 影响 3D 路线系统的 ID 设计 | 主 Agent 决定 ID 统一方案 |
| **P1** | 验证 | all-in 后手牌结算 / side-pot 完整流程 | 影响 Milestone 验证完整性 | `verify_full_game_flow.mjs` 补测或 Playwright 验证 |
| ~~**P1**~~ | ~~验证~~ | ~~`patternPunish` 是否接入 AI~~ | ~~已解决~~ | 已确认 src/ai.js:12 + :125 接入；强度调优另作实测 |
| **P1** | 验证 | fixed 撤离计费 `finalCost` ≠ "从预约费用抵扣" | 已核实 src/game.js:838（reserveCost）+ :1024（finalCost）是两次独立扣除 | — |
| **P1** | 验证 | `tableToolHeatBonus` / `winHeatRelief` 实际行为 | 影响牌桌规则准确性 | Playwright 实测 |
| **P1** | 范围 | Ledger Cellar / Embers Table 是否在当前 vertical slice 验证范围 | 影响 QA 范围 | `design-baseline.md` 与 `development-plan.md` 对齐 |
| **P1** | 范围 | `player-notes` 是否需要补验证或移除 | 影响道具平衡与功能完整性 | 主 Agent 决策 |
| **P1** | 资产 | 扑克牌 PNG 去边框后是否仍属 public domain（衍生作品归属） | 影响扑克牌商用资格 | 法务或主 Agent 确认；原始来源确认（vector-playing-cards PD） |
| **P2** | 资产 | 扑克牌冗余副本（`Godot/Cards/`、`Godot/素材/...`）是否清理 | 影响打包与发行体积 | 主 Agent 决定；MD5 已确认与 `assets/cards/` 完全一致 |
| **P1** | 资产 | `stash-noir.blend` 默认许可协议 | 影响 Blender 资产授权链 | 补充 LICENSE 文件 |
| **P2** | 验证 | `intelBonus: 1`（neon-poker-club）字段是否仍需 | 影响数据清理 | 主 Agent 决策 |
| **P2** | 验证 | `routeIntel` 5 个键（`publicExit` / `fixedWhisper` / `emergency` / `serviceStairs` / `riverLaunch`）是否按酒馆隔离 | 影响路线触发逻辑 | 主 Agent 决策 |

## 六、建模 / 开发 Agent 可直接使用的结果

1. **场景图 → 酒馆氛围参考**：`SP-002`（smoky-den）、`SP-003`（high-rise-suite）、`SP-004`（rooftop-club）、`SP-005`（neon-poker-club）已确认与 `bgImage` 绑定；每图 1376×768，含构图、灯光、道具布局。
2. **牌桌道具与材质参考**：`SP-008`（德扑牌桌视角，2816×1536）—— 筹码排列、牌桌布料参考。
3. **藏匿点 3D 基础**：`BL-001`（`assets/blender/stash-noir/stash-noir.blend`，939 KB，含贴图打包，1479 objects）—— 已通过 `build_scene.py` 验证可重建，可作为 Blender 起点。
4. **撤离演出视频参考**：`VD-007`、`VD-008`（extraction-success / extraction-failure，1584×672）—— 5 秒循环，撤离演出视觉。
5. **酒馆 ambient 灯光 / 烟雾动画**：`VD-003`（smoky-den）、`VD-005`（rooftop-club）、`VD-006`（neon-poker-club）—— 灯光 / 烟雾 / neon 闪烁参考。
6. **完整牌组素材**：`assets/cards/*.png`（56 张，含 52 牌 + 2 鬼牌 + back + back@2x）—— 已确认 src 引用（`src/main.js:53, 3620`）；3D 牌桌可视情况复用或重做。同套文件另两处副本（`Godot/Cards/`、`Godot/素材/playing-cards-assets-master/png/`）MD5 完全一致。
7. **牌桌 / 对手 / 物品 / 路线全部字段**：`content-map.md` 已逐条给出代码引用位置，可直接用于关卡 / 道具 / AI 数据迁移。
8. **QA 检查模板**：`acceptance-checklist.md` 已按 22 类编写 183 项检查（含 AC-PHYS 3D 占位 13 条、AC-EXTRACT 细分 4 条），默认状态"未执行"；QA 拿到版本即可逐步填入实际结果。
9. **marked-lens 等 9 项 usable 物品的"建议 3D 模型独立性"**：content-map.md §4a 已逐项给出建模建议（如 marked-lens 为桌面透视/读牌道具、Sleeve Clip 为桌面换牌工具）；仅为建议，不伪装为已确认要求。
10. **stash.glb 与 stash-noir.blend 双向对照**：stash-noir.blend（939 KB，1479 objects，1115 meshes）→ Godot three_d/assets/stash.glb（11,705,068 字节）；两者是同一场景的两种导出形式。

## 七、本轮主 Agent 复核追加修正（2026-09-08）

主 Agent 通过 `inventory-review.md` 提出 10 项复核意见，本轮协作 Agent 集群已逐条对照源码核实并修正：

| # | 主 Agent 发现 | 本轮处理 |
|---|---|---|
| 1 | CSV 部分行列数错位、未转义逗号 | Agent E 重写：SP-010/011/012/013、GD-005 补尾列；VD-001~008、GD-007、GD-008 加双引号包裹；CSV 11 列结构对齐 |
| 2 | GD-008 被标"未集成"，但实为 Godot 主场景入口 | 已改为"已确认（Godot 3D 项目主场景入口）"，引用 project.godot:14 + world.gd preload |
| 3 | patternPunish 误判"未接入" | content-map.md §6.4 改写为已接入（src/ai.js:12 + :125），移除"可能尚未接入"判断 |
| 4 | 通用路线图无代码引用证据 | content-map.md §5e 补充 scenes/extraction/style.css:166+ 与 index.js:190+ routeClass 字典引用 |
| 5 | rooftop-club-route-heliport-bg.png 不存在 | content-map.md §5c 改为明确说明图片不存在，仅 high-rise-suite 有类比图 |
| 6 | fixed 撤离"finalCost 从预约费抵扣"错误 | content-map.md §5e 改写为"reserveCost 与 finalCost 两次独立扣除"（src/game.js:838 + :1024） |
| 7 | AC-EXTRACT-002 把"拒绝"当"失败结算" | acceptance-checklist.md 拆为 AC-EXTRACT-002（heat=6 拒绝）/ AC-EXTRACT-003（现金不足拒绝）/ AC-EXTRACT-004（撤离失败演出触发）三条 |
| 8 | AC-PHYS 仅 2 条且为占位 | 已扩为 13 条 AC-PHYS-001~013，按房间/入口关联，含 3D 迁移后启用注 |
| 9 | 数量与文案：AC 摘要写 167，实际 170；licenses 视频 7 个实为 8 个；marked-lens 笔误 | 摘要改为 183（扩后实测）；视频改为 8 个；marked-lens"桌面色情道具"→"桌面透视/读牌类道具" |
| 10 | CSV/licenses 出现"Byvecade License"无证据 | 已删除，改为本地 LICENSE 实际标题"MIT License (Copyright (c) 2018 Howard Yeh)"+ 原始素材来源 vector-playing-cards public domain |

---

## 八、协作边界声明

按 `协作Agent任务书.md` 第八节严格执行：

- 仅新增 / 修改 `docs/3d-production/inventory/` 内文件
- 未触碰 `src/`、`scenes/`、`Godot/`、模型或原始素材
- 未安装工具、未批量重命名、未删除、未提交或推送 Git
- 未启动游戏编辑器、未修改导入设置、未生成模型或贴图
- 未决定引擎架构、模型精度、美术风格或玩法修改
- 所有"是否独立模型"判断仅作建议，不伪装为已确认要求
- 所有数量差异、设计文档冲突、命名错配一律如实记录

---

**交付完毕。主 Agent 可据此安排：(1) P0 许可证补全；(2) 设计文档更新（4 牌桌 + all-in）；(3) 路线 ID 系统是否统一；(4) 牌桌 4 条规则与全押完整验证；(5) Blender 资产默认许可补充；(6) Godot 3D 原型与 HTML5 游戏的资源统一与版本对齐；(7) `extraction-failure.mp4` 在 src/ 中的实际触发路径核实。**