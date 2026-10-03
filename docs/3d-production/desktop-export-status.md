# 桌面导出准备与验证

更新：2026-10-03。本记录属于交付准备，不代表 Phase 5 完成。

**最新状态：官方模板已安装，macOS 独立 ZIP 已导出并完成本机启动检查。下文模板缺失为历史记录，最新证据见末尾。**

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

## 补充：World 保存/加载入口与损坏文件保护

上述跨进程脚本已进一步改为调用游戏实际 `world.save_checkpoint()` / `world.load_checkpoint()`，仅将 `world.save_path` 指向专用临时文件。藏匿点和牌桌四次进程运行再次全部通过。读回后验证暂停面板出现、移动被禁止、完整状态一致；调用实际 `resume()` 后，暂停消失，入座/探索各自恢复正确控制与摄像机。

读模式还在临时文件内注入损坏字节，调用加载入口，确认当前世界未变、`saving_enabled` 被关闭、原损坏字节保留、玩家收到损坏提示；随后恢复本次测试的有效字节。此结果验证错误加载的保护结果，未模拟磁盘写满或操作系统权限失败。日志已更新为本轮结果。

该脚本显式调用与启动相同的入口，但仍以 `--test` 阻止启动时自动访问真实用户存档，故不声称已验证发行包默认启动的文件定位。以上更新取代上一节“未通过正式启动自动读档/暂停界面”中关于暂停与加载入口的未测项；原生应用、真实窗口和干净机器仍未验收。

## 可重复构建入口

在项目根目录执行：

```sh
python3 Godot/three_d/tools/build_preview.py
```

入口刷新预设的运行资源清单，导出 PCK，再从独立临时目录执行资源检查、四酒馆最短循环、藏匿点及牌桌跨进程恢复。新增人物贴图会自动选入；不改人物源或 GLB、不提交、不推送。当前入口使用本机 Godot 路径，不是跨平台发行构建器。

本次流水线全部通过，选中 106 项资源，PCK 为 56,793,104 字节。`output/builds/preview-build.json` 记录状态、运行源码和包体 SHA256、尺寸及数量；日志为 `output/builds/preview-*.log`。构建前后运行源码指纹不一致会判失败，避免资产正在写入时错误报告稳定构建。失败时报告标为 failed，即使旧 PCK 仍在也不能作为本次通过产物。

新构建替换旧预览快照，仍不是原生应用；不扩大既有检查范围。全部牌桌与特殊出口、官方模板、Windows 构建、性能与干净机器验收仍待完成。

## 补充：四酒馆 × 四桌包内顺序通关

最短循环检查已扩展为每酒馆从货运桌依次完成账房、镜厅和余烬桌，共 16 桌；没有伪造已完成列表或补钱。每桌进入前按实际服务降低风声并付费，每桌仍进行磁盘快照恢复后继续完成。独立账目累加筹码净收益、实际加入背包的奖励价值，扣除降风声费用；每桌及公共撤离后的资产总额均一致，最终四桌完成列表也被确认。

本轮为固定种子 41、牌桌种子 301 与固定合法动作；不代表完整种子池、AI 策略或全部状态转移覆盖。315 项检查通过，0 失败。已通过 `build_preview.py` 重建当前包并完整运行资源、循环及跨进程检查，日志为 `output/builds/preview-loop.log` 等，构建报告更新为本轮快照。其他牌桌的规则运行和磁盘恢复已补证；仍未在它们的真实物理房间逐桌走路/入座，也未验证特殊出口和全物品组合。

## 2026-10-03：预约与紧急撤离包内验证

在各酒馆合法完成四桌的状态上，通过 RunCheckpoint 建立独立恢复分支，分别执行预约接应、丢现金、丢贵重物，共 12 个特殊撤离样本。预约使用真实服务预付费用，拒绝重复预约；准备后的状态再次恢复，再执行撤离。独立资产账目扣除预付、降风声、出口费和牺牲资产，结果与金库一致；撤离不能重复。紧急出口依赖真实牌桌完成及奖励产生的已知线索/贵重物，没有伪造背包或风声。

首次检查屋顶酒馆预约失败，因为四桌结束时风声超过路线限制；这是正常规则限制。本轮在预约前通过实际酒保降风声服务付费，未修改路线门槛。四店三类样本均通过。当前固定预约只覆盖各店当前 offer，不能声称 16 个具名路线全部通过；通行证的楼梯/河边路线、预约过期与高风声失败反馈仍需进一步包内验证。

完整 `build_preview.py` 实跑通过，循环 396 项检查、0 失败，资源与跨进程恢复亦通过。证据为 `output/builds/preview-loop.log` 和 `preview-build.json`，本次报告替代上轮失败构建状态。仍为资源包检查，未产出原生应用。

