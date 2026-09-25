# 素材许可证清单

> 本清单只摘录项目内已有证据，不构成法律建议。所有未明确标记的素材都需要主 Agent 单独确认来源与许可后再进入正式发行。

## 方法论与证据标准

- **有效证据**：LICENSE 文件、README 中的作者/来源声明、NOTICE 文件、代码注释中明确写出的许可证条款。
- **无效证据**（不作为商用依据）："免费"、"可下载"、"项目里已有"、文件存在于某目录、文件日期早于项目其他文件。
- **自制品认定**：必须有 README 或其他项目内书面记录明确说明为自制或 AI 生成，才标注为自制品；否则写"来源待确认"。
- **只归纳原文**：使用条件、署名要求、再分发限制等均原文摘录，不做推论。

---

## 1. 扑克牌（52 张 + 2 张鬼牌 + 卡背）

| 字段 | 内容 |
|---|---|
| **素材/素材组** | 扑克牌 PNG（52 张数字牌 + J/Q/K + 2 鬼牌 + 卡背） |
| **覆盖路径** | `assets/cards/*.png`（56 个 PNG，游戏实际加载位置）；同套文件 MD5 完全一致地复制到 `Godot/Cards/*.png` 和 `Godot/素材/playing-cards-assets-master/png/*.png` |
| **来源或作者** | 来源：https://code.google.com/p/vector-playing-cards/（原始 SVG，public domain）；经处理去边框后转为 PNG |
| **许可证名称** | Public Domain（原始 SVG）；处理工具为 MIT License（见下方说明） |
| **本地证据位置** | `Godot/素材/playing-cards-assets-master/README.md`（来源说明）；游戏加载路径 `src/main.js:53, 3620`（`../assets/cards/`）；三处文件 MD5 已逐张验证一致 |
| **明确写出的使用条件** | README 原文："*Courtesy of https://code.google.com/p/vector-playing-cards/ (public domain)*"；"With some additional processing to remove borders of cards." |
| **未确认事项** | 处理后的 PNG 是否仍属于 public domain（需确认去边框处理是否产生新的版权）；其他两处副本（`Godot/Cards/`、`Godot/素材/...`）在打包/发行时建议删除以避免许可范围混淆 |

**附：处理工具许可证**

`Godot/素材/playing-cards-assets-master/LICENSE`（MIT License，Copyright (c) 2018 Howard Yeh）覆盖 svg2png.js 等处理工具，不覆盖 card image 本身（card image 来自 vector-playing-cards public domain）。

---

## 2. 字体

| 字段 | 内容 |
|---|---|
| **素材/素材组** | 全部字体（CSS 变量引用，无外部字体文件） |
| **覆盖路径** | `styles/foundation.css`（`--ui-font`、`--pixel-font`、`--display-font`） |
| **来源或作者** | 系统内置字体（无外部来源） |
| **许可证名称** | N/A — 无外部字体文件；CSS 中引用的是操作系统自带字体 |
| **本地证据位置** | `styles/foundation.css` 第 23–25 行（font-family 声明）；无 `@font-face` 规则；无字体文件存在于项目内 |
| **明确写出的使用条件** | 无外部字体文件，无对应许可证；系统字体随操作系统授权 |
| **未确认事项** | 无。未发现外部字体文件或 @font-face 引用。 |

**字体清单**（`styles/foundation.css` 第 23–25 行）：
- `--ui-font`：`"Avenir Next", "Segoe UI", "Helvetica Neue", Arial, sans-serif`
- `--pixel-font`：`"Baskerville", "Palatino Linotype", "Book Antiqua", Georgia, serif`
- `--display-font`：`"Baskerville", "Palatino Linotype", "Book Antiqua", Georgia, serif`

---

## 3. 模型（3D Blender 文件）

| 字段 | 内容 |
|---|---|
| **素材/素材组** | stash-noir Blender 场景 |
| **覆盖路径** | `assets/blender/stash-noir/stash-noir.blend` |
| **来源或作者** | 自制（项目成员制作） |
| **许可证名称** | 未记录 — 该目录无 LICENSE 或其他许可证声明文件 |
| **本地证据位置** | `assets/blender/stash-noir/README.md`（描述为"根据本次提供的皮箱／木桌参考图制作的第一版可编辑 3D 静物场景"；未提及第三方授权） |
| **明确写出的使用条件** | README 中未写出任何许可证条款 |
| **未确认事项** | 自制场景的默认许可未声明（建议补充 LICENSE 文件）；`assets/blender/` 下无其他 .blend/.glb/.gltf 文件 |

---

## 4. 音频（BGM，OGG 格式）

| 字段 | 内容 |
|---|---|
| **素材/素材组** | 背景音乐 OGG 文件（9 个） |
| **覆盖路径** | `assets/audio/bgm/*.ogg` |
| **来源或作者** | 来源待确认 |
| **许可证名称** | 未确认 — 该目录下无 LICENSE、README 或其他许可声明 |
| **本地证据位置** | `assets/audio/README.md`（仅描述目录结构和命名规范，不涉及音频来源或授权） |
| **明确写出的使用条件** | 无 |
| **未确认事项** | **所有 9 个 BGM 文件的来源、作者和许可证均未确认**，包括：menu-theme.ogg、stash-loop.ogg、tavern-floor.ogg、tavern-high-rise-suite.ogg、tavern-neon-poker-club.ogg、tavern-rooftop-club.ogg、table-pressure.ogg、summary-success.ogg、summary-failure.ogg |

