extends Control
signal start_requested
signal action_requested(kind: String, revision: int, raise_target: int)
signal continue_requested(revision: int)
signal leave_requested
const NAMES := {"player": "你", "dock-braggart": "码头吹牛客", "ledger-clerk": "账房先生", "river-shark": "河道老鲨", "velvet-rook": "绒衣新客", "calm-widow":"沉静寡妇", "smiling-knife":"笑面刀", "house-viper":"庄家毒蛇", "ash-smuggler":"灰烬走私客"}
const TABLE_NAMES := {"cargo-table": "货运桌", "ledger-cellar": "账房地窖", "mirror-hall":"镜厅", "embers-table":"余烬桌"}
const STREETS := {"preflop": "翻牌前", "flop": "翻牌", "turn": "转牌", "river": "河牌"}
const ACTIONS := {"fold": "弃牌", "check": "过牌", "call": "跟注", "raise": "加注", "all-in": "全押"}
var header: Label
var opponent_left: Label
var opponent_right: Label
var status: Label
var hand: Label
var history: Label
var start_button: Button
var next_button: Button
var leave_button: Button
var raise_amount: SpinBox
var action_buttons := {}
var displayed_revision := -1
var result_banner: Label
var collateral_choice: OptionButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = text(self, "货运桌", 26)
	header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	header.offset_left = -380
	header.offset_right = 380
	header.offset_top = 26
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_left = text(self, "", 19)
	opponent_left.position = Vector2(300, 135)
	opponent_right = text(self, "", 19)
	opponent_right.position = Vector2(880, 135)
	history = text(self, "", 17)
	history.position = Vector2(32, 150)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -202
	panel.offset_bottom = -18
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.063, 0.056, 0.95)
	style.border_color = Color("8d764a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	status = text(rows, "", 19)
	hand = text(rows, "", 26)
	collateral_choice = OptionButton.new()
	rows.add_child(collateral_choice)
	collateral_choice.hide()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 9)
	rows.add_child(buttons)
	for kind in ["fold", "check", "call", "raise", "all-in"]:
		var button := make_button(buttons, ACTIONS[kind])
		button.pressed.connect(func(): action_requested.emit(kind, displayed_revision, int(raise_amount.value) if kind == "raise" else -1))
		action_buttons[kind] = button
	raise_amount = SpinBox.new()
	raise_amount.custom_minimum_size = Vector2(120, 44)
	raise_amount.step = 1
	buttons.add_child(raise_amount)
	start_button = make_button(buttons, "开始牌局")
	start_button.pressed.connect(func(): start_requested.emit())
	next_button = make_button(buttons, "下一手")
	next_button.pressed.connect(func(): continue_requested.emit(displayed_revision))
	leave_button = make_button(buttons, "离开牌桌")
	leave_button.pressed.connect(func(): leave_requested.emit())
	result_banner = text(self, "", 36)
	result_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_banner.offset_left = -460
	result_banner.offset_right = 460
	result_banner.offset_top = -50
	result_banner.offset_bottom = 70
	result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_banner.add_theme_color_override("font_shadow_color", Color.BLACK)
	result_banner.add_theme_constant_override("shadow_outline_size", 12)
	result_banner.hide()
	pregame()

