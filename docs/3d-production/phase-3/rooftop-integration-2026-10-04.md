# 屋顶会所露台接入记录

已将 Blender 露台建筑接入 rooftop-club 的四个牌室。屋顶模式显示栏杆、灯架、灯串与夜空，隐藏前墙、左墙和天花板的渲染网格；仅显示当前牌室，防止看到并排的开发房间。返回藏匿点或其他酒馆时恢复原外壳和背景。静态碰撞、入口、交互锚点与游戏规则保留。

新建筑 18,108 三角形、4 材质面；铺装与建筑分开导出。原地板和家具合并，因此运行时隐藏新铺装，避免重叠。未调用生图。

验证：147 项针对性检查通过，包含四牌室、读档、反复切换复用节点、静态碰撞与 Run 状态不变；实际导出的 PCK 在 macOS Metal 下同样通过 147 项。全量回归 82 个 Godot 测试套件与 20 个 Python 测试通过，运行期间源码指纹不变。报告：output/3d/regression/20261004-133556/report.json。

实机截图：output/3d/rooftop-in-game.png。验证包：output/builds/rooftop-validation.pck；记录：output/builds/rooftop-package-verification.json。桌面 ZIP 尚未更新；没有将此验证包作为 Windows 原生测试。

仍待完成：城市外景、后勤三翼独立美术、独立家具与最终铺装、磨损细节、最终灯光和目标设备性能验收。当前不能标记整个屋顶会所高精度制作完成。
