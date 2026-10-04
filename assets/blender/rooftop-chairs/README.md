# 屋顶配套椅子

可编辑源 rooftop-chairs.blend，构建脚本 build_chairs.py。两把椅子中心对应既有角色根节点 x=-1.1/0.25、z=-1.9，人物与碰撞保持不变。坐垫顶面为 43cm，按现有人物裤子底部和坐姿调整；椅背最高约 1.057m。金属框架含横撑、靠背螺栓和橡胶脚垫，复用已有 leather 三张贴图，未调用生图。

运行模型共 5,776 三角形、4 材质/网格，GLB 与构建报告计数一致，记录 output/3d/rooftop-chairs-integrity.json。合并网格在导出前应用旋转/位移，使 Godot 边界能准确检查脚垫和原碰撞范围。没有新增碰撞、动画或真实灯光节点。

共用酒馆旧椅子独立为 TavernChairs 根节点；屋顶显示新椅子，切换其他酒馆恢复旧椅子。四个牌室均有切换、读档和几何范围检查。配套桌仍为上一轮 rooftop-table。独立吧台、后勤空间、最终磨损、LOD 与目标设备性能仍待完成。

取样截图 output/3d/rooftop-chairs-{idle,bet,fold,win}.png。只检查当次屋顶货运桌的两个角色、四种动画在约 0.3s 时的静态画面，未看到明显椅背穿模；这不证明全部八对手、完整连续动画或最终角色都已验收。

构建：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/rooftop-chairs/build_chairs.py
```