func text(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0dfb4"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func make_button(parent: Node, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(118, 44)
	button.add_theme_font_size_override("font_size", 19)
	parent.add_child(button)
	return button

static func card_text(card: Dictionary) -> String:
	var rank := int(card.rank)
	return str({11:"J",12:"Q",13:"K",14:"A"}.get(rank, str(rank))) + {"S":"♠", "H":"♥", "D":"♦", "C":"♣"}[card.suit]

static func cards_text(cards: Array) -> String:
	var parts: PackedStringArray = []
	for card in cards:
		parts.append(card_text(card))
	return "  ".join(parts)

func pregame(cash := 0, definition: Dictionary = {}, inventory: Array = [], run: RefCounted = null) -> void:
	if definition.is_empty():
		return
	result_banner.hide()
	header.text = "%s · 本桌 %d 手" % [TABLE_NAMES[definition.id], definition.hands]
	status.text = "每席 %d 筹码 · 小盲 %d / 大盲 %d" % [definition.buyIn, definition.smallBlind, definition.openBet]
	if run != null:
		status.text += " · " + run.rule_text(definition.id)
	collateral_choice.clear()
	collateral_choice.add_item("不抵押贵重物")
	collateral_choice.set_item_metadata(0, "")
	collateral_choice.visible = definition.get("allowCollateral", false)
	if collateral_choice.visible and run != null:
		for id in inventory:
			if run.content.items[id].kind == "valuable":
				collateral_choice.add_item("抵押 " + run.item_name(id) + " · 最后一手未获胜则失去")
				collateral_choice.set_item_metadata(collateral_choice.item_count - 1, id)
	collateral_choice.select(0)
	hand.text = "随身现金 %d · 开始时扣除买入 %d，离桌返还剩余筹码" % [cash, definition.buyIn]
	history.text = ""
	opponent_left.text = NAMES[definition.opponentIds[0]]
	opponent_right.text = NAMES[definition.opponentIds[1]]
	for button in action_buttons.values():
		button.hide()
	raise_amount.hide()
	start_button.show()
	next_button.hide()
	leave_button.show()

func refresh(view: Dictionary, locked := false) -> void:
	collateral_choice.hide()
	displayed_revision = view.revision
	var playing: bool = view.status == "playing"
	result_banner.visible = not playing
	var your_turn: bool = playing and view.currentActorId == "player" and not locked
	var you: Dictionary = view.players[0]
	var owed := maxi(0, view.currentBet - you.currentBet)
	header.text = "%s · 第 %d / %d 手 · %s · 底池 %d" % [TABLE_NAMES[view.tableDef.id], view.handNumber, view.totalHands, STREETS[view.street], view.pot]
	for i in [1, 2]:
		var seat: Dictionary = view.players[i]
		var state_text: String = "已弃牌" if seat.folded else ("全押" if seat.stack == 0 else "本轮已投 %d" % seat.currentBet)
		var label: Label = opponent_left if i == 1 else opponent_right
		label.text = "%s · 筹码 %d\n%s\n%s" % [NAMES.get(seat.id, seat.id), seat.stack, state_text, cards_text(seat.holeCards) if not seat.holeCards.is_empty() else "暗牌"]
	hand.text = "你的手牌  %s     筹码 %d" % [cards_text(you.holeCards), you.stack]
	if playing:
		status.text = "轮到你 · 需跟注 %d" % owed if your_turn else ("正在翻牌…" if view.currentActorId.is_empty() else "%s正在行动…" % NAMES.get(view.currentActorId, view.currentActorId))
	else:
		var winners: PackedStringArray = []
		for id in view.summary.get("awards", {}):
			if view.summary.awards[id] > 0:
				winners.append("%s收回 %d" % [NAMES.get(id, id), view.summary.awards[id]])
		var net := int(view.summary.get("awards", {}).get("player", 0)) - int(you.handContribution)
		var outcome := "赢了！" if net > 0 else ("输了这一手" if net < 0 else "本手持平")
		result_banner.text = "%s  %s%d 筹码" % [outcome, "+" if net > 0 else "", net]
		result_banner.add_theme_color_override("font_color", Color("8ee1b0") if net > 0 else (Color("ffa399") if net < 0 else Color("f0dfb4")))
		if view.status == "finished":
			result_banner.text += "\n本桌结束 · 合计 %+d 筹码" % (you.stack - int(view.tableDef.buyIn))
		status.text = "本手结束 · " + "，".join(winners)
		if view.status == "finished":
			hand.text += "    本桌净变化 %+d" % (you.stack - int(view.tableDef.buyIn))
	for kind in action_buttons:
		var button: Button = action_buttons[kind]
		button.visible = playing
		button.disabled = not your_turn or not view.legal.get("allIn" if kind == "all-in" else kind, false)
		button.text = "跟注 %d" % owed if kind == "call" else ACTIONS[kind]
	var minimum: int = view.tableDef.openBet if view.currentBet == 0 else view.currentBet + int(view.tableDef.raiseIncrement)
	raise_amount.visible = playing
	raise_amount.editable = your_turn and view.legal.get("raise", false)
	raise_amount.max_value = maxi(minimum, you.currentBet + you.stack)
	raise_amount.min_value = minimum
	raise_amount.value = minimum
	start_button.hide()
	next_button.visible = view.status == "hand_over"
	leave_button.visible = view.status == "finished"
	var lines: PackedStringArray = []
	for entry in view.log.slice(-5):
		if entry.kind in ACTIONS:
			lines.append("%s %s%s" % [NAMES.get(entry.actor, entry.actor), ACTIONS[entry.kind], " %d" % entry.amount if entry.amount > 0 else ""])
	history.text = "\n".join(lines)

func selected_collateral() -> String:
	return str(collateral_choice.get_item_metadata(collateral_choice.selected)) if collateral_choice.visible and collateral_choice.selected >= 0 else ""
