# Phase 3 资产追踪入口

2026-09-29，W0 初始盘点。状态只说明当前运行资产和缺口，不代表美术规格或性能已经验收。规则 ID 以 `Godot/three_d/rules/content.json` 为准；19 件物品与 9 位人物的逐件现状、源文件、加载点和缺口已在 [B2 物品表](../external-handoff/B2-production-breakdown/items.csv)、[B2 人物表](../external-handoff/B2-production-breakdown/characters.csv)，此处不复制第二套逐件清单。

| 空间 ID | 目前运行中的空间资产 | 高保真制作状态 | W1/W2 接入重点 |
|---|---|---|---|
| 藏匿点（`stash`，非酒馆规则 ID） | `assets/blender/stash-noir/stash-noir.blend` → `Godot/three_d/assets/stash.glb`；另有 `stash-room-detail.glb`，Godot 构造房壳和交互节点 | 有可编辑基础场景，未完成高低模、贴图烘焙、材质与性能验收 | W1。保留 `CaseLidPivot`、台灯/窗/抽屉/牌/筹码的可见状态与射线锚点 |
| `smoky-den` 烟雾酒馆 | 四店共用 `tavern-detail.glb`、`tavern-routes.glb` 与 Godot 房壳/牌室/后勤翼 | 有可玩基础场景，尚无此店独立高保真建筑包 | W1 先做吧台、货运桌和一条撤离路径；W2 再补齐四牌室与其余路线翼 |
| `high-rise-suite` 高层套房 | 同一套共用模型；规则、费用、货架、路线按 `scene_id` 变更 | 尚无独立建筑包 | W2。先保留当前物理拓扑，再做能从轮廓、材料和窗景识别的独立空间 |
| `rooftop-club` 屋顶会所 | 同上 | 尚无独立建筑包 | W2。验证屋顶外景、临边栏杆、动线和多高度出口的可读性 |
| `neon-poker-club` 霓虹扑克俱乐部 | 同上 | 尚无独立建筑包 | W2。验证湿街外景、霓虹对比度和暗处交互标识的可读性 |

运行接口：`Godot/three_d/scripts/world.gd` 建造四个牌室并以 `install_detail()` 安装共用视觉包；`Godot/three_d/scripts/tavern_layout.gd` 建造后勤三翼、楼梯/坡道及撤离锚点。建模源在 `assets/blender/tavern-detail/`、`assets/blender/tavern-routes/`；角色按 ID 从 `Godot/three_d/assets/characters/` 加载。W2 若改为四店独立 GLB，应在保留现有碰撞和交互逻辑的条件下按 `scene_id` 选取视觉包，并对四店 × 四桌 × 各撤离翼复测。

W0 尚缺的现场证据：五空间固定视角的 Godot 截图、目标 Mac/Windows 中端机型与同口径帧时/内存基线、逐张参考图的适用性判断。现有文件与节点盘点不能替代这些测量，也不能据 GLB 文件大小推断 60 fps。

交互锚点可从当前运行代码重导：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tools/export_interaction_anchors.gd -- --test`。脚本输出本地 `output/3d/phase-3-interaction-anchors.json`，记录每个 `Area3D` 的房间、动作 ID、房间局部坐标、世界坐标和盒形射线范围。本次导出共 59 个锚点：藏匿点 9、酒馆主厅 18、账房 11、镜厅 11、余烬 10。示例：皮箱 `(-0.39, 1.04, -0.72)`、牌桌座位 `(-0.45, 1.0, 0.04)`、货梯 `(1.12, 1.2, -11.0)`、上行楼梯 `(-2.75, 2.3, -12.65)`、下行码头 `(2.75, -0.2, -13.75)`，均为所在房间局部米坐标。该快照只反映当前默认种子和现有布局；货架、房间变化后应重导，不能把一次导出当成所有种子的交互全集。

## 2026-10-03 接续盘点

三人样板已更新连续手部，当前接入证据与剩余精修见 [人物交接复核](character-handoff-review-20261003.md)。物品重新按实际运行 GLB 盘点：19 件规则物品中 9 件有模型、10 件缺模型；另三个场景交互件不计入规则物品完成数。逐件尺寸、重导命令和货架/手部接入限制见 [物品运行约束](prop-runtime-contract.md)。以上更新不改变五空间、九人物、十九物品的最终目标，也不宣称高保真验收。

## 2026-10-04：贵重物实体首版

十件贵重物新增独立 Blender 源/GLB，几何覆盖从 9/19 到 19/19；背包已接入当前持有物的实际预览。细节与当前未完成的高保真、奖励/抵押用途见 [物品运行约束](prop-runtime-contract.md) 的本日记录。原 B2 表和 10 月 3 日记录是历史盘点，不能继续据此声称当前仍缺十件网格，也不能反过来把首版网格标为 W4 最终放行。
