# B1 返修记录：资产与内容事实修正

返修日期：2026-09-22。本轮对应主 Agent《外部交付验收与后续任务（2026-09-21）》第 4 节 B1。

**写法**：每条按「修订前结论 → 新证据 → 修订后结论」记录，并指向被改动的文件。
**边界**：只读取源文件与 GLB 元数据／清单；**未执行 build/export，未覆盖任何资产，未生图，未改代码或规则**。
**核查脚本**：`output/external-handoff/B1/b1_audit.py`（一键重跑，只读）→ 快照 `output/external-handoff/B1/b1-audit.json`。
**版本说明**：原 B 交付基于 `b158491`。本轮返修跨了两个提交，**代码行号按返修时的 HEAD `413dce9` 取**：

| 版本 | 说明 |
|---|---|
| `b158491` | 原 B 交付基线 |
| `d44a1dd` | 主 Agent 加固 `run_checkpoint.gd` 的恢复边界（关 A2-4）|
| `413dce9` | 主 Agent 新增加注实付预览 + `Godot/three_d/tests/raise_preview_test.gd`（核查期间落地，已并入本记录 B1-7）|

凡涉及行号的证据均已按 `413dce9` 复核；**没有任何一条结论因这两个提交而反转**，只有 `firstAggressionDiscount` 的硬编码点从 2 处增到 **7 处**（含测试侧 5 处，订正见 B1-7 的"审查后订正"）。

同时被改动的三份原文件：

| 文件 | 改动 |
|---|---|
| `README.md` | 修正第 2.1/2.3/2.4/2.5 节与第三节资产表的结论；状态词改为「实现状态 + 验证状态」两列制；计数口径改写 |
| `content-matrix.csv` | 13 列 → 18 列：`状态` 拆成 `实现状态` + `验证状态`，新增 `生成脚本 / 导出文件 / 加载函数 / 运行使用点` 四列追踪（28 行已填：19 物品 + 9 人物） |
| `asset-gaps.csv` | 5 行事实修正（账房地窖、对手×8、酒保、可用道具×9、贵重道具×10），保持 14 行 |

---

## 一句话结论

上一轮 B 的**方向多数正确、四条具体断言错**：`酒保未接线`、`只有三套网格`、`九个独立 GLB`、`十件贵重物 3D 完全不可见（无任何建模痕迹）`。其中后两条错在**把"文件数""道具实例数"当成了唯一的资产存在形式**；`只有三套网格` 错在**用顶点数代替几何比较**。正确边界是：**几何 4 套、配色 9 套；道具是 12 个命名部件；贵重物有静态装饰但无可用道具**。

---

## B1-1 酒保被判为 GLB 未接入

- **修订前结论**（`README.md` 第三节、`asset-gaps.csv` 酒保行、`content-matrix.csv` 酒保行）：
  「运行场景中的酒保是 3 个 BoxMesh 粗盒；`bartender.glb` 已导出但**未见 scene 接线调用**」→ 判为「部分实现／未接线」。

- **新证据（代码级链路）**：
  1. `Godot/three_d/scripts/characters.gd:27`：`people.bartender = actor("bartender", room, Vector3(2.55, 0, .4), -PI / 2)` —— 在 `build()` 里**主动加载**酒保 GLB。
  2. `characters.gd:6-21 actor()`：`load("res://three_d/assets/characters/" + id + ".glb").instantiate()`，并取 `AnimationPlayer`、把 `idle` 设为循环、连接 `animation_finished` 回 idle。
  3. `characters.gd:28-30`：遍历房间子节点，`visual_role` 以 `"Bartender"` 开头的节点 `hide()`。而 `world.gd` 的 `box()` 会 `set_meta("visual_role", node_name)`，`bar_display.gd:13-15` 建的正是 `BartenderTorso / BartenderHead / BartenderHand` → **三个占位盒体在 GLB 挂入时被隐藏**。
  4. **交付动画入口**：`characters.gd:57-59 deliver()` 取 `rooms[...].bartender` 的 `AnimationPlayer` 播 `bet` 段；调用点 `world.gd:861`（与 `bar_display.deliver(item_id)` 同一交接流程，`:860`）。测试 `characters_test.gd:45` 显式调用 `world.characters.deliver()`。
  5. `art_integration_test.gd:20-22` 逐条断言 `Floor/PokerTable/…/BarCounter/BarTop/BarStool/BottleShelf/Bottle` 的**原始占位体已隐藏**，说明"隐藏占位、展示 GLB"是本项目既定的接线范式。

