# 屋顶独立铺装接入

共用酒馆模型将地板拆为独立 TavernFloor，不再与家具的 walnut 网格合并。室内仍显示原地板，屋顶显示独立 105 块露台铺装。铺装下补封闭基层，避免木板缝透看到城市亮窗；碰撞顶面仍为 y=0，可见顶面与原地板保持 y=0.014。

既有源 tavern-detail.blend 未改变。新增 export_details.py 可从其独立可编辑对象直接导出，免重烘焙；build_detail.py 使用同一导出入口。CLI 重导出仅更新酒馆 GLB，藏匿点 GLB 与材质图片不变。

旧/新酒馆 GLB 总三角形均为 72,716，整体边界和材质名称一致；地板独立为 28,200 三角形，网格由 8 个变为 9 个。导出字节由 11,972,100 变为 11,611,752。露台包含封闭基层后为 18,120 三角形。对照记录：output/3d/floor-split-integrity.json。

179 项露台专项检查、171 项美术集成检查通过。专项覆盖四牌室、地板高度、保留家具、恢复室内地板、读档、碰撞和 Run 不变；导出的实际 PCK 在 Mac Metal 下同样通过 179 项。全量 82 个 Godot 测试套件与 20 个 Python 测试通过，源码指纹不变：output/3d/regression/20261004-140224/report.json。旧网格数量断言已更新为独立地板的新结构，并加上节点/高度验证。

实机图：output/3d/rooftop-in-game.png。验证包：output/builds/rooftop-deck-validation.pck；记录：output/builds/rooftop-deck-package-verification.json。桌面 ZIP 仍为上一轮城市外景版本，未包含此次地板拆分。

仍待完成：独立家具、城市立面细节、后勤三翼美术、最终磨损/灯光与目标设备性能。当前不标记屋顶高保真或全项目目标完成。
