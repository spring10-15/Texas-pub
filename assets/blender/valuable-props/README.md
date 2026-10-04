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

## 金属表面细节首版（2026-10-04）

`metal_surfaces.py` 以固定种子制作银、金的加工拉丝与少量细划痕，四张 512×512 法线/粗糙度 PNG 位于 `textures/`，源 blend 内同时打包。使用 Non-Color 数据贴图和显式 UV，GLB 内嵌四图；Godot 导入时提取出四张 `valuable-props_*.png`，已加入两平台导出清单以保持运行依赖完整。此为加工表面微细节，不等同接触区磨损、脏污分布或高模烘焙完成；不使用生图或外部图像。

十件物品面数和尺寸保持不变，GLB 由 2,698,688 增至 2,907,648 字节。Godot 专项检查现为 69 项，验证导入后的贴图、法线开关和 UV；原始 glTF 与 Blender/Godot 面数独立对齐记录在 `output/3d/valuable-metal-integrity.json`。近景实机样板 `output/3d/valuable-metal-closeup.png` 能观察旧银打火机侧面的细拉丝，怀表保留表盘可读性。联系图仍使用背包预览组件，不是实际抵押视角或最终美术验收。该版本尚未重新导出安装包或完成 GPU/目标机型性能验证。

全量回归：`output/3d/regression/20261004-032841/report.json`，81 个 Godot 套件、20 个 Python 测试通过，运行期间资源指纹不变。

## 宝石切面结构（2026-10-04 后续）

原锥台改为闭合的台面、八面冠部、薄腰围与亭部，平面法线保留切面。红宝石/翡翠各增加 18 个三角形，雕像两只金镶眼同一切面构造共增加 36 个；全包增加 72 个三角形，规则 ID 与十件米制尺寸保持不变。原始 GLB、Blender 和 Godot 面数对齐，记录 `output/3d/valuable-gem-integrity.json`；源四个切面零件均闭合、各边两面、无零面积面、正体积，见 `output/3d/gem-topology.json`。近景 `valuable-gem-closeup.png` 已检查。本轮只完成结构，仍是有色不透明材质，透光/折射/内部吸收与最终宝石外观未完成。安装包仍为上一金属版本；该切面版本不在 metal-active-soak 的 30 分钟结果范围内。

切面版本全量回归：`output/3d/regression/20261004-125916/report.json`，81 个 Godot 套件、20 个 Python 测试通过，运行期间资源指纹不变。