- **修订后结论**：
  **酒保 GLB 已接线并已隐藏占位盒体**，不是"未接线"。改为「**已实现 + 已核验**」。
  真正的遗留是"**接线后冗余**"而非"缺失"：`bar_display.gd` 仍继续创建三个盒体，且 `:42-49` 的手部 tween 作用在**已隐藏**的盒体上；可见效果由道具模型 + 酒保 `bet` 动画承担。建议主 Agent 在 Phase 2/3 决定是否清理这段冗余，**不建议现在动**（它不影响可见结果，清理属额外风险）。
  另：酒保几何是**独立组 C**（见 B1-2），`standing=True`（`build_characters.py:35` `lift=.35`）。

- **独立复核补强（2026-09-22，对抗性复查）**：上面第 1、3 条证据由本轮审查脚本**独立重推导**确认（`output/external-handoff/adversarial/adversarial_audit.py`），并新增两条：
  1. **有测试在断言同一件事**：`tests/characters_test.gd:32` 与 `characters.gd:29` 用**完全相同**的判据（`str(node.get_meta("visual_role", "")).begins_with("Bartender")`）检查占位件。这比"只读实现代码"强，因为测试若与实现不一致会失败。
  2. **隐藏是"元数据驱动"的，不是按名字硬匹配**：`world.gd:130-133 box()` 里有 `body.set_meta("visual_role", node_name)`，`bar_display.gd:13-15` 恰好把三个盒体命名为 `BartenderTorso / BartenderHead / BartenderHand`，前缀才匹配得上。**脆弱点（应报给主 Agent）**：将来若新增不带 `visual_role` 元数据、或以别的前缀命名的酒保占位件，`hide()` 会**静默失效**（占位盒与 GLB 同时可见，且不会有测试报错）。`art_integration_test.gd:20-22` 只覆盖 `Floor/PokerTable/…/Bottle` 那批前缀，**没有覆盖 `Bartender*`**。

---

## B1-2 以三种顶点数断言只有三套网格

- **修订前结论**（`README.md` 第三节、`asset-gaps.csv` 人物行）：
  「顶点数只有 3 种取值（40282 / 39558 / 38588），实际是 **3 套共享网格 + 配色差异**，不是 9 个独立人物」→ 并在 `content-matrix.csv` 的对手行写「与 river-shark 同网格」。

- **新证据（对 9 个 GLB 的 POSITION 与 JOINTS_0／WEIGHTS_0 取原始字节 sha256）**：

  | 文件 | manifest 顶点 | GLB 顶点合计 | 几何+蒙皮组 |
  |---|---:|---:|---|
  | ash-smuggler | 40282 | 41463 | **A** `567b2697…` |
  | dock-braggart | 40282 | 41463 | **A** 同上 |
  | river-shark | 40282 | 41463 | **A** 同上 |
  | smiling-knife | 40282 | 41463 | **A** 同上 |
  | house-viper | 39558 | 40617 | **B** `b19ad6a6…` |
  | ledger-clerk | 39558 | 40617 | **B** 同上 |
  | velvet-rook | 39558 | 40617 | **B** 同上 |
  | bartender | 39558 | 40617 | **C** `74e02b28…` ← **顶点数同 B，几何不同** |
  | calm-widow | 38588 | 39708 | **D** `2d6f13e3…` |

  - 几何+蒙皮互不相同的组数是 **4**，不是 3。原报告把 `bartender` 归进 39558 那一组，**正是"顶点数相同 ⇒ 几何相同"这个推论的反例**。
  - 差异来源在 `build_characters.py:9 CAST` 的三个开关：`hat`（A 组 4 人全为 `True` → 各多一顶 `Felt hat brim` + `Hat crown`）、`female`（D 组 `calm-widow` 独有 → `Pinned hair` + `Jacket/Cranium/Jaw/Cheek` 尺寸与 `Fitted shirt` 投影不同）、`standing`（C 组 `bartender` 独有 → `lift=.35`、膝/踝位置、`Sleeve` 材质分支）。**每人各自的 suit/hair 色值不改变几何。**
  - 配色侧：9 个 GLB 的材质名完全一致（`Wool/Hair/Brass/Skin/Eye white/Iris/Lips/Ivory cotton/Polished leather`，各 9 个，无贴图），但 `(Wool, Hair, Skin)` 的 `baseColorFactor` **9 人 9 套、无重复**（`Skin` 随 `build_characters.py:36` 的 `idx` 微调）。
  - 顺带纠正一个口径混淆：`manifest.json` 的 `vertices`（40282/39558/38588）是 **Blender 侧 `len(body.data.vertices)`**（`build_characters.py:121`），而 GLB 的 POSITION 合计（41463/40617/39708）是**导出按 UV/法线切分后**的顶点数。两者都对，但不是同一个量。