## 2026-10-03：macOS 独立应用首次导出

GitHub 网络恢复，`main` 的积累提交已推送至 `eb9531f`。从 Godot 官方 godot-builds 的 4.7.2-stable Release 下载 `Godot_v4.7.2-stable_export_templates.tpz` 和 `SHA512-SUMS.txt`；完整档案 SHA512 与官方清单一致，内部 `templates/version.txt` 为 `4.7.2.stable`。只安装当前所需的 `macos.zip` 和版本文件，没有覆盖已有模板。官方档案保留于 `output/builds/`。

使用现有 `macOS Preview` 预设成功导出 `output/builds/TexasPub.zip`，约 112 MiB，日志 `native-export.log` 无 ERROR/WARNING。解压结果为 `output/builds/macos-preview/Godot德扑酒馆.app`，恢复 ZIP 中记录的执行权限。该包包含当前未冻结的人物样板，仅作为内部预览，未签名/公证。

实际启动导出的 `Contents/MacOS/Godot德扑酒馆`：工作目录 `/tmp`，不调用已安装编辑器，使用包内嵌资源；无窗口 120 帧、窗口 240 帧均退出码 0。测试带 `--test` 防止访问正式存档。首次尝试传入 `--path` 被发行模板拒绝，因此改为切换工作目录，未自编模板绕过。成功日志为 `native-startup.log`（引擎版本行）、`native-window-startup.log`（窗口运行无控制台输出）；窗口检查未留截图，不据此宣称视觉或性能通过。

本机可以直接打开上述 `.app` 试玩，默认运行会使用正常存档。只进行隔离启动检查时，以绝对程序路径执行 `-- --test`。资源包构建命令暂只构建 PCK；原生导出需单独执行本文前述 `--export-release` 命令。

剩余交付验收：Windows 包、Mac/Windows 目标机表现、30 分钟运行、干净机器启动与通关、全部特殊路线及真实输入操作、签名/公证策略。官方模板缺失已解决，不能再作为当前阻碍。

## 2026-10-03：Windows x64 首次导出

从此前已匹配官方 SHA512 的模板档案安装 Windows release x64 和 console 模板，新增 `Windows Preview` 预设。同步调整资源包构建入口，自动刷新 Mac/Windows 两份资源选择。导出成功，`windows-export.log` 无 ERROR/WARNING；产物 `output/builds/windows-preview/TexasPub.exe` 为 PE32+ GUI x86-64，资源在同目录 `TexasPub.pck`。

Mac 上的 Godot 读取 Windows PCK，26 项资源加载及 396 项规则循环检查通过。完整预览构建命令仍通过。Windows EXE 未在 Windows 真机运行，不能称为 Windows 启动或性能验收。

交付准备包 `output/builds/TexasPub-Windows-preview.zip` 含 EXE、PCK、试玩说明和文件 SHA256/尺寸清单。说明源为 `docs/3d-production/windows-preview-readme.md`。两文件需保持同目录。本包未签名，当前建模样板未冻结，只用于内部试玩；Windows 实机、目标硬件与干净机器验收仍待执行。

## 2026-10-03：八条通行证路线

新增包外 `verify_export_routes.gd`，四酒馆分别验证后厨楼梯和河边接驳，共 8 条路线。使用合法基线种子 0 保留完整货架，按桌序真正完成牌局直到目标通行证上架；通过购买服务花钱/行动点，再使用通行证揭示线路并消耗物件。未知路线拒绝撤离、通行证不能重复使用、checkpoint 恢复后线路仍已知且物件不复生、最终撤离与独立资产账目一致，不能重复入账。没有直接写库存或解锁标记。

170 项检查通过，0 失败；已加入 `build_preview.py` 的 `preview-routes` 步骤，本轮完整流水线通过。日志为 `output/builds/preview-routes.log`。基线种子样本不能代表所有随机货架组合；仍是包内规则调用，不是玩家走到楼梯/码头触发物理锚点。具名预约路线变体、有效期、风声边界及物理输入仍待测。仅新增工具检查，运行代码/模型未变，无需因此重导原生应用。

## 2026-10-03：具名预约与真实轮次边界

路线检查继续扩展：在实际种子 1–100 中找到各店两种 offer 的自然出现场景，先正常完成货运桌取得预约线索，真实服务预付预约费用，核对具名 ID，恢复 reservation 后撤离并核对独立资产账目。四店 8 个具名预约全部通过，加上前述 8 个通行证特殊路线，当前配置中的 16 条具名路线都有包内正常撤离样本；这不是完整转移覆盖或物理出口可达验收。

