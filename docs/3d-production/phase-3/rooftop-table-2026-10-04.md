# 屋顶独立牌桌接入

新模型 rooftop-table.glb 使用独立金属脚架、安装片/螺栓、横撑、橡胶脚垫、皮革圆角环与缝线；尺寸 2.05×1.4 米，毛毡顶面 y=0.857。可编辑源和构建脚本在 assets/blender/rooftop-table/，复用六张既有 fabric/leather 图片，未调用生图。

运行资产 13,376 三角形、六材质/网格、6,728,664 字节。GLB 索引计数与源报告一致：output/3d/rooftop-table-integrity.json。最终金属磨损、专用材质和目标设备性能仍未验收。

共用酒馆 GLB 将旧桌拆为 TavernTable 根节点，屋顶隐藏旧桌并显示新桌，其他酒馆恢复旧桌。共用总三角形仍为 72,716，整体边界及材质名称不变；网格 12 个，11,604,568 字节。原可编辑酒馆源、藏匿点 GLB 与材质图片未改，椅子和吧台仍用旧资产。

实机入座检查发现原手牌模型伸出桌沿，显示坐标 z 从 -0.17 调整为 -0.39，使其完整覆盖在毛毡内。抵押物原底面 y=0.85 与已有可见毛毡差 7mm，现对齐 y=0.857。仅改变视觉投影，牌局数据、存档格式、水平抵押位置、入座锚点和碰撞保持原逻辑。

203 项露台切换、175 项美术集成、19 项实际射线入座/牌面/抵押物/读档/自然合法结算检查均通过，实际导出 PCK 在 Mac Metal 下通过同样三组检查。新增 rooftop_table_test.gd 复用现有抵押物真实交互合同，仅切换酒馆夹具。全量 83 个 Godot 测试套件与 20 个 Python 测试通过，源码指纹不变：output/3d/regression/20261004-142023/report.json。

实机图：output/3d/rooftop-table-live-play.png。验证包：output/builds/rooftop-table-validation.pck；包内记录：output/builds/rooftop-table-pack-verification.json。桌面 ZIP 仍为上一轮城市外景版本，未包含独立铺装/牌桌与这次显示位置修正；未发布 GitHub Release。

当前只完成独立牌桌的第一轮制作与接入，独立椅子、吧台、后勤空间、最终磨损及性能仍待完成，不标记屋顶高保真或全项目完成。
