# 后勤三翼撤离空间细节包

`tavern-routes.blend` 是可编辑源文件，`build_routes.py` 可从空场景重建 Blender 工程并导出 `Godot/three_d/assets/tavern-routes.glb`。尺寸使用 Godot 本地米制坐标；脚本在导出时统一转换到 Blender Z-up。

资产只叠加视觉细节，不带碰撞：检修舱门、后厨瓷砖/储物罐、后厨楼梯扶手、预约货梯栅门/升降机构、河埠防滑木板/系船柱。通路碰撞、路线触发和交互锚点仍由 `Godot/three_d/scripts/tavern_layout.gd` 管理。河埠末端保留一段开放门洞，能看到外侧水面与船。

重建命令：

```sh
/Applications/Blender.app/Contents/MacOS/blender --background --python assets/blender/tavern-routes/build_routes.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path Godot --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --script res://three_d/tests/art_integration_test.gd -- --test
```

后厨、货梯与河埠的玩家实走和路线高度检查由 `spatial_interaction_test.gd` 覆盖；该模块是第一轮可玩细节包，不等于四家酒馆的独立建筑美术或最终高精度验收。
