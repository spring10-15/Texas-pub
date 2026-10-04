# 屋顶会所城市背景

可编辑源文件 rooftop-city.blend，构建脚本 build_city.py。使用米制、固定 seed=4104，仅在屋顶会所露台激活时显示，跟随当前牌室建筑一起隐藏。无碰撞、动画或真实灯光节点。

三层背景距离露台中心约 22、43、68 米，街面低于露台 18 米。52 栋建筑，462 扇亮窗，包含屋顶檐口、设备箱、近景排气管。52 栋均为背景建筑，不能进入。暖窗和少量冷窗使用自发光材质；没有调用生图或外部纹理。

导出按材质合并为 6 个网格、6 个材质面，共 7,644 三角形，GLB 541,796 字节。原始 GLB 与构建报告一致，记录 output/3d/rooftop-city-integrity.json。材质目前仅为基础 PBR；立面纹理、最终磨损和最终灯光未完成，不能标为高保真验收通过。

实机视角截图：output/3d/rooftop-in-game.png、rooftop-city-entry.png、rooftop-city-table.png、rooftop-city-exit.png。入口和牌桌仍使用已有家具。155 项露台专项检查包含四牌室切换、背景模型加载、背景无碰撞、室内恢复、读档复用、静态碰撞和规则状态不变。性能仅有几何预算，尚无中端机 60 fps 验收。

构建：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/rooftop-city/build_city.py
```
