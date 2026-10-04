# 屋顶会所露台建筑样板

源文件为 rooftop-terrace.blend，保留独立铺装、栏杆、灯架、灯泡和修改器。构建命令：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/rooftop-terrace/build_rooftop.py
```

使用米制，与当前 6×7m 牌室对齐：铺装顶面 y=0、栏杆 1.12m、灯架 2.9m。左侧 z=1.05–2.25 留出既有出口，后墙中间 x=-0.9–0.9 留出后勤通道。木纹复用项目既有 walnut 数据贴图，未调用生图或采购图片。

运行 GLB 在保存可编辑源后按材质合并：一个网格、四个材质面、17892 三角形，Blender、原始 GLB 与 Godot 导入计数一致。实机独立样板图为 output/3d/rooftop-architecture-sample.png，结构记录 output/3d/rooftop-architecture-integrity.json。

当前尚未接入 World，仍需按 rooftop-club 场景切换显示，并验证四牌室、读档、撤离翼、门道、告示和原有碰撞不变。城市外景、后勤三翼独立美术、最终磨损/灯光/性能仍未制作。本包没有碰撞或灯光节点，灯泡材质自发光不等于真实照明；截图中的天空/照明来自独立预览夹具。此样板不能标作五空间中一家已完成，也没有打进桌面安装包。