---

## 5. 视频（MP4 格式）

| 字段 | 内容 |
|---|---|
| **素材/素材组** | 循环视频背景 MP4 文件（8 个） |
| **覆盖路径** | `assets/videos/*.mp4`（8 个文件，详见 manifest.json） |
| **来源或作者** | 来源待确认 |
| **许可证名称** | 未确认 — 该目录下无 LICENSE、README 或其他许可声明 |
| **本地证据位置** | `assets/videos/README.md`（仅描述命名规范和同步脚本，不涉及视频来源或授权） |
| **明确写出的使用条件** | 无 |
| **未确认事项** | **所有 8 个 MP4 文件的来源、作者和许可证均未确认**，包括：menu-title-bg.mp4、stash-loop.mp4、tavern-smoky-den-bg.mp4、tavern-high-rise-suite-bg.mp4、tavern-rooftop-club-bg.mp4、tavern-neon-poker-club-bg.mp4、extraction-success.mp4、extraction-failure.mp4 |

---

## 6. 插画（场景图 PNG）

| 字段 | 内容 |
|---|---|
| **素材/素材组** | 静态场景图 PNG 文件（~30 个） |
| **覆盖路径** | `assets/scene-plates/*.png` |
| **来源或作者** | 来源待确认 |
| **许可证名称** | 未确认 — 该目录下无 LICENSE 或其他许可声明 |
| **本地证据位置** | `assets/scene-plates/README.md`（描述为"source scene plates used by the live build"，未提及来源或授权） |
| **明确写出的使用条件** | 无 |
| **未确认事项** | **所有场景图的来源、作者和许可证均未确认**；包括酒馆背景图（4 张）、路线图（16 张）、弹窗/案件夹图（数量待确认）、主场景图等 |

---

## 未确认事项汇总（需主 Agent 解决）

以下为所有许可证尚未确认的素材，按优先级排列：

### P0 — 无法确认商用资格（禁止进入正式发行）

1. **全部 9 个 BGM OGG 文件**（`assets/audio/bgm/*.ogg`）：无任何来源、作者或许可证证据。必须找到原始出处（作曲/创作平台）并确认授权类型（CC0、CC-BY、商业授权等）。

2. **全部视频 MP4 文件**（`assets/videos/*.mp4`，共 8 个）：无任何来源、作者或许可证证据。必须确认是自录制、自生成（AI生成）还是第三方素材。

3. **全部场景图 PNG 文件**（`assets/scene-plates/*.png`，约 30 个）：无任何来源、作者或许可证证据。必须确认来源。

4. **stash-noir Blender 场景**（`assets/blender/stash-noir/stash-noir.blend`）：README 自述"自制"，但未写明默认许可协议。建议补充 LICENSE 文件（如 CC-BY 或 CC0），避免后续纠纷。

### P1 — 需要补充确认

5. **扑克牌 PNG 文件**：README 声称来自 vector-playing-cards（public domain）并经过"去边框处理"。需确认：处理后的 PNG 是否仍属于 public domain（某些司法管辖区对衍生作品有不同规定）。**实际游戏引用路径已确认是 `assets/cards/`**（src/main.js:53 + 3620）；`Godot/Cards/` 与 `Godot/素材/playing-cards-assets-master/png/` 经 MD5 验证为同一套文件复制 3 份，建议清理冗余副本。

### P2 — 低优先级（已确认基础许可）

6. **字体**：已确认无外部字体文件，使用系统内置字体，无额外许可问题。

---

## 统计

| 资产组 | 已确认许可证 | 来源待确认 |
|---|---|---|
| 扑克牌 | 1（Public Domain，原始来源） | 1（处理后PNG是否仍为PD） |
| 字体 | 1（系统内置，无需许可） | 0 |
| 模型（Blender） | 0（自制品但无许可声明） | 1 |
| 音频（BGM） | 0 | 9 |
| 视频 | 0 | 8 |
| 插画 | 0 | ~30 |
| **合计** | **2** | **≥48** |

---

## 附：证据文件索引

本次扫描覆盖的本地证据文件：

- `/Godot/素材/playing-cards-assets-master/README.md` — 扑克牌来源说明
- `/Godot/素材/playing-cards-assets-master/LICENSE` — 处理工具 MIT 许可证
- `/assets/audio/README.md` — 音频目录说明（无许可信息）
- `/assets/videos/README.md` — 视频目录说明（无许可信息）
- `/assets/scene-plates/README.md` — 场景图目录说明（无许可信息）
- `/assets/blender/stash-noir/README.md` — 自制场景说明（无许可信息）
- `/styles/foundation.css` 第 23–25 行 — 字体变量声明
- `/项目根目录/README.md` — 项目概述（不涉及第三方素材授权）

本清单只摘录项目内已有证据，不构成法律建议。所有未明确标记的素材都需要主 Agent 单独确认来源与许可后再进入正式发行素材清单。