- **修订后结论**：
  「顶点数只有 3 种取值」这个**观察成立**；「因此只有 3 套网格」这个**推论不成立**，改为：
  > **4 套独立几何+蒙皮 × 9 套独立配色**，共 9 个角色。
  > 几何组：A=ash-smuggler/dock-braggart/river-shark/smiling-knife（hat=True）；B=house-viper/ledger-clerk/velvet-rook；C=bartender（standing=True）；D=calm-widow（female=True）。
  `content-matrix.csv` 对手行的「与 X 同网格」改为按组 A/B/C/D 表述。**不再写"已证实只有三个人物"**，也不升级成"必须重建 9 个模型"——9 个角色在"每人独立配色 + 4 套体型"下是**可辨识**的，缺的是雕塑级细节。

---

## B1-3 九件道具被称为九个独立 GLB 文件

- **修订前结论**（`README.md` 第三节、`asset-gaps.csv` 可用道具行）：
  「9 件可用道具有独立 GLB（`props-export.json`）」→ 被读成 9 个独立文件。

- **新证据**：
  1. `Godot/three_d/assets/interactive-props.glb` 的 glTF 节点名为 **12 组**：`disposable-phone / dock-passkey / drawer / false-bottom-wallet / kitchen-pass / loose-card / loose-chip / marked-lens / player-notes / signal-lighter / sleeve-clip / steadying-drink`（每个另有 `xxxMesh` 子节点），`meshes` 也为 **12**。
  2. `props-export.json` 恰好是这 **12 个键**（9 件可用道具 + `drawer` / `loose-card` / `loose-chip`）。
  3. `world.gd:11 PROPS_ASSET = preload("res://three_d/assets/interactive-props.glb")`；`world.gd:958-962 make_detailed_prop(id)` 按 id 从这一个 GLB 里取命名节点。
  4. `art_integration_test.gd:24-28` 对 `SUPPORTED_ITEMS + ["loose-card","loose-chip","drawer"]` = **12 个 id** 逐个断言「单件可移动网格 + AABB 长度 < 1.1 m」，从测试侧固定了"12 个部件"这个口径。

- **修订后结论**：
  存在**三级数量**，必须分开写：
  - **文件数 1**（只有一个 `interactive-props.glb`）
  - **网格/部件数 12**（9 件可用道具 + 3 个场景件）
  - **道具数 9**（可用道具，`kind:"usable"`）
  「9 件可用道具有独立 GLB 模型」改为「**9 件可用道具是同一个 GLB 内的 9 个命名部件**」。

---

## B1-4 十件贵重物被一概判为无源文件、无 GLB、3D 不可见

- **修订前结论**（`README.md` 第三节、`asset-gaps.csv` 贵重道具行）：
  「**10 件贵重物既无 Blender 源文件也无 GLB**，3D 里完全不可见」。