预约原状态继续实际完成后续牌桌，按结算推进 search_index，不直接改轮次。烟雾、屋顶和霓虹的 6 个 offer 超期后提示“预约已过期”，拒绝撤离且完整状态不变；有效期当天不被判过期。高层酒馆两个 offer 在货运桌后预约，第四桌结束恰好到有效期末轮，因此本场景验证截止边界，没有到达其超期状态，不宣称这两种超期已测。

完整构建流水线通过，路线脚本共 542 项检查、0 失败；日志 `output/builds/preview-routes.log`。工具改动未改变游戏规则或美术，无需重做现有原生包。未覆盖全部种子、预约预付后风声升高的真实失败场景、玩家走到对应门口的输入与视觉反馈。

## 2026-10-03：包内空间与出口射线

复用现有 `spatial_interaction_test.gd` 作为包外脚本运行，PCK 实际角色移动通过：上层后厨楼梯、地面库房、下层码头坡道均可到达；藏匿点物件射线操作、动画状态、货架购买和牌局结果提示也通过。47 项检查、0 失败，日志 `output/builds/pack-spatial.log`。没有截图采集，不把数值检查当作视觉验收。

新增 `verify_export_exit_rays.gd`：四个酒馆规则状态下，从预设近门站位瞄准货梯、后厨、河边和两个紧急口，共 20 个锚点样本；实际 `player.can_interact` 和 `request_action` 通过。对应撤离面板选中准确路线；未取得线索时按钮禁用、显示提示，强行调用确认也不会修改完整规则状态。共 104 项检查、0 失败，已纳入 `build_preview.py`，完整流水线通过；日志 `preview-exit_rays.log`。

注意四家酒馆当前仍使用同一建筑布局，本次不能证明四套独立建筑。出口射线从设置的位置起测，不是连续行走测试；既有行走测试只在烟雾酒馆执行。合法线路解锁后从真实出口确认撤离、其他酒馆逐段步行、门口提示视觉仍待端到端验收。工具改动未改变运行源，原生包不因本轮变化失效。

## 2026-10-03：合法解锁至物理出口确认

出口射线脚本扩展 20 个合法交互样本：每个酒馆分别创建独立晚间，通过真实牌桌解锁、付费降风声、购买/消耗通行证或预约服务取得线路；紧急出口使用真实牌桌奖励。然后从预设近门站位瞄准实际锚点，调用必须通过物理射线校验的 request_action，核对对应线路、确认按钮可用、面板准确显示最终到账。确认后世界回到藏匿点、晚间结束、金库按报价入账、last_result 记录正确线路；再次确认不产生状态变化。

连同未知线路拒绝，当前出口脚本 446 项检查、0 失败；完整构建流程通过。日志 `preview-exit_rays.log`。准备阶段用真实规则操作但不通过每个商店按钮/桌面 UI；角色站位由脚本设置，没有连续从大厅走到门口，也未模拟键盘 E 事件。不要把该样本扩大为全输入或连续行走验收。没有修改规则、空间网格或人物源，原生包仍为既有运行代码快照。

## 2026-10-03：连续行走与真实窗口 E 键

出口脚本进一步扩展：四家酒馆规则状态下，从设定的后勤走廊入口 `(10, 0.02, -2.7)` 开始，角色通过实际 move_forward 输入连续走向地面货梯、上层后厨、下层码头，共 12 条行走样本；检查上层/下层角色高度。入口为测试固定起点，没有从酒馆出生点绕过牌桌走到走廊；两个紧急口仍采用预设近门站位。

真实窗口模式下使用 E 键事件，经角色 `_unhandled_input` / interaction_requested / World 到达结算面板，共 20 个合法出口样本；后续确认仍调用面板方法而非模拟鼠标。490 项检查通过、0 失败，退出码 0，无 ERROR/WARNING。日志 `output/builds/exit-window-input.log` 记录 Apple M5、Metal 4.0 / Forward+，不是帧率或长时稳定性测量。

初次输入注入失败属于测试事件缓冲：发送同一事件对象后过早改为松开；修正为按下后 flush_buffered_events，松开使用独立 duplicate 对象。中途失败检查已主动停止，最终证据来自完整清洁运行，没有修改游戏输入代码。无窗口检查使用射线调用分支，不能当作 E 键输入证据；窗口分支才负责 E 键。

随后完整无窗口构建流程再次通过；出口检查为 510 项（多出射线调用分支断言），日志 `preview-exit_rays.log`。两种模式的断言数量不同，不能相加为状态转移覆盖。

## 2026-10-03：窗口长时巡回启动

新增 `soak_preview.gd`，拒绝无窗口或缺少 `--test` 的启动。脚本使用当前 PCK，真实窗口依次巡回各牌室、库房、后厨、码头和藏匿点；每轮通过实际牌局动作、服务降风声、结算和公共撤离推进，不直接伪造完成表。以固定视角站位轮换，不模拟物理行走，也不在原生 release EXE 中运行。

