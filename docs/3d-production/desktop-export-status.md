# 桌面导出准备与验证

更新：2026-09-30。本记录属于交付准备，不代表 Phase 5 完成。

## 本次结果

- 新增 `Godot/export_presets.cfg`，提供 `macOS Preview` 预设。明确选取当前 `three_d` 的运行脚本、规则、场景与资产，额外包含运行时读取的规则 JSON；测试和工具不随包交付。动态加载的人物与材质也在选择范围内。
- 使用本机 Godot 4.7.2 成功生成 `output/builds/TexasPub-preview.pck`，约 54 MiB。资源包含另一模型当前尚未提交的角色样板，仅用于本地集成预览。
- 从 `/tmp` 启动该包，运行 120 帧后正常退出，日志仅有引擎版本行，没有脚本或缺失资源错误。使用 `--test`，不读写正式玩家存档。这是无窗口启动检查，尚不能证明四酒馆、全部动态素材、交互和视觉完整。
- 实际尝试导出 macOS ZIP，失败退出码为 1；不存在可交付的独立应用。

## 可复现命令

在项目根目录运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --export-pack 'macOS Preview' ../output/builds/TexasPub-preview.pck
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp --main-pack "$PWD/output/builds/TexasPub-preview.pck" --quit-after 120 -- --test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot --export-release 'macOS Preview' ../output/builds/TexasPub.zip
```

原始结果：`output/builds/pack-startup.log`、`output/builds/native-export.log`。

## 原生导出的待办

1. 安装精确匹配 4.7.2.stable 的官方模板；引擎要求的位置是 `~/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip`，当前没有该文件。
2. 引擎还报告 arm64/universal 需要启用 `rendering/textures/vram_compression/import_etc2_astc`。下一次原生导出前启用并等待纹理重新导入，验证材质和包体；不能用改成仅 Intel 来绕过 Apple Silicon 交付。
3. 本地访问 Godot 下载服务曾超时，先恢复下载可达性，再取得官方模板。不要修改用户系统 DNS/代理作为隐式解决方案。
4. 在独立包内验证四酒馆、角色与动态材质、存读档、胜负反馈、撤离及视频；随后测真实窗口和目标机性能、30 分钟稳定性及干净机器启动。
5. 当前预设关闭签名，仅用于内部预览。公开分发前另行决定签名、公证与安装说明。

角色和场景精修会继续更新资源，因此该 PCK 是一次工作树快照，不是冻结版本。新增运行素材时须更新预设资源选择，再重做导出验证。