- **新证据（逐件检索 stash 建模脚本与导出物）**：
  1. `assets/blender/stash-noir/build_scene.py` 有第 **05 组「Personal valuables」**（`:145-163`），含：`Silver cigarette case`（银烟盒）、`Pearl necklace`（49 外圈 + 19 内圈 + `Necklace clasp`）、`Pocket watch body` + `Ivory enamel watch dial` + `Watch bezel` + 12 个 `Watch hour` + 时分针 + `Watch bow`。
  2. `export_game_asset.py:17` 的保留条件是组号 ∈ `['01'…'07']` → **05 组被保留**；`:53` `labels={…,'05':'Valuables',…}` → 导出后合并成节点 **`Valuables`**。
  3. `Godot/three_d/assets/stash.glb` 的节点名实测含 **`Valuables`**（另 7 个：`Desk / CaseBody / CaseLidMesh / CaseLidPivot / Cash / Chips / Cards / Lamp`），与 `stash-export.json` 的 `mesh_objects: 8` 吻合。
  4. `world.gd:14 STASH_ASSET` + `:181-184 build_stash()` 把它挂进藏匿点 → **这组装饰在游戏里是可见的**。
  5. 反向核对：`build_scene.py` 里**没有**打火机、袖扣、纪念币、债券、胸针、雕像、本票的任何建模；10 件贵重物在 `props-export.json` 与 `interactive-props.glb` 里**都没有**独立部件。

  **逐件对应表**：

  | 贵重物 | 静态装饰对应物 | 独立可复用模型 | 背包/奖励 3D 表现 |
  |---|---|---|---|
  | pearl-necklace | ✅ `Pearl necklace`（stash.glb `Valuables`） | ❌ | ❌ |
  | gold-cased-watch | ✅ `Pocket watch body` + 珐琅表盘 + 表圈/指针/表弓 | ❌ | ❌ |
  | ivory-chip | ◐ 场景筹码堆（`04 • Casino chips` 的象牙嵌片/中心），非该道具 | ❌ | ❌ |
  | old-silver-lighter | △ 最近似的是 `Silver cigarette case`（**银烟盒，不是打火机**） | ❌ | ❌ |
  | ruby-cufflink / antique-coin / sealed-bond / emerald-brooch / obsidian-idol / vault-promissory | ❌ 未检索到 | ❌ | ❌ |

- **修订后结论**：
  拆成三层写，避免"有装饰"与"有道具"互相冒充：
  > - **静态装饰**：2 件有明确可辨认的藏匿点装饰（珍珠项链、金壳怀表），1 件近似（银烟盒 ≈ 旧银打火机，但物件不同），1 件只有材质级筹码堆装饰（象牙筹码）。这些装饰随 `stash.glb` 在藏匿点可见。
  > - **独立可复用模型**：**0 件**。
  > - **背包/奖励的 3D 表现**：**0 件**；规则侧（价值/占格/抵押/`sale_value`/撤离计价/奖励发放）照常生效，界面为纯文字（`table_hud.gd:144-148` 抵押下拉）。
  影响阶段维持 Phase 3，但**不得据此升级成"全部重新建模"**：占 2 格的只有 3 件（见 B1-6）。

---

## B1-5 四件贵重物占两格

- **修订前结论**：`README.md` 2.1 节写「10 件贵重物中 **4 件**占 2 格（sealed-bond / obsidian-idol / vault-promissory / **另外 sealed-bond 等**）」——同一句里把 `sealed-bond` 写了两次，凑成 4，且没有第 4 个实体。

- **新证据**：`content.json` 的物品段实测 `slots == 2` 的只有三项：**`sealed-bond` / `obsidian-idol` / `vault-promissory`**；其余贵重物（含 `antique-coin`、`gold-cased-watch`、`pearl-necklace`、`emerald-brooch`、`ruby-cufflink`、`old-silver-lighter`、`ivory-chip`）全为 `slots == 1`。背包 `inventorySlots = 6`。

- **修订后结论**：
  「**4 件**占 2 格」→「**3 件**占 2 格（sealed-bond / obsidian-idol / vault-promissory）」。6 格背包下的取舍仍然存在，但门槛比原描述低一档。

---

## B1-6 「部分实现」和「未单独测试」混用

