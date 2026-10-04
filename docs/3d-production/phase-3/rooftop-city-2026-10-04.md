# 屋顶会所城市背景接入

露台之外新增三层城市轮廓，包含 52 栋建筑、462 扇亮窗、屋顶檐口和设备；街面低于露台 18 米。源文件 assets/blender/rooftop-city/rooftop-city.blend 保留 637 个独立可编辑网格对象。构建脚本固定种子，未调用生图。

运行背景为 6 个材质合并网格、7,644 三角形、541,796 字节。仅显示当前屋顶牌室，与露台一起切换；无碰撞、动画或真实灯光节点。城市不增加探索范围。源几何检查确认建筑不侵入 18 米外景排除范围。

155 项专项检查通过；实际导出 PCK 在 macOS Metal 下也通过 155 项。全量 82 个 Godot 测试套件和 20 个 Python 测试通过，源码指纹不变：output/3d/regression/20261004-134239/report.json。

实机画面：output/3d/rooftop-in-game.png 与 rooftop-city-entry.png、rooftop-city-table.png、rooftop-city-exit.png。出口近距离截图仅用于确认原门和交互提示保留；牌桌/入口视角确认城市背景没有遮挡原牌桌与后勤入口。测试是固定相机视角，不代表真人动线测试。

检查记录：output/3d/rooftop-city-integrity.json、rooftop-city-source-audit.json；验证包：output/builds/rooftop-city-validation.pck。桌面 ZIP 未更新。

当前为初步城市建筑轮廓，最终立面、磨损、灯光、后勤三翼与目标设备性能仍待完成，不能作为高保真阶段验收通过。
