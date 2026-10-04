# 屋顶会所独立牌桌

可编辑源 rooftop-table.blend，构建脚本 build_table.py。2.05×1.4 米，毛毡顶面 y=0.857、皮革包边 y=0.852；保留既有桌面中心、入座位置与碰撞。独立金属底座含安装片、螺栓、横撑、橡胶脚垫，皮革包边有独立缝线。材质复用已烘焙 fabric/leather 六张项目贴图，没有调用生图或外部图片。

源文件保留独立对象及倒角等修改器。运行模型按六种材质合并，13,376 三角形、6 个网格/材质面。GLB 与源报告计数一致，记录 output/3d/rooftop-table-integrity.json。没有碰撞、动画或真实灯光节点。

共用酒馆模型同时拆出 TavernTable 根节点；屋顶显示新模型并隐藏旧桌，其他酒馆恢复旧桌。原家具总几何/边界/材质名称仍保留，其他椅子和吧台暂未独立制作。毛毡圆角与皮革环独立建模；当前金属仅基础 PBR，最终磨损和性能验收仍待完成。

运行展示修正：手牌的可视模型向桌内移到 z=-0.39，牌局数据不变；抵押物底面由 y=0.85 对齐到实际毛毡 y=0.857，原水平位置不变。实际射线入座、抵押物、手牌覆盖范围、读档与合法行动结算由 rooftop_table_test.gd 回归。实机图 output/3d/rooftop-table-live-play.png。

构建：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/rooftop-table/build_table.py
```
