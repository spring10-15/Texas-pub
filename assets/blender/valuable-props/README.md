# 十件贵重物独立实体首版

2026-10-04。此包只补已有十件贵重物，不新增规则、不替换现有九件商品或三件场景交互件。当前是可编辑实体首版，尚未完成高保真、LOD、磨损烘焙与最终性能验收。

构建：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python assets/blender/valuable-props/build_valuables.py
```

源 `valuable-props.blend` 在网格合并前保存，保留零件、文字、材质和倒角修改器；脚本转换、按物品合并网格后导出 `Godot/three_d/assets/valuable-props.glb`，面数记录在 `export-report.json`。十个根节点均使用规则 ID、位置为零、缩放为一。Blender 米制/Z-up 经标准 glTF 导出为 Godot Y-up；最终 Godot 尺寸以 `output/3d/prop-contract.json` 为准。

模型包括打火机铰链/刻线、筹码嵌条/字样、袖扣杆和横扣、怀表刻度/指针/表弓、硬币滚边/铭文、债券边框/蜡封、珍珠/金扣、胸针宝石/围珠/别针、黑曜石像、带边框与编号的本票。使用自定义常量 PBR 材质和游戏自有英文标记，没有生成或采购新图片，没有宣称这些模型参考了经许可的新增外部图像。

实际使用：背包 `item_preview.gd` 先解析原商品包，再解析本包；只有当前持有物品才创建预览，未知 ID 保留符号。预览自适应包围盒、一次渲染后停止。现已接入搜索奖励到账后的模型展示、开桌前抵押预览及静态桌面抵押物；取物动作、牌桌奖励亮相、归还/没收动作和出售交接仍未完成。

结构专项 `valuable_asset_test.gd` 42 项通过；十件原始 GLB 索引计数与 Blender 清单、Godot 包围盒工具面数独立对齐，证据 `output/3d/valuable-props-integrity.json`。Godot 渲染联系图 `output/3d/valuable-props-contact-sheet.png` 已检查，使用相同背包预览组件，属于独立展示夹具。2026-10-04 后续已在预览组件补环境反射，解决金属近乎全黑的问题；最终场景中的反射校准、宝石玻璃/折射、真实磨损和物品 LOD 仍需在实际视角精修。

后续接入：已增加开桌前抵押选择预览，以及 `collateral_display.gd` 的实际已抵押物静态桌面模型、读档重建和结算清理。归还/没收动作与奖励/出售交接仍待制作，以上不等同所有显示用途完成。