每 10 秒写帧回调间隔 median/p95、引擎静态内存、显存和节点数，附引擎、CPU/GPU、窗口尺寸、进程 ID 与运行状态。静态内存不是 RSS，帧回调间隔含系统调度/显示节奏，不能单凭它宣布中端机 60 fps 或无内存泄漏。

30 秒预检已实际完成：39 项检查、0 失败，退出码 0；日志 `soak-smoke.log`，报告 `soak-smoke.json`。随后已启动目标 1800 秒正式窗口巡回，输出 `output/builds/soak-30min.log` 与 `soak-30min.json`；**本节记录启动，不代表 30 分钟已通过**。结束后需核对退出码、完整时长、日志、内存与帧时间走势。运行用 `--test` 不读写正式存档。

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /tmp --main-pack "$PWD/output/builds/TexasPub-preview.pck" --script "$PWD/Godot/three_d/tools/soak_preview.gd" -- --test --soak-seconds=1800 "--soak-output=$PWD/output/builds/soak-30min.json"
```

新增离线汇总工具 `Godot/three_d/tools/analyze_soak.py`，运行 `python3 Godot/three_d/tools/analyze_soak.py` 后生成 `output/builds/soak-analysis.json`。按同一家酒馆、同一空间阶段比较帧回调与内存，保存原始报告 SHA256；不会把不同场景的节点数差异直接当成泄漏。完成状态、完整时长、零失败同时满足才记录完成，且目标至少 1800 秒才算 30 分钟样本。五项完成边界检查通过；当前读取到 510 秒、仍在运行、0 失败，汇总正确标记未完成。最终仍需单独核对进程退出与日志。

## 2026-10-03：30 分钟窗口巡回完成

正式进程 PID 39171 正常退出，退出码 0。实际时长 1800.001 秒，300 项检查、0 失败；完整日志无 ERROR/WARNING。Apple M5 / Metal Forward+，窗口 1376×768，共 179 个十秒采样窗口。原始报告 `output/builds/soak-30min.json`，日志 `soak-30min.log`，离线汇总 `soak-analysis.json`。

所有采样窗口中最差 p95 帧回调间隔为 5.642 ms；引擎静态内存范围 198.574–200.684 MiB。28 个同酒馆同空间阶段有重复巡回样本，其节点数差值全部为 0，静态内存首末差值范围 −0.242 至 +1.399 MiB。当前样本未出现节点累积；这些数据不足以证明没有内存泄漏，仍缺进程 RSS/GPU 帧时间及更多重复周期。

此结果证明当前 PCK 在本机 Godot 引擎的脚本巡回中运行满 30 分钟并正常退出。没有物理连续行走或真人输入，也不是原生 release 包、Windows 或目标中端机器的长时验收；不能据此宣布 Phase 3/5 完成。

原始报告 SHA256：`3c8383c2e5ad627858e1e22b0c1d2bb9119c8c60880e4d7a019af156a1985cdd`。

## 2026-10-03：原生应用巡回入口预检未成立

尝试从 `/tmp` 启动既有 Mac release 应用，以 `--script` 指定外部巡回脚本和 30 秒目标。进程实际运行超过 50 秒，但未生成报告，日志为空；没有证据表明进入脚本。已终止本次测试创建的 PID 46773，不计为 30 秒或原生长时测试通过。后续原生自动巡回应使用单独测试构建内置入口，或通过真实输入驱动既有应用，不能直接沿用编辑器外部脚本启动方式。

巡回报告新增实际 executable_path 与 template_runtime 字段，便于后续明确区分引擎加载 PCK 和导出模板运行。

## 2026-10-03：原生模板测试包预检通过

新增 `build_native_soak.py`，将运行资源复制到临时项目，仅在副本把巡回脚本转换为 Node 场景入口，导出独立 `TexasPub-native-soak.zip`。源项目入口与既有试玩包不变；构建前后核对运行资源指纹。首次副本缺图标导致导出失败，补齐后导出通过；自定义主循环尝试未建立入口，改为明确测试主场景。

首次原生场景预检进入巡回，但首帧延迟跳过中间阶段，错误尝试未解锁牌桌并正常报失败。巡回现按顺序补齐经过的阶段；修正后 30.002 秒、39 项检查、0 失败、退出码 0、日志无 ERROR/WARNING。报告记录 template_runtime=true 与实际 .app 二进制路径。日志/报告为 `native-soak-smoke.log/json`。

该测试包是 release 模板内置自动化入口，不能代替正式试玩入口、真人行走或干净机器验收。接着启动目标 1800 秒巡回，报告 `native-soak-30min.json`，日志 `native-soak-30min.log`；启动不代表完成。

原生巡回 PID 48408 已确认运行。另启 `monitor_soak_rss.py`，每十秒用 macOS ps 采集该 PID 的进程 RSS，并核对二进制路径与报告 PID，观察结果写入 `native-soak-rss.json`。观察从报告约 50 秒开始，首个 RSS 约 215.92 MiB；缺少启动前 50 秒数据，不能作为完整启动峰值。RSS 不等于显存或引擎静态内存，最终需与同场景重复采样共同分析。

原生报告独立汇总命令：`python3 Godot/three_d/tools/analyze_soak.py --source output/builds/native-soak-30min.json --output output/builds/native-soak-analysis.json`。默认命令仍汇总已完成的引擎 PCK 巡回。输出包含原始文件绝对路径和 SHA256，已核对两份报告没有混用，原生运行中报告仍标记未完成。

## 2026-10-03：原生 release 模板 30 分钟巡回完成

独立自动巡回测试包 PID 48408 正常退出，退出码 0；1800.002 秒、300 项检查、0 失败，完整日志无 ERROR/WARNING。报告确认 template_runtime=true，执行文件为独立测试 .app；Apple M5，窗口 1376×768。原始报告 `output/builds/native-soak-30min.json`，日志 `native-soak-30min.log`，汇总 `native-soak-analysis.json`。原始报告 SHA256：`906f8f662223193ed783dd0a6508189c133392e705e14fe844a0ea2c02616238`。

28 个同酒馆同空间阶段跨巡回重复采样，节点数首末差值全部为 0。最差采样窗口 p95 帧回调间隔 5.983 ms；它不是 GPU 耗时或目标中端机帧率。release 模板的 MEMORY_STATIC 全为 0，属于本次无法取得有效读数，不能解释为零内存占用或没有增长。

RSS 观察进程正常结束（process_ended、退出码 0），175 个样本，范围 198.00–225.34 MiB，首值 215.92 MiB、末值 213.23 MiB。观察从约 50 秒开始，缺少启动峰值；不同场景切换会改变占用，本次不能证明无泄漏。原始记录 `output/builds/native-soak-rss.json`。

这项结果补齐本机原生 release 模板自动巡回证据。独立测试入口使用脚本推进合法牌局和固定视角，不等同正式玩家入口的 30 分钟真人行走测试；Windows 实机、干净机器、目标中端硬件及最终精细模型仍待验收。测试没有读写正式存档，也没有提交另一模型正在修改的美术资源。Phase 3/5 仍未完成。

汇总工具已修正静态内存可用性：同场景样本含零读数时，标记 static_memory_available=false，首末值与差值输出 null，避免误读为内存没有增长。用两份真实报告及混入零读数的边界检查通过；重新生成汇总，原始测试记录保持不变。

## 2026-10-03：Mac 试玩包补齐独立说明

发现 TexasPub.zip 原先只有应用文件，没有试玩说明。新增 package_macos_preview.py，将 macos-preview-readme.md 作为包根目录 README.md，并生成 build-manifest.json，记录应用各文件与说明的字节数和 SHA256。包内明确 test_harness=false、clean_machine_verified=false，不把独立测试包验收转移到玩家包。工具支持重复执行替换说明和清单，不累加同名条目。实际打包通过，逐个核对应用字节与 ZIP 执行权限完全一致，ZIP CRC 校验通过；未重新导出或替换正在精修的美术资源。

正式资源包检查新增主场景与自动巡回入口隔离断言。从实际 Mac 玩家 ZIP 提取内嵌 PCK，28 项检查、0 失败、退出码 0。独立巡回包反例被两项断言正确拒绝、退出码 1；初次 FileAccess 未识别导出资源重映射，改为 ResourceLoader.exists 后反例通过。ZIP 二进制权限为 0755。上述检查不替代干净机器运行。

## 2026-10-03：存档矩阵修复进入 Mac 试玩包

重新导出 TexasPub.zip，官方 release 导出正常退出、日志无 ERROR。资源指纹逐项与 20261003-124036 的完整回归报告一致。提取内嵌 PCK 检查 28 项、零失败；从 /tmp 启动原生二进制无窗口 120 帧正常退出，另以窗口 240 帧正常退出，日志无 ERROR。测试带 --test，不访问正式玩家存档。操作说明注明异常变换保护，并重新嵌入 README 与校验清单；清单各文件 SHA256 逐项核对通过。

新 ZIP SHA256：`ecb238da5207c5067182a53bb5e75dcc0e35af6384cc220856d9b7d4b514e67f`；旧包保留为 output/builds/TexasPub-before-transform-fix.zip。新解压应用在 output/builds/macos-transform-preview/。本次仅本机短时启动，不继承先前独立巡回包的 30 分钟验收，不证明干净机器或目标中端性能。Windows 包尚未刷新该修复。

## 2026-10-03：Windows 预览同步恢复矩阵修复

Windows release 导出正常退出、日志无 ERROR；EXE 的 PE x64 头检查通过，运行资源源码指纹与 20261003-124036 全量回归一致。Godot 在 Mac 上加载新 Windows PCK 检查 28 项资源/入口、零失败，不能当作 Windows EXE 已运行。重建 TexasPub-Windows-preview.zip，包含 EXE、PCK、更新说明及校验清单；ZIP CRC 和逐文件 SHA256 全部核对。旧包保留 TexasPub-windows-before-transform-fix.zip。新 ZIP SHA256：`23536e52171cb9782f6c2d18d365738fa54e93580341622e14400f52277b18e7`。Windows 实机启动、默认用户目录存档、渲染与长时测试均未验收；manifest 保持 windows_runtime_verified=false。

## 2026-10-03：当前试玩截图集

新增 capture_preview_media.gd，以 --test 和绝对输出目录在窗口加载实际 Mac 玩家 PCK，截取藏匿点、出发面板和通过真实准星入座买入后的牌桌，共三张 1376×768 PNG。已逐张视觉检查，牌桌等待正常输入延迟结束后再截取，行动和费用提示可见。图片、来源 PCK SHA256、尺寸及说明打包为 output/builds/TexasPub-preview-media.zip。这是编辑器加载实际包资源的窗口截图，不是原生应用截图或最终高精美术宣传材料。现有基础人物与三人精修样板仍混用，风格统一尚未完成。未生图、未修改玩法或另一模型美术。

截图集扩展为六张：新增桌终输赢强调、普通出口费用/到账报价和返回藏匿点金库。通过合法玩家弃牌和生产对手 AI 完成牌桌、离座结算，再调用现有撤离面板确认；没有伪造金额。三张结果画面已逐张检查，牌桌亏损 -20、出口费 57、到账 223 与金库 1123 一致。此样本未步行到实体出口，不作为物理路线验收。截图清单哈希与 ZIP 已同步更新。


## 2026-10-03：连续转向存档误拒绝修复包

Mac 与 Windows 官方 release 导出均退出 0，日志无 ERROR；原包分别保留为 TexasPub-before-rotation-fix.zip 与 TexasPub-windows-before-rotation-fix.zip。新版玩家入口不变，指南和清单已更新。两份实际 PCK 的 28 项资源检查、窗口下 9 项真实鼠标转向/旧微小误差/明显缩放拒绝检查均通过。这由本机 Godot 引擎加载导出 PCK 执行，不是 Windows 原生输入证明。

Mac 新应用从 /tmp 以 --test 启动，原生 headless 120 帧退出 0，无 ERROR；Windows EXE 的 PE/x64 头、ZIP CRC 和清单校验通过，windows_runtime_verified 继续为 false。release 的 GDScript 是编译资源，不能用原 .gd 路径的 FileAccess 文本 hash 证明源码一致；该尝试不成立，改用实际包运行修复专项，未把失败的文本校验记为通过。

旧包创建、新包读取的七类存档全部通过，14 个独立进程退出 0，旧夹具字节未变。证据：output/builds/upgrade-checks/20261003-133555/report.json。覆盖 stash/table/search/shopping/reservation/extracted/collateral 样本，不证明所有历史矩阵或真人重启。

- Mac ZIP SHA-256：`ce07bdf49f6d331844dec30870aad43208d9dc8984988ff16a6c71de34fb4bd7`。
- Windows ZIP SHA-256：`b6911c4cfc7eade90d41ed7a70f9a7fc4668896d08219bb00687a182678dde34`。
- 日志：rotation-macos-resources.log、rotation-macos-mouse.log、rotation-windows-resources.log、rotation-windows-mouse.log、rotation-native-check.log。

新版玩家包未重新跑 30 分钟巡回；已有长时报告仍属于旧版本测试包，不能沿用为本次新版完成证明。


## 2026-10-03：最佳牌型展示复制优化包

在保留策略、试验数、牌型比较与 RNG 的条件下，evaluate_best_hand 仅为最终最佳组合创建展示牌副本。71 个 Godot 套件、20 个 Python 测试通过，完整报告为 output/3d/regression/20261003-201735/report.json；该轮源码/资产指纹不变。CPU 样本及未达整帧预算的限制见 phase-3/performance-budget.md，不能据本更新宣称 60 fps 或美术性能封版。

Mac/Windows 官方 release 导出退出 0，无 ERROR。两份实际 PCK 各自通过 28 项资源检查及 1414 个输入、4242 项完整牌型结果/输入不变/返回牌不共享字典检查。外部校验脚本使用开发目录的测试牌型 fixture，但 Poker 类实际从导出 PCK 加载。Mac 新原生应用从 /tmp 以 --test 运行 headless 120 帧，退出 0，无 ERROR；Windows 原生执行仍未验证，清单继续为 false。ZIP 清单和 CRC 已更新，旧包保留为 before-hand-eval-optimization 备份。

- Mac ZIP SHA-256：`2a2a9cbf515427456149f357af0c9ca7a5da9f6ad2644cf448ad6a31552d1235`。
- Windows ZIP SHA-256：`706701cefcb79c7dcce54bf8bee1e163af710d40b3852087c244acfb5e0e2529`。
- 日志：hand-eval-macos-resources.log、hand-eval-macos-hands.log、hand-eval-windows-resources.log、hand-eval-windows-hands.log、hand-eval-native-check.log。

旧版本 30 分钟记录没有重记为当前版本长时通过，本轮尚未重新做该项验收。

优化包另通过旧包创建、新包加载的七类存档样本，14 个独立进程全部通过且原夹具字节不变：output/builds/upgrade-checks/20261003-202505/report.json。范围仍为既有七类代表样本，不证明任意历史存档。


## 2026-10-03：AI 直接七张牌评分包

AI 使用只读 rank/tiebreak 评分，保留 85 次原有洗牌、种子、随机数消耗和公共完整牌型/展示接口；完整河牌的玩家评分只计算一次。完整回归 output/3d/regression/20261003-203614/report.json，73/73 个 Godot 套件、20/20 个 Python 测试通过，源码/测试/运行资产指纹未变。三次本机 CPU 探针中位 4.509–4.692 ms、最大 6.123–6.823 ms，不等于最终画面 FPS 或目标设备验收。

Mac/Windows release 导出均退出 0，日志无 ERROR。两份实际 PCK 各自通过 28 项资源检查、20691 项七张牌与原逐组合评分对照、34 组/66 项精确 equity 对照。七张牌校验使用外部固定测试 fixture，实际 Poker/Opponent 类从 PCK 加载。Mac 原生应用从 /tmp 以 --test 运行 headless 120 帧退出 0，无 ERROR。Windows x64 头、ZIP CRC、文件清单校验通过，但 Windows 原生运行仍未验证。旧包保留 before-seven-card-optimization 备份。

- Mac ZIP SHA-256：`ed19f54e3ca687e4488ef13ecaf00c91916ef4dfab7109c512bd1c90e25cff08`。
- Windows ZIP SHA-256：`86aff2e7db8ac5c8d779f58d91e2e375dc9d152c4bfea68a68e82bb5115bc12f`。
- 日志：seven-card-macos-resources/score/equity.log、seven-card-windows-resources/score/equity.log、seven-card-native-check.log。

本轮未将旧版 30 分钟记录重记为新版长时通过；Windows 实机、干净机器和最终精细资产验收仍未完成。

## 2026-10-03：交互动画恢复修复包

桌面包已包含源码提交 `e831210` 的物件/皮箱旧 Tween 取消逻辑。最终源码回归 `output/3d/regression/20261003-211539/report.json`：74 个 Godot 套件、20 个 Python 测试全部通过、运行期间源码/资产指纹未变。本轮只重新导出与验证包，没有重复完整源码回归。

官方 macOS/Windows release 导出均退出 0，日志没有 ERROR/脚本解析错误。外部专项脚本仅改报告输出路径，世界与规则实际加载自对应 PCK：两份各 28 项检查通过，包含恢复后旧动画不再改写画面、非法恢复保持动画、新交互可继续。此范围不是完整打包玩法或任意历史存档验收。

Mac 原生应用从 `/tmp` 以 `--headless --quit-after 120 -- --test` 启动，退出 0，无 ERROR。Windows PCK 在 Mac Godot 引擎中验证，不代表 Windows EXE 原生运行。两 ZIP 的 CRC 与内嵌文件大小/SHA256 清单全部核对；Windows ZIP 内容与导出完成后的 exe/pck/readme 文件逐字节相同。

- 当前 Mac：`output/builds/TexasPub.zip`，SHA256 `c64d51211987db97219f472a4e8dd00b0bd2c5b60dc4bc6e1f52e41be12f7d7c`。
- 当前 Windows：`output/builds/TexasPub-Windows-preview.zip`，SHA256 `12fe65bf535c828666bf91782c032d6d892aa7ed05c2f9b09a8aef64cc7405a0`。
- Mac 解压核验副本：`output/builds/macos-animation-restore-preview/`。
- 原有包保留 `TexasPub-before-animation-restore.zip` 与 `TexasPub-Windows-preview-before-animation-restore.zip`。
- 本轮日志：`animation-restore-macos-export.log`、`animation-restore-windows-export.log`、`animation-restore-macos-test.log`、`animation-restore-windows-test.log`、`animation-restore-native-check.log`。包内专项原始 JSON 为 `animation-restore-macos-test.json` 与 `animation-restore-windows-test.json`。

本地包包含当前工作区三个人物精修样板及其游戏接入；这些美术改动仍未纳入场景开发的 Git 提交，不能仅按 Git SHA 复建完全相同美术包。没有上传 GitHub Release。Windows 实机、干净机器、目标中端性能、当前版 30 分钟和最终高保真美术仍未完成，旧版长时报告不重标为本版通过。

## 2026-10-03：背包 3D 实物预览包

背包只展示当前持有物品，有现有模型的道具显示一次性 3D 近景，无模型贵重物保留符号与名称。没有新增规则或物品。导出选择加入 `item_preview.gd`；源码完整回归 `output/3d/regression/20261003-212924/report.json` 75/75 Godot 套件与 20/20 Python 测试通过、运行期间源码/资产未变。

两平台 release 导出退出码 0，无 ERROR。两份实际 PCK 在本机有窗口 Metal 引擎中各通过 9 项专项，包括持有列表、快照不变、重复打开、旧实例释放、预览首帧后停止刷新。Mac 包内截图 `output/builds/inventory-preview-macos.png` 已检查，实物打火机与未建模袖扣的名称/符号正常显示。Mac 原生应用从 `/tmp` 以隔离测试模式 headless 运行 120 帧退出 0；Windows EXE 仍未在 Windows 上执行。

当前 ZIP CRC 与内嵌大小/SHA256 清单验证通过：

- Mac `output/builds/TexasPub.zip`：`9ef0179b56d1168dae64d4db887286512dfc061c98ff1a172e3d98292dcd7dff`。
- Windows `output/builds/TexasPub-Windows-preview.zip`：`46a1246b6faf1ff9e91e29700612cfe5f354cda9950d293eaae58062d6676939`。

日志为 `inventory-preview-{macos,windows}-export.log`、`inventory-preview-{macos,windows}-test.log`、`inventory-preview-native-check.log`。Mac 解压核验副本在 `macos-inventory-preview/`；旧 ZIP 保留 `before-inventory-preview` 备份。资源仍包含另一模型未提交的当前人物样板；源 Git SHA 不代表美术包可仅从已提交文件完整复建。未上传 GitHub Release，未重复旧版 30 分钟记录或声称目标平台性能通过。

## 2026-10-04：五类灯光样板预览包

五类环境与点光源配色已接入场景切换和读档。保留开关状态、光源能量数值、规则与碰撞。主工作区完整回归 76/76 Godot 套件和 20/20 Python 测试通过，报告 `output/3d/regression/20261004-014228/report.json`，期间指纹不变；独立导出副本也完成同等回归，报告 `output/builds/lighting-validation-source/output/3d/regression/20261004-014455/report.json`。副本复制后与已通过工作区的源码/资产一致，固定指纹记录在 `output/builds/lighting-snapshot-source-sha256.json`。

Mac、Windows release 导出退出 0；两份实际 PCK 各通过 56 项 headless 灯光检查，Mac PCK 再通过有窗口 Metal 渲染 56 项，五类截图 `output/builds/lighting-package-*.png` 已生成，霓虹截图已核对。Mac 原生程序从 `/tmp` 以 `--test` headless 运行 120 帧退出 0；首次检查误传官方模板不支持的 `--path` 参数，失败日志保留为 `lighting-native-check.log`，修正调用后的通过日志为 `lighting-native-check-retry.log`。没有修改引擎或游戏来绕过限制。

两份 ZIP CRC 与内嵌文件大小/SHA256 清单核验通过：

- Mac `output/builds/TexasPub.zip`：`34ee2226df60a2185ada27af14e5c80633d03d0193c6bd5cbf07b84a89f2fc1a`。
- Windows `output/builds/TexasPub-Windows-preview.zip`：`62b69cc2ef5bdc8aa46ef282deeebdcabbf5aaffe54fcbee705713e824311ae8`。

导出/专项日志为 `lighting-{macos,windows}-{export,test}.log`，有窗口日志 `lighting-package-capture.log`，校验汇总 `lighting-package-verification.json`。Mac 解压副本 `macos-lighting-preview/`，上一版两份 ZIP 保留 `before-lighting` 备份。当前包包括外部模型未提交的三个人物 36 骨骼样板；仅凭 Git 提交不能完整复建相同美术包，未上传 GitHub Release。

Windows PCK 在 Mac 引擎中验证不等于 Windows EXE 实机通过。独立建筑、最终高保真美术、Windows/干净机器以及本版长时性能仍需后续验收；旧版 30 分钟结果不重标为本版通过。
