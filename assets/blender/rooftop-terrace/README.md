# 屋顶会所露台建筑样板

源文件为 rooftop-terrace.blend，保留独立铺装、栏杆、灯架、灯泡和修改器。构建命令：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/rooftop-terrace/build_rooftop.py
```

使用米制，与当前 6×7m 牌室对齐：铺装顶面 y=0、栏杆 1.12m、灯架 2.9m。左侧 z=1.05–2.25 留出既有出口，后墙中间 x=-0.9–0.9 留出后勤通道。木纹复用项目既有 walnut 数据贴图，未调用生图或采购图片。

运行 GLB 在保存可编辑源后按材质合并：独立铺装与建筑两个网格、四个材质面、18108 三角形，Blender、原始 GLB 与 Godot 导入计数一致。实机独立样板图为 output/3d/rooftop-architecture-sample.png，结构记录 output/3d/rooftop-architecture-integrity.json。

已按 rooftop-club 接入 World，四牌室切换、读档和静态碰撞保留通过 147 项针对性检查。屋顶模式仅渲染当前牌室，回到藏匿点或其他酒馆恢复室内外壳与背景。新铺装在运行时隐藏，沿用与家具合并的原地板，避免重叠；后勤三翼仍使用原室内结构。实机截图：output/3d/rooftop-in-game.png。已接入独立 rooftop-city 初步背景；最终城市立面、后勤三翼独立美术、磨损/灯光/性能仍未完成。本包没有碰撞或灯光节点，灯泡材质自发光不等于真实照明；截图中的天空/照明来自独立预览夹具。此样板不能标作五空间中一家已完成，也没有打进桌面安装包。
