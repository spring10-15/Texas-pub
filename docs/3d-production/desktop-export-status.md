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
2. 已启用 `rendering/textures/vram_compression/import_etc2_astc` 并完成导入；重新尝试原生导出，ARM 纹理错误消失，仅报告模板缺失。真实 ARM 窗口性能仍待测。
3. 本地访问 Godot 下载服务曾超时，先恢复下载可达性，再取得官方模板。不要修改用户系统 DNS/代理作为隐式解决方案。
4. 在独立包内验证四酒馆、角色与动态材质、存读档、胜负反馈、撤离及视频；随后测真实窗口和目标机性能、30 分钟稳定性及干净机器启动。
5. 当前预设关闭签名，仅用于内部预览。公开分发前另行决定签名、公证与安装说明。

角色和场景精修会继续更新资源，因此该 PCK 是一次工作树快照，不是冻结版本。新增运行素材时须更新预设资源选择，再重做导出验证。

## 补充：包内动态资源检查

新增 `Godot/three_d/tools/verify_export_pack.gd`，作为包外检查脚本运行。当前包内 9 个角色可加载并实例化、12 张材质贴图可加载、4 个场景模型和主场景可加载，共 26 项资源检查、0 失败。检查同时确认测试和工具目录未随包交付。原始日志为 `output/builds/pack-resources.log`。这不等于全部游戏行为或视觉通过。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp --main-pack "$PWD/output/builds/TexasPub-preview.pck" --script "$PWD/Godot/three_d/tools/verify_export_pack.gd"
```

## 补充：四酒馆包内最短循环

`verify_export_loop.gd` 在项目目录外加载 PCK，实例化真实主场景，然后针对四家酒馆逐一调用包内实际规则：出发、一次合法搜索、货运桌完整结算、公共出口撤离、金库按报价入账。56 项检查通过，退出码 0，最终日志无引擎错误；原始日志为 `output/builds/pack-loop.log`。

首轮脚本错误地要求在牌桌结算后再次发现出口，4 项失败。核对实际 `settle_table` 会自动揭示公共出口后，检查改为验证这一真实结果，未修改游戏规则。

牌局采用固定合法策略（玩家过牌/跟注，对手弃牌），测试目的为包内可执行性；不代表 AI 策略验收。四酒馆只测货运桌与公共出口，其他三桌、特殊出口、抵押、商店、存档和物理射线仍需包内扩展检查。主场景已实例化，但并未通过角色移动或鼠标触发流程，不能代替真人完整试玩。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /tmp --main-pack "$PWD/output/builds/TexasPub-preview.pck" --script "$PWD/Godot/three_d/tools/verify_export_loop.gd" -- --test
```

## 补充：包内真实磁盘存读档

扩展同一 `verify_export_loop.gd`：四家酒馆均在货运桌进行中捕获状态，通过包内 SaveStore 原子写入临时文件、实际读回，再由 RunCheckpoint 恢复并比较完整状态（包含牌局和 RNG）。使用恢复实例继续结算、撤离；将撤离后的状态替换写回、读回并恢复，确认重复撤离被拒绝且金库不增加。检查 `.tmp` 无残留并删除测试文件。当前共 94 项检查、0 失败，退出码 0；同一日志 `output/builds/pack-loop.log` 更新为本次结果。

文件位于系统缓存目录，带进程号；存在同名文件时直接拒绝运行。未读写正式 `user://three-d-checkpoint.save`。这些检查覆盖规则状态的磁盘恢复，未通过 World 恢复玩家位置/镜头/交互物，也未模拟关闭和重启进程；正式包仍需验证这两层。当前包保持原快照，检查脚本在包外执行，因此不需要因工具变化重新打包。

## 补充：真实进程退出与 World 恢复

`verify_export_restart.gd` 已通过两个独立进程验证两种状态，四次运行均退出码 0，日志无脚本或资源错误：

- 藏匿点：关灯、打开窗户和首个抽屉，设置非默认位置及镜头，写入完整 World 状态；写进程退出后，读进程重新创建主场景并恢复。
- 牌桌：从真实 World 出发到烟雾酒馆，移动到桌前并通过实际物理射线入座，创建货运桌牌局，保存并退出；读进程恢复运行状态、玩家和返回位置、镜头、环境物件、牌局/RNG、入座摄像机及玩家控制权限。

两种恢复均比较完整 `world.checkpoint_state()` 与前进程写入状态一致。测试运行从临时目录加载既有 PCK，传入 `--test`，正式存档未加载；临时目录在全部进程结束后删除。日志为 `output/builds/pack-restart-{stash,table}-{write,read}.log`。

复现：对同一绝对临时文件路径分别执行 `write` 和 `read`，例如在原有 `--main-pack` 参数后加入：

```text
--script /绝对项目路径/Godot/three_d/tools/verify_export_restart.gd -- --test write table /绝对临时目录/texaspub-restart-table.save
--script /绝对项目路径/Godot/three_d/tools/verify_export_restart.gd -- --test read table /绝对临时目录/texaspub-restart-table.save
```

藏匿点将 `table` 换为 `stash`，使用另一份文件。写模式拒绝覆盖已有测试文件，结束后仅删除本次创建的临时目录。这里由脚本显式调用存储和恢复，未通过正式启动自动读档/暂停界面，不代表干净机器的窗口试玩、全酒馆关闭重开或原生应用验收。