- **修订前结论**：`content-matrix.csv` 只有一列 `状态`，取值混用 `已核验 / 部分实现`；`README.md` §五 写「部分实现 11 条」。
  - 后果一：`cargo-table` 被标"部分实现"，但它的**规则在跑**（`table_test:67` 已验证首攻优惠只扣一次），真正缺的是 `content.json` 那个字段没接线——这是"数据未接线"，不是"功能半成品"。
  - 后果二：贵重物被标"部分实现"，读起来像"功能做了一半"，实际是"**功能全在、只是出售路径没有独立断言**"。

- **新证据**：本轮把矩阵里每行的"缺什么"回读了一遍，缺口分三类且互斥——① 规则未接线（数据字段没人读）；② 断言未单列（功能已实现、测试证据不够细）；③ 3D 呈现缺失（美术资产未做）。

- **修订后结论**：
  `content-matrix.csv` 单列 `状态` → **两列**：
  - `实现状态`：`已实现 / 部分实现 / 未实现` —— **本轮 56 行全部为 `已实现`**（没有一行是功能半成品）。
  - `验证状态`：`已核验 / 部分验证 / 未验证` —— **已核验 48，部分验证 8**（`signal-lighter` + 7 件贵重物），无"未验证"行。
  并在 `缺口` 列把三类原因分开写。`README.md` §五 的「45 / 11」计数随两列制重写。
  **明文规则**：没有单独的售卖测试，只能写「出售路径未单独断言」，**不能写"没有售卖逻辑"**（`run.gd:447-449 sale_value()` 对贵重物返回 `value`，是明确存在的分支）。

---

## B1-7 字段读取结论过强

- **修订前结论**：`README.md` §2.5 的表把 `baseRewardPool` 归入「未被读取」，并给影响「情报里显示的奖励池 ≠ 实际发放规则」。

- **新证据（全量 `grep` `Godot/three_d/**/*.gd`）**：

  | 字段 | 命中 | 性质 |
  |---|---|---|
  | `baseRewardPool` | **1 处**：`run.gd:432` | **被读取，但只用于情报文案展示**（`"、".join(content.tables[table_id].baseRewardPool.map(...))`） |
  | `signatureReward` | 0 处 | 未读取（奖励发放是 `run.gd:198-202` 的 `match definition.id` 硬编码） |
  | `firstAggressionDiscount`（**内容字段名**） | **0 处** | 未读取——`content.json` 的字段名确实没人读 |
  | `firstAggressionDiscountAvailable`（**同义运行时状态字段**） | **12 行** | **在跑**：`table.gd:26` 定值开关（`state.tableDef.id == "cargo-table"`）、`table.gd:67`、`table.gd:94`、`table.gd:96`、`table_hud.gd:201`，以及 `table_parity.gd:15` / `table_test.gd:67` / `two_tables.gd:26` / `poker_action_coverage_test.gd:32` / `poker_guard_coverage_test.gd:29-31` |
  | 折扣**字面量 `10`** | **7 处** | 生产 2：`table.gd:67`、`table_hud.gd:201`；测试 5：`raise_preview_test.gd:19`、`poker_action_coverage_test.gd:32`、`poker_guard_coverage_test.gd:29/30/31`。另有 **2 处断言**把折扣写进期望值：`table_test.gd:67`、`two_tables.gd:26` |
  | `publicInfo` / `hiddenInfo` | 0 处 | 未读取（文案是 `run.gd:524-525` 的硬编码 map） |
  | `intelBonus` / `forcedExitLossFactor` / `revealFlag` | 0 处 | 未读取（`revealFlag` 的实际替代是 `advanced_services.gd:41/53` 的 `unlockRoute`） |

  > **口径提示（2026-09-22 复核）**：核查期间主 Agent 又提交了 `413dce9 feat: show actual raise cost and first aggression discount`，给 `table_hud.gd` 加了加注实付预览并新增 `Godot/three_d/tests/raise_preview_test.gd`。该提交**没有改变本条结论**，反而把硬编码点从 2 处增到 4 处：`content.json` 的 `firstAggressionDiscount` 依旧零读取，新测试第 19 行**自己也硬编码了 `10`**。也就是说"改 content.json 数值不会生效"这件事，现在有一个测试在配合它——如果将来接线，这个测试也要同步改，否则会出现"代码读了数据、测试仍按 10 断言"的新双份真相。
  >
  > **⚠️ 审查后订正（2026-09-22，对抗性复查）：上面的"4 处硬编码 10"是错的，正确是 7 处。** 原写法把三类不同的东西并成一条：① `table.gd:26` 是**桌名门**（`state.tableDef.id == "cargo-table"`），里面**没有**字面量 `10`；② `table.gd:67` 和 `table_hud.gd:201` 是生产侧字面量 `10`；③ `raise_preview_test.gd:19` 是测试侧字面量 `10`。当时漏了测试侧另外 4 个字面量 `10`：`poker_action_coverage_test.gd:32` 与 `poker_guard_coverage_test.gd:29/30/31`（各自手算 raise 期望值时都减了写死的 10）。因此**字面量 `10` = 7 处**，另有桌名门 1 处、断言 2 处。
  > 与之配套的另一个问题：原 §2.5 给的复现命令把 `firstAggressionDiscount` 与其余 6 个字段**合并成一次 grep**，实际会返回 12 行（全部是 `…Available`），与表中"0"直接冲突。**已改为按字段分开搜**（见 `README.md` §2.5 复现块）。

