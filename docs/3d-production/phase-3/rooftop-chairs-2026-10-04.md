# 屋顶配套椅子接入

两把椅子与现有角色中心 x=-1.1/0.25、z=-1.9 对齐。金属框架、横撑、靠背螺栓、橡胶脚垫和皮革坐垫/靠背，复用三张既有 leather 图片，无生图。坐垫顶面 43cm，按当前坐姿裤子底部调整；人物骨骼、动作和碰撞未改。

运行模型 5,776 三角形、4 材质/网格，可编辑源在 assets/blender/rooftop-chairs/。原始 GLB 与构建报告一致：output/3d/rooftop-chairs-integrity.json。最终磨损、LOD、全部人物连续动作适配和性能仍未验收。

共用酒馆模型将旧椅子拆为 TavernChairs，屋顶隐藏旧椅子并显示新椅子，其他酒馆恢复旧椅子。原可编辑源保持不变，总三角形 72,716、整体边界和材质名称不变。共用导出现在 14 个网格、11,606,468 字节。拆分时保留的合并旋转会放大 Godot 包围盒，现仅对椅子组应用导出变换，消除误判；未修改实际造型、碰撞或人物位置。

227 项露台切换/几何范围检查、179 项美术集成检查、19 项真实射线入座/抵押物/读档/合法结算检查通过；实际 PCK 在 Mac Metal 下通过相同三组。全量 83 个 Godot 测试套件、20 个 Python 测试通过，源码指纹不变：output/3d/regression/20261004-143926/report.json。

固定背后视角取样 output/3d/rooftop-chairs-{idle,bet,fold,win}.png，检查当次屋顶货运桌两个角色四种动作在约 0.3s 的静态帧，没有看到明显椅背穿模。这不能代表全部八对手、完整连续动画或最终精模适配完成。

验证包 output/builds/rooftop-chairs-validation.pck；记录 output/builds/rooftop-chairs-pack-verification.json。桌面 ZIP 仍是先前城市外景版，未同步此次独立家具。

独立吧台与后勤空间、最终磨损/灯光和目标机性能仍待完成，屋顶高保真及全项目目标保持未完成。
