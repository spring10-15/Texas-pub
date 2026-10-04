# 屋顶中央库房与预约货梯

屋顶后勤模型新增中央库房地坪、两侧隔墙、后墙、两只板条箱、金属储物架及货梯门框/栅门/把手/呼叫按钮。当前 rooftop-service.glb 为 21,720 三角形、5 个材质/合并网格、6 张既有纹理。可编辑源与构建入口仍在 assets/blender/rooftop-service/，不使用新增 AI 图片。

旧共用货梯装饰朝向走廊后方，与真正位于侧墙 x=1.12、z=-11 的交互区域不一致。新门朝向该交互区域；货梯仍是现有预约撤离路线，未新增呼叫按钮玩法、动画、费用或进入电梯内部的功能。

共用路线源不改。export_routes.py 直接重导出既有源，将货梯与箱件装饰拆为 StoreDetails：旧/新总三角形均 16,160、材质名称集合与合并边界一致。当前 14 网格、836,204 字节。证据 output/3d/store-split-integrity.json；build_routes.py 重建共用同一导出函数。

后勤仅存在于主酒馆房间 Tavern；此次将独立后勤模型也限定在该房间显示，避免其他三个牌桌房间显示没有碰撞支撑的后勤模型。新库房只替换对应可见网格，不改原碰撞、路线锚点或任何 Run 规则。其他酒馆恢复旧可见网格和 StoreDetails。

游戏内截图 output/3d/rooftop-city-store.png 已检查，货梯交互提示能与新门对应。截图是固定近景，不能代表最终三距离验收或所有场景已经统一。

装卸侧翼、屋顶与河岸的建筑关系仍未完成；磨损/LOD/最终灯光及目标设备性能尚未验收。桌面 ZIP 仍未同步独立家具和后勤更新。

全量 85 个 Godot 套件、20 个 Python 测试通过，源码指纹不变：output/3d/regression/20261004-153025/report.json。实际 PCK 在 Mac Metal 下通过 411 项布局、183 项美术接入、19 项屋顶牌桌、34 项吧台和 131 项实际行走检查，共 778 项；后者包含打开/关闭货梯预约撤离面板且完整 Run 状态不变。记录 output/builds/rooftop-store-pack-verification.json，验证包 rooftop-store-validation.pck。该包未做 Windows 原生运行、中端 60fps 或本包长时验收。