- **修订后结论**：
  `baseRewardPool` 从「未被读取」改为「**用于情报展示（`run.gd:432`）；奖励发放是否与它同源，需另行核对**」——本轮已核对：**不同源**，发放走 `run.gd:198-202` 的硬编码 `match`，所以"情报显示池 ≠ 实际发放规则"这个影响**仍然成立，但原因不是'零读取'而是'双份真相'**。
  其余字段也按"展示 / 结算 / 旧存档兼容入口"三分层重新标注（`README.md` §2.5 表已加"性质"列）。

---

## B1-8 计数及历史兼容

- **修订前结论**：`README.md` §一 写「`content-matrix.csv` 共 **55 行**（…）= 实际 **56 行**」——一句话里两个数，自相矛盾。

- **新证据**：
  - 实测矩阵**数据行 56**（表头另计）：酒馆 4 + 牌桌 4 + 物品 19 + 对手 8 + 酒保 1 + 路线固定 8 + 路线特殊 8 + 通用撤离 4 = 56。
  - `asset-gaps.csv` 数据行 **14**。
  - `opponentIds` 的 `seed_value == 0` 回退（`run_variants.gd:30-31`）**不是死字段**：`world.gd:772` 每局用 `int(randi() % 2147483646) + 1` 生成种子（恒 ≥ 1），所以对局中确实不可达，但该分支同时承担 **① 旧存档兼容**（`opponent_pool_test.gd:66` 断言"旧计划保留历史名单"）、**② 调试/回放入口**（`run_variants.gd:23` 的 `initial_offer`、`:17-18` 的货架变异都以 `seed_value != 0` 为条件）。**不能当作可随意删除的无效字段。**
  - `账房地窖` 的定位：`world.gd:51 ROOMS` 里 `ledger → {node:"LedgerCellar", table:"ledger-cellar", x:20.0}`，与 `Tavern/MirrorHall/EmbersRoom` 一样由 `world.gd:206 build_tavern()` **同一函数**生成（`:79-82` 四次调用，offset 10/20/30/40）。它是"同一建筑内的另一间牌室"，**不是四酒馆之外的"第四个牌室"，也不是第五套空间**。

- **修订后结论**：
  - 统一为**56 行**，删掉"55"。
  - `asset-gaps.csv` 明确写 **14 行**。
  - `README.md` §2.3 补充：静态 `opponentIds` 标注为「**仅 `seed=0`（旧存档兼容 / 调试回放）生效**」，并注明它**不可删**；同时保留原有的"运行时 `[pressure, value]` 与静态 `[value, pressure]` 顺序相反"这条实践警告（`ledger-cellar: ["river-shark","velvet-rook"]` 是 `[value, pressure]`，而 `cargo-table: ["dock-braggart","ledger-clerk"]` 恰好是 `[pressure, value]`——**四个桌里只有 cargo-table 的顺序与运行时常量一致**，这个不一致本身才是要报的坑）。
  - `asset-gaps.csv` 账房地窖行改写为"同一 `build_tavern()` 生成的房间实例之一"，删去易被读成"第四个牌室"的说法。

