# 3D 原型 · 双桌与撤离闭环

## 运行

双击本目录的 `启动3D原型.command`。也可以在 Godot 4.7.2 打开上一级 `project.godot`，按 F6 运行 `three_d/scenes/main.tscn`，或按 F5 运行项目。

- WASD：行走；鼠标：观察。
- 接近物件并将准星对准它，按 E 交互；有效距离为 2 米，墙体会阻挡交互。
- 皮箱可以开合；右侧房门显示出发金额，确认后进入烟雾酒馆。
- 靠近牌桌前沿按 E 入座，点击“开始牌局”；每席 60 筹码，最多两手。
- 通过按钮弃牌、过牌、跟注、加注或全押；加注输入框表示加到的总额。
- 牌局开始后不能中途离座；一手结束点“下一手”，整桌结束点“离开牌桌”。
- 离桌后，查看入口门旁的白色出口告示，再对准门按 E 查看撤离费；确认后返回藏匿点。
- 货运桌结束并离座后，酒馆右侧门可进入账房地窖：买入 90、盲注 15/30、最多两手；门口可返回酒馆。
- 每张桌每局只玩一次；可以首桌后直接撤离，也可以继续第二桌。
- 开局前可以按 Esc 离座，开局后 Esc 暂停牌局。
- Esc 暂停／恢复；切出窗口自动暂停。

## 当前完成

- Blender → GLB → Godot 的实际导入与分组。
- 藏匿点与烟雾酒馆的可行走粗模空间、碰撞、门切换。
- 视线交互、箱盖动作、入座与离座、暂停。
- 独立的牌型比较、浏览器兼容随机数／洗牌、边池计算模块及对照测试。
- 盲注、行动队列、两手推进、本地 AI 对手、全押与摊牌分账、三维动态牌面。

**已接通带钱出发、首桌买入、离桌返还、寻找出口和付费撤离；已自动保存资金、库存、牌局和位置，关闭后可继续。** 酒馆还是灰盒；Blender 原图像贴图已保留，木材和皮革已换用烘焙 PBR 贴图，烘焙、人物、音效、完整搜索事件、其它酒馆和正式美术仍待制作。此版不是最终画质样板。

## 技术入口

- `scripts/world.gd`：空间组装、交互请求分发和视角状态。
- `scripts/player.gd`：第一人称移动和射线目标检查。
- `scripts/interactable.gd`：物件的交互 ID、标题和状态。
- `rules/poker.gd`：不依赖画面和场景节点的纯规则。
- `assets/stash.glb`：8 个网格、185,908 个三角形，约 16.4 MB；网格数量不等于绘制调用数量。
- `assets/stash-export.json`：导出检查数据。

Blender 源文件在项目根目录的 `assets/blender/stash-noir/`。`export_game_asset.py` 只生成运行资产，不覆盖源 `.blend`。

原有 2D 场景保持在原位置。项目主入口切换到新的 3D 场景，当前实测编辑器版本为 Godot 4.7.2，Mac 使用 Metal / Forward+。尚未安装并验证桌面导出模板，也尚未交付独立游戏安装包。

## 验证

在项目根目录执行：

```sh
node Godot/three_d/tests/generate_poker_fixtures.mjs
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/poker_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/smoke.gd -- --test
```

牌型对照数据由现有浏览器规则生成，包含 1,013 组手牌、200 次比较、100 个随机输出和 5 套洗牌结果，另有 106 项边池及筹码守恒检查。3D 操作检查覆盖 26 个断言。

报告在项目根目录 `output/3d/`。检查日志必须没有 `SCRIPT ERROR` 或 `ERROR`，且报告中的 `failed` 为 0；不能仅依据 Godot 进程退出码判定通过。

真实渲染截图：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Godot --rendering-driver metal --resolution 1376x768 --script res://three_d/tests/capture.gd -- --test
```

截图来自引擎实际帧缓冲；此操作会临时打开并关闭游戏窗口。

## 首桌新增验证

```sh
node Godot/three_d/tests/generate_table_fixtures.mjs
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/table_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/table_parity.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/table_integration.gd -- --test
```

与旧网页实现的明确差异和范围，见项目内 `docs/3d-production/table-migration.md`。

## 资金闭环验证

执行与上面相同的 Godot 命令，将脚本换为 res://three_d/tests/run_test.gd。

资金测试 639 项，界面整局测试 58 项。具体口径见项目内 docs/3d-production/run-migration.md。

## 双桌流程验证

运行脚本 res://three_d/tests/two_tables.gd（参数 -- --test），共 27 项检查。增加 --capture 并使用 Metal 图形模式，可生成 output/3d/ledger-table.png。

账房地窖目前复用粗模空间布局；已接入原版买入、盲注、对手和解锁条件，已接入镜片、袖口夹的额外风声及盈利物品奖励。

## 背包、奖励与保存

- B 只打开自己的背包与已知线索；商品需要在酒保货架上对准实物按 E 购买。对准吧台与酒保交谈，出售、查规则、降风声或预约接应；每轮 2 行动力，完成牌桌后刷新。
- 支持全部九种可用道具，实际库存随轮次变化；手机在第二轮提前上架，便于最后一桌前使用。
- 盈利离桌后按原版条件领奖，满背包会提示；贵重物可以出售或撤离折现。
- 服务面板打开时牌局暂停，B / Esc 返回。
- 自动保存间隔为 0.5 秒，并在切出窗口与关闭时保存；重启后恢复到暂停界面。存档不与浏览器版混用。
- 无法普通撤离时，可查看并确认放弃本局的损失；保留原金库；持有夹层钱包时可额外带回至多 80 现金。

新增验证脚本 services_save_test.gd 共 46 项，覆盖场景恢复、道具消耗、奖励及损失；完整说明见 docs/3d-production/services-save-migration.md。

## 预约与特殊撤离

- B 面板只查看已知路线的位置与费用；到实际入口按 E 才能撤离。
- 完成货运桌或使用手机获得接应线索；预约预付和撤离尾款分开支付，面板显示有效轮次。
- 后勤通道左转上楼到后厨出口，直走进入库房右侧货梯，右转下坡到河边码头；使用对应通行证或预约后，在入口按 E 查看条件并确认。
- 风声达到 6，离桌后触发紧急结算；无可用出口则按失败规则结算。
- 道具和路线测试 routes_items_test.gd 共 54 项；整体计划、制作遗漏项和测试步骤见 docs/3d-production/plan-review.md。

## 2026-09-09 交互调整

台灯、抽屉、窗户、桌面扑克牌/筹码以及酒馆壁灯/餐具柜均可对准按 E 操作。窗外目前为动态雨街。每手输赢与净筹码在中央显著显示。

新增 spatial_interaction_test.gd（40 项）。具体范围、试玩步骤和截图索引见 docs/3d-production/interaction-pass.md。

## 第一轮场景细化

Blender 细节包已替换牌桌、吧台、椅凳、吊灯、地板和护墙板的部分粗模；玩法入口和碰撞保留。新增源文件 assets/blender/tavern-detail/tavern-detail.blend 可继续编辑。并非最终写实美术验收版，具体完成范围见 docs/3d-production/art-pass-01.md。

art_integration_test.gd 在 Metal 模式加 -- --test --capture 可检查细节包并截图，实机路径 96 项检查。
