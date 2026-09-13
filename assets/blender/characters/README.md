# 人物基础模型与动作链路

来源：项目现有「酒馆酒保交易视角.png」与「德扑牌桌视角.png」。依据其中的西装、马甲、礼帽、酒保衬衫与坐姿制作，未生成新参考图，也未引入第三方角色资产。

`build_characters.py` 生成八位对手与酒保的独立 `.blend` 和 Godot `three_d/assets/characters/*.glb`。每个模型包含 14 根骨骼、一张蒙皮网格、衣领/纽扣/面部/手部组件，以及 idle/bet/win/fold 四段基础动画。面部体块已体素融合；衣襟按身体曲面生成。对手以坐姿绑定，酒保以站姿绑定；单位为米，面向 Godot +Z。

复现：在项目根目录执行 Blender --background --python assets/blender/characters/build_characters.py，再运行 Godot --headless --editor --path Godot --import。实际程序路径见项目 three_d README。

这不是最终人物美术：目前共用基础面部与体型，差异主要为服装、帽发与配色；体素面部仍需适合表情的拓扑、UV/磨损贴图、个性化五官、指骨与自然发牌/下注/递物动画。当前单人物约 4 万顶点，需要低模与性能验收，不能把已导入骨架等同于最终质量达标。骨架主要用于验证流程，坐姿与站姿后续需统一姿态/动画体系。