---

## 逐实体追踪（19 物品 + 9 人物）

按主 Agent 要求的「内容 ID → 生成脚本 → 导出文件 → 加载函数 → 运行使用点」链路，已写入 `content-matrix.csv` 的四个新列（28 行已填）。三类实体的链路模板：

| 类别 | 生成脚本 | 导出文件 | 加载函数 | 运行使用点 |
|---|---|---|---|---|
| 9 件可用道具 | `assets/blender/tavern-detail/build_props.py` | `interactive-props.glb`（节点名=道具 id，共 12 键）+ `props-export.json` | `world.gd:11 PROPS_ASSET` / `:958 make_detailed_prop()` | `bar_display.gd:24-37` 货架、`:52-53 make_item()`、`world.gd:860 deliver()`；各自的规则入口见矩阵行 |
| 10 件贵重物 | 无独立脚本（仅 stash 静物 `build_scene.py` 05 组） | 无独立 GLB；合并进 `stash.glb` 节点 `Valuables` | `world.gd:14 STASH_ASSET` / `:181-184 build_stash()`（装饰，不是道具实例） | 规则侧 `run.gd:449` / `run.gd:199-202` / `routes.gd:51` / `table_hud.gd:144-148` |
| 9 人物 | `assets/blender/characters/build_characters.py`（`CAST` 的 suit/hair 色 + hat/female[+bartender standing]） | `characters/<id>.glb` + `manifest.json` | `characters.gd:6-21 actor()` | `characters.gd:22-27 build()`、`:44-56 refresh()`、`:57-59 deliver()`（`world.gd:861` 调用） |

矩阵里 56 行中另外 28 行（酒馆 4 / 牌桌 4 / 路线 16 / 通用撤离 4）是**规则与内容**实体，没有对应美术资产链路，四列留 `-`。

---

## 需要主 Agent 决定 / 后续（承接上一轮第四节的 6 个问题）

上一轮提的 6 个问题中，本轮已经**自己回答掉 3 个事实类**（酒保接线、几何套数、道具文件数）。剩下仍需主 Agent 决定的：

1. **`specialRoutes` 键 vs id 的双名字**——保持分层（dispatch key / display id）还是统一？现状两套名字同时在跑。
2. **6 个"存在但未读取"的字段**（`firstAggressionDiscount` / `signatureReward` / `publicInfo` / `hiddenInfo` / `intelBonus` / `forcedExitLossFactor` / `revealFlag`）——接线还是删？**建议先定 `firstAggressionDiscount`**，它是 `difficulty-curve.md` 里的规则。
3. **`baseRewardPool` 的双份真相**——让发放改读数据，还是把字段降级为纯展示并加注释？
4. **`opponentIds` 静态顺序**——是否把 `ledger-cellar / mirror-hall / embers-table` 改成与运行时一致的 `[pressure, value]`？现在只有 `cargo-table` 一致。
5. **`bar_display` 的遗留盒体与 tween**——何时清理（不影响可见结果，可推迟）。
6. **四店建筑是否拆成 4 套空间**、**`src/data.js` 的定位**——维持上一轮结论，Phase 3 再定。

---

## 本轮边界声明

- 未运行任何测试（测试执行属任务 A／A2）。
- 未修改 `Godot/three_d/rules/`、`scripts/`、任何 `.blend` / `.glb` / 贴图、`src/`。
- 未执行 build/export，未覆盖资产，未启动编辑器，未生成模型/贴图/图片。
- 未覆盖上一轮 `inventory/` 文件。
- 未 commit / push。
- `content-matrix.csv` 与 `asset-gaps.csv` 的改动前副本留在 `output/external-handoff/B1/*.bak`，可逐单元格比对。
