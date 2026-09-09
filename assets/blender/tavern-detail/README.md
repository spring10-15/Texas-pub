# 酒馆细节模型 · 第一轮

2026-09-09。根据现有藏匿点、烟雾酒馆和酒保交易参考图手工编写 Blender 建模脚本，不使用 image2.5 或新增 AI 参考图。

- build_detail.py：可复现的建模与材质烘焙入口。
- tavern-detail.blend：703 个可编辑网格，保留倒角等修改器，12 张贴图已内嵌。
- interactive-props.blend / build_props.py：九种商店道具、抽屉、桌面筹码和扑克牌的独立可编辑模型；每种运行物件保留独立根节点。
- textures/：四组 1024×1024 PBR 色彩、法线、粗糙度贴图；由 Blender Cycles 程序材质烘焙，不是从参考图提取的贴图。
- Godot/three_d/assets/tavern-detail.glb：按材质合并为 8 个网格，72,716 三角形，11,972,100 字节。
- Godot/three_d/assets/stash-room-detail.glb：1 个网格，54,896 三角形，5,214,960 字节。

几何包括错缝木地板、护墙板与饰条、皮革包边牌桌、车木桌脚、椅背、吧台饰面和脚踏杆、皮革圆凳、酒架、瓶子和绿罩吊灯。资产单位是米，脚本将 Godot 的 Y 向上坐标转换到 Blender，glTF 导出后恢复 Godot 坐标。

在项目根目录运行：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/tavern-detail/build_detail.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/tavern-detail/build_props.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/stash-noir/export_game_asset.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path Godot --import
```

第三步为原有皮箱场景换用已烘焙的木材、皮革、灰泥贴图，不覆盖原始 stash-noir.blend。第四步会让 Godot 自动生成导入元数据并提取 GLB 内嵌图像。

当前材质是第一轮可复用纹理，尚未做每个物件独立的磨损/污迹图、完整灯光与后处理。人物仍是交互粗模，不纳入本轮美术完成项。
