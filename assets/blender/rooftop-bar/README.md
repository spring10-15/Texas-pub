# 屋顶独立吧台首版

石质台面、胡桃木柜体和凹面板、金属框架、黄铜脚踏杆、双层货架及三把皮革圆凳。可编辑源为 rooftop-bar.blend，重建入口 build_bar.py；五个材质、9,924 三角形，木材复用既有三张纹理，无新增 AI 图片。

台面顶面 1.21m，保留原交互与碰撞。下层货架顶面 1.70m，x=2.46–2.88m；商品由现有 Godot 商店系统动态摆放，按实际网格底部贴合货架。商品库存、交付和购买规则不写入静态模型。

运行文件 Godot/three_d/assets/rooftop-bar.glb。构建报告 export-report.json，原始 GLB 校验 output/3d/rooftop-bar-integrity.json。Blender 源保留修改器，导出时应用变换并按材质合并。

最终独立磨损、石材与皮革细节、LOD、完整灯光及目标机性能仍未验收。后勤空间尚待独立建模。
