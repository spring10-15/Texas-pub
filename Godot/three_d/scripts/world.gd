extends Node3D
## Scene presentation and timing. Table rules own all bets and chip transfers.
const PlayerController = preload("res://three_d/scripts/player.gd")
const Interactable = preload("res://three_d/scripts/interactable.gd")
const RunRules = preload("res://three_d/rules/run.gd")
const OpponentRules = preload("res://three_d/rules/opponent.gd")
const TableHUD = preload("res://three_d/scripts/table_hud.gd")
const SaveStore = preload("res://three_d/rules/save_store.gd")
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const ServicesHUD = preload("res://three_d/scripts/services_hud.gd")
const PROPS_ASSET = preload("res://three_d/assets/interactive-props.glb")
const TAVERN_DETAIL = preload("res://three_d/assets/tavern-detail.glb")
const STASH_DETAIL = preload("res://three_d/assets/stash-room-detail.glb")
const STASH_ASSET = preload("res://three_d/assets/stash.glb")
var player: CharacterBody3D
var title_label: Label
var hint_label: Label
var pause_panel: PanelContainer
var seat_panel: Control
var table_game: RefCounted
var table_content: Dictionary
var run_game: RefCounted
var economy_label: Label
var run_panel: PanelContainer
var run_heading: Label
var run_body: Label
var run_confirm: Button
var forfeit_button: Button
var run_action := ""
var run_revision := -1
var exit_notice: Area3D
var table_delay := 0.0
var cards_root: Node3D
var explore_instructions: Label
var crosshair: Label
var case_target: Area3D
var door_target: Area3D
var table_target: Area3D
var lid: Node3D
var lid_open_rotation: Vector3
var case_open := true
var action_busy := false
var seated := false
var paused := false
var current_room := "stash"
var return_transform: Transform3D
var seat_camera: Camera3D
var readiness := false
var materials := {}
var table_rooms := {}
var active_table_id := "cargo-table"
var ledger_door: Area3D
var services_panel: Control
var save_path := "user://three-d-checkpoint.save"
var saving_enabled := false
var save_clock := 0.0
var last_saved: PackedByteArray
var save_notice: Label
var selected_route := "general"
var props: RefCounted
var bar_display: RefCounted
var service_mode := "bag"
var product_id := ""

func _ready() -> void:
	table_content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	run_game = RunRules.new(table_content)
	configure_input()
	make_materials()
	build_lighting()
	props = preload("res://three_d/scripts/scene_props.gd").new(self)
	bar_display = preload("res://three_d/scripts/bar_display.gd").new(self)
	build_stash()
	build_tavern()
	build_tavern("LedgerCellar", 20.0)
	select_table_room("Tavern")
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(-0.35, 0.05, 1.9)
	player.camera.rotation.x = -0.30
	player.interaction_requested.connect(request_action)
	player.focus_changed.connect(show_focus)
	player.pause_requested.connect(toggle_pause)
	build_ui()
	refresh_economy()
	if not OS.get_cmdline_user_args().has("--test"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	readiness = true
	if not OS.get_cmdline_user_args().has("--test"):
		get_tree().auto_accept_quit = false
		load_checkpoint()

func configure_input() -> void:
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "interact": KEY_E, "pause": KEY_ESCAPE, "inventory": KEY_B}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func make_materials() -> void:
	var colors := {"wall": Color("343b39"), "wood": Color("51351f"), "floor": Color("30251e"), "brass": Color("b18c45"), "green": Color("174038"), "dark": Color("171b1a"), "cloth": Color("645941"), "ivory": Color("d5c69d")}
	for key in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[key]
		material.roughness = 0.76
		if key == "brass":
			material.metallic = 0.7
			material.roughness = 0.35
		var tile: String = {"wood":"walnut", "floor":"walnut", "wall":"plaster", "cloth":"leather"}.get(key, "")
		if not tile.is_empty():
			material.albedo_color = Color.WHITE
			material.albedo_texture = load("res://three_d/assets/materials/" + tile + "-color.png")
			material.roughness_texture = load("res://three_d/assets/materials/" + tile + "-roughness.png")
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.normal_enabled = true
			material.normal_texture = load("res://three_d/assets/materials/" + tile + "-normal.png")
			material.normal_scale = 0.45
		materials[key] = material

func box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, material: String, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = node_name
	body.set_meta("visual_role", node_name)
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = materials[material]
	body.add_child(mesh)
	if solid:
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
	return body

func room_shell(offset: Vector3, label: String) -> Node3D:
	var room := Node3D.new()
	room.name = label
	room.position = offset
	add_child(room)
	box(room, "Floor", Vector3(0, -0.12, 0), Vector3(6, 0.24, 7), "floor")
	box(room, "Ceiling", Vector3(0, 3.1, 0), Vector3(6, 0.2, 7), "dark")
	if label == "Tavern":
		for x in [-1.95, 1.95]:
			box(room, "BackWall", Vector3(x, 1.5, -3.5), Vector3(2.1, 3, 0.18), "wall")
		box(room, "DoorLintel", Vector3(0, 2.8, -3.5), Vector3(1.8, 0.4, 0.18), "wood")
	else:
		box(room, "BackWall", Vector3(0, 1.5, -3.5), Vector3(6, 3, 0.18), "wall")
	box(room, "FrontWall", Vector3(0, 1.5, 3.5), Vector3(6, 3, 0.18), "wall")
	for x in [-3.0, 3.0]:
		if label == "Stash" and x > 0:
			box(room, "WindowSill", Vector3(x, 0.5, -1.4), Vector3(0.18, 1, 2), "wall")
			box(room, "WindowLintel", Vector3(x, 2.95, -1.4), Vector3(0.18, 0.3, 2), "wall")
			box(room, "SideWall", Vector3(x, 1.5, -2.95), Vector3(0.18, 3, 1.1), "wall")
			box(room, "SideWall", Vector3(x, 1.5, 1.55), Vector3(0.18, 3, 3.9), "wall")
		else:
			box(room, "SideWall", Vector3(x, 1.5, 0), Vector3(0.18, 3, 7), "wall")
		box(room, "Skirting", Vector3(x * 0.965, 0.16, 0), Vector3(0.06, 0.3, 6.9), "wood", false)
	for z in [-2.0, 0.0, 2.0]:
		box(room, "CeilingBeam", Vector3(0, 2.94, z), Vector3(5.9, 0.18, 0.15), "wood", false)
	return room

func build_stash() -> void:
	var room := room_shell(Vector3.ZERO, "Stash")
	var asset := STASH_ASSET.instantiate()
	asset.name = "ImportedDesk"
	asset.position = Vector3(0, 0, -0.85)
	room.add_child(asset)
	lid = asset.find_child("CaseLidPivot", true, false)
	if lid:
		lid_open_rotation = lid.rotation
	# A single invisible collider, separate from export meshes, keeps the GLB reimportable.
	var collider := StaticBody3D.new()
	collider.name = "DeskPhysics"
	collider.position = Vector3(0, 0.405, -0.85)
	room.add_child(collider)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.15, 0.81, 1.43)
	shape.shape = bounds
	collider.add_child(shape)
	case_target = target(room, "CaseTarget", Vector3(-0.39, 1.04, -0.72), Vector3(1.0, 0.7, 0.85), "toggle_case", "合上皮箱")
	door_target = make_door(room, Vector3(2.83, 1.1, 1.65), "进入酒馆", "enter_tavern")
	box(room, "Cabinet", Vector3(-2.48, 0.8, -2.45), Vector3(0.75, 1.6, 1.0), "wood")
	var lamp := point_light(room, Vector3(0.53, 1.39, -1.25), Color("ffc580"), 1.7, 4)
	props.build_stash(room, lamp)
	install_detail(room, STASH_DETAIL)
	point_light(room, Vector3(2.45, 2.1, -1.4), Color("83a6ce"), 0.55, 4)

func build_tavern(room_name := "Tavern", offset := 10.0) -> void:
	var room := room_shell(Vector3(offset, 0, 0), room_name)
	box(room, "BarCounter", Vector3(2.0, 0.57, -1.25), Vector3(0.65, 1.14, 2.8), "wood")
	target(room, "BarService", Vector3(1.54, 1.20, 0.10), Vector3(0.3, 0.6, 0.6), "services", "与酒保交谈 · 服务 / 接应")
	box(room, "BarTop", Vector3(2.0, 1.16, -1.25), Vector3(0.86, 0.10, 3.0), "brass")
	for z in [-2.2, -1.2, -0.2]:
		box(room, "BarStool", Vector3(1.20, 0.37, z), Vector3(0.4, 0.74, 0.4), "wood")
	for y in [1.65, 2.25]:
		box(room, "BottleShelf", Vector3(2.77, y, -1.2), Vector3(0.22, 0.07, 2.7), "wood", false)
		for i in range(8):
			box(room, "Bottle", Vector3(2.72, y + 0.19, -2.3 + i * 0.30), Vector3(0.09, 0.3, 0.09), "green", false)
	box(room, "PokerTable", Vector3(-0.45, 0.76, -0.8), Vector3(2.05, 0.15, 1.4), "wood")
	box(room, "Felt", Vector3(-0.45, 0.842, -0.8), Vector3(1.9, 0.014, 1.25), "green", false)
	for x in [-1.1, 0.2]:
		box(room, "TableLeg", Vector3(x, 0.35, -0.8), Vector3(0.1, 0.7, 0.1), "wood")
	for x in [-1.1, 0.25]:
		box(room, "OpponentChair", Vector3(x, 0.45, -1.9), Vector3(0.52, 0.9, 0.52), "dark")
	cards_root = Node3D.new()
	cards_root.name = "LiveCards"
	room.add_child(cards_root)
	table_target = target(room, "TableSeat", Vector3(-0.45, 1.0, 0.04), Vector3(1.6, 0.50, 0.28), "sit", "坐到牌桌前")
	if room_name == "Tavern":
		make_door(room, Vector3(-2.83, 1.1, 1.65), "查看撤离费用", "enter_stash")
		box(room, "ExitNotice", Vector3(-2.84, 1.6, 2.55), Vector3(0.04, 0.48, 0.55), "ivory", false)
		var notice_text := Label3D.new()
		notice_text.text = "EXIT\n出口告示"
		notice_text.font_size = 48
		notice_text.pixel_size = 0.002
		notice_text.modulate = Color("18221f")
		notice_text.outline_size = 0
		notice_text.position = Vector3(-2.805, 1.6, 2.55)
		notice_text.rotation.y = PI / 2
		room.add_child(notice_text)
		exit_notice = target(room, "ExitNoticeTarget", Vector3(-2.73, 1.6, 2.55), Vector3(0.16, 0.52, 0.59), "discover_exit", "查看出口告示")
		preload("res://three_d/scripts/tavern_layout.gd").build(self, room)
		ledger_door = make_door(room, Vector3(2.83, 1.1, 1.65), "前往账房地窖 · 需完成货运桌", "enter_ledger")
	else:
		make_door(room, Vector3(-2.83, 1.1, 1.65), "返回烟雾酒馆", "back_tavern")
	install_detail(room, TAVERN_DETAIL)
	props.build_tavern(room, room_name)
	bar_display.build(room)
	seat_camera = Camera3D.new()
	seat_camera.name = "SeatCamera"
	room.add_child(seat_camera)
	seat_camera.position = Vector3(-0.45, 1.42, 0.65)
	seat_camera.rotation.x = -0.38
	seat_camera.fov = 65
	table_rooms[room_name] = {"cards": cards_root, "camera": seat_camera, "target": table_target}
	point_light(room, Vector3(-0.45, 2.45, -0.8), Color("ffe1a8"), 2.2, 4.2)
	point_light(room, Vector3(1.8, 2.4, -1.3), Color("d9b782"), 1.0, 4)

func target(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, action: StringName, caption: String) -> Area3D:
	var anchor := Interactable.new()
	anchor.name = node_name
	anchor.action_id = action
	anchor.title = caption
	anchor.position = pos
	anchor.collision_layer = 2
	anchor.collision_mask = 0
	parent.add_child(anchor)
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collision.shape = bounds
	anchor.add_child(collision)
	return anchor

func make_door(room: Node3D, pos: Vector3, caption: String, action: StringName) -> Area3D:
	box(room, "Door", pos, Vector3(0.10, 2.2, 1.05), "wood", false)
	var side := -1.0 if pos.x > 0 else 1.0
	box(room, "DoorHandle", pos + Vector3(0.10 * side, 0, 0.30), Vector3(0.10, 0.04, 0.15), "brass", false)
	return target(room, "DoorTarget", pos + Vector3(0.12 * side, 0, 0), Vector3(0.20, 2.1, 1.05), action, caption)

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171d22")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b0b7c0")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

func point_light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = true
	parent.add_child(light)
	return light

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	title_label = label(ui, "藏匿点", 30)
	title_label.position = Vector2(32, 25)
	explore_instructions = label(ui, "WASD 行走   ·   鼠标观察   ·   E 交互   ·   B 背包   ·   Esc 暂停", 18)
	explore_instructions.position = Vector2(32, 67)
	economy_label = label(ui, "", 17)
	economy_label.position = Vector2(32, 100)
	crosshair = label(ui, "+", 22)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(7, 15)
	hint_label = label(ui, "", 23)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -350
	hint_label.offset_right = 350
	hint_label.offset_top = -105
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_panel = make_panel(ui, "已暂停", "", "继续探索", resume)
	seat_panel = TableHUD.new()
	ui.add_child(seat_panel)
	seat_panel.start_requested.connect(start_table)
	seat_panel.action_requested.connect(play_action)
	seat_panel.continue_requested.connect(continue_hand)
	seat_panel.leave_requested.connect(leave_seat)
	run_panel = make_panel(ui, "准备出发", "", "确认", confirm_run_action)
	run_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	run_panel.offset_left = -350
	run_panel.offset_right = 350
	run_panel.offset_top = -270
	run_panel.offset_bottom = 270
	var column: VBoxContainer = run_panel.get_child(0).get_child(0)
	run_heading = column.get_child(0)
	run_confirm = column.get_child(1)
	run_body = label(column, "", 19)
	column.move_child(run_body, 1)
	var cancel := Button.new()
	cancel.text = "返回探索"
	cancel.custom_minimum_size.y = 40
	cancel.pressed.connect(close_run_panel)
	column.add_child(cancel)
	var routes_button := Button.new()
	routes_button.text = "查看背包与已知路线（B）"
	routes_button.custom_minimum_size.y = 36
	routes_button.pressed.connect(func(): close_run_panel(); open_services())
	column.add_child(routes_button)
	forfeit_button = Button.new()
	forfeit_button.text = "无法撤离：查看放弃本局的损失"
	forfeit_button.custom_minimum_size.y = 36
	forfeit_button.pressed.connect(func(): show_run_panel("abandon"))
	column.add_child(forfeit_button)
	forfeit_button.hide()
	services_panel = ServicesHUD.new()
	ui.add_child(services_panel)
	services_panel.requested.connect(service_action)
	services_panel.closed.connect(close_services)
	services_panel.hide()
	save_notice = label(ui, "", 15)
	save_notice.position = Vector2(32, 126)
	run_panel.hide()
	pause_panel.hide()
	seat_panel.hide()

func label(parent: Node, content: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("f0dfb4"))
	node.add_theme_color_override("font_shadow_color", Color.BLACK)
	node.add_theme_constant_override("shadow_offset_x", 2)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func make_panel(parent: Control, heading: String, body: String, button_label: String, callback: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -230
	panel.offset_bottom = -65
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	label(column, heading, 24)
	if not body.is_empty():
		label(column, body, 18)
	var button := Button.new()
	button.text = button_label
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	column.add_child(button)
	return panel

func show_focus(focus: Area3D) -> void:
	if hint_label:
		hint_label.text = focus.prompt() if is_instance_valid(focus) else ""

func request_action(anchor: Area3D) -> bool:
	if paused or run_panel.visible or services_panel.visible or seated or action_busy or not player.can_interact(anchor):
		return false
	if str(anchor.action_id).begins_with("prop:"):
		props.interact(str(anchor.action_id).trim_prefix("prop:"))
		return true
	if str(anchor.action_id).begins_with("shop:"):
		open_services("product", str(anchor.action_id).trim_prefix("shop:"))
		return true
	if str(anchor.action_id).begins_with("route:"):
		show_run_panel(anchor.action_id)
		return true
	match anchor.action_id:
		"toggle_case":
			if not is_instance_valid(lid):
				return false
			action_busy = true
			case_open = not case_open
			var goal := lid_open_rotation if case_open else lid_open_rotation + Vector3(deg_to_rad(102), 0, 0)
			var tween := create_tween()
			tween.tween_property(lid, "rotation", goal, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func(): action_busy = false)
			anchor.title = "合上皮箱" if case_open else "打开皮箱"
			show_focus(anchor)
		"services":
			open_services("bar")
		"enter_tavern":
			show_run_panel("enter")
		"enter_stash":
			show_run_panel("extract")
		"enter_ledger":
			if "cargo-table" not in run_game.completed:
				hint_label.text = "先完成货运桌并离座"
				return false
			travel("ledger")
		"back_tavern":
			travel("tavern")
		"discover_exit":
			run_game.discover_exit()
			exit_notice.title = "出口已确认 · 门口可查看撤离费用"
			refresh_economy()
			show_focus(anchor)
		"sit":
			var reason: String = run_game.table_blocked_reason(active_table_id)
			if not reason.is_empty():
				hint_label.text = reason
				return false
			return_transform = player.global_transform
			seated = true
			player.controls_enabled = false
			player.velocity = Vector3.ZERO
			seat_camera.current = true
			seat_panel.pregame(run_game.cash, table_content.tables[active_table_id])
			seat_panel.show()
			explore_instructions.hide()
			crosshair.hide()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_:
			return false
	return true

func travel(destination: String) -> void:
	bar_display.refresh()
	current_room = destination
	select_table_room("LedgerCellar" if destination == "ledger" else "Tavern")
	player.velocity = Vector3.ZERO
	player.position = Vector3(18.0 if destination == "ledger" else 8.0, 0.05, 1.7) if destination != "stash" else Vector3(1.95, 0.05, 1.7)
	player.rotation = Vector3(0, -0.65 if destination != "stash" else 0.55, 0)
	player.camera.rotation = Vector3(-0.10, 0, 0)
	title_label.text = {"tavern": "烟雾酒馆", "ledger": "账房地窖", "stash": "藏匿点"}[destination]
	player.update_focus()
	refresh_economy()

func leave_seat() -> void:
	if paused or not seated or (table_game != null and table_game.state.status != "finished"):
		return
	if table_game != null and not run_game.settle_table(run_game.revision):
		return
	table_game = null
	refresh_economy()
	clear_cards()
	seated = false
	explore_instructions.show()
	player.global_transform = return_transform
	player.controls_enabled = true
	player.camera.current = true
	seat_panel.hide()
	crosshair.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check_pressure()

func toggle_pause() -> void:
	if services_panel.visible:
		close_services()
		return
	if run_panel.visible:
		close_run_panel()
		return
	if paused:
		resume()
		return
	if seated and table_game == null:
		leave_seat()
		return
	pause_game()

func pause_game() -> void:
	paused = true
	player.controls_enabled = false
	if seated:
		seat_panel.hide()
	var buttons := pause_panel.find_children("*", "Button", true, false)
	buttons[0].text = "继续牌局" if seated else "继续探索"
	pause_panel.show()
	crosshair.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	paused = false
	player.controls_enabled = not seated
	pause_panel.hide()
	if seated:
		seat_panel.show()
	crosshair.visible = not seated
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if seated else Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and readiness:
		if not saving_enabled or save_checkpoint():
			get_tree().quit()
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and readiness and not run_panel.visible and not OS.get_cmdline_user_args().has("--test"):
		if saving_enabled:
			save_checkpoint()
		if services_panel.visible:
			close_services()
		if not paused:
			pause_game()

func start_table(seed_value: int = -1) -> void:
	if not seated or table_game != null or paused:
		return
	table_game = run_game.enter_table(int(Time.get_ticks_usec() % 2147483647) if seed_value < 0 else seed_value, run_game.revision, active_table_id)
	if table_game == null:
		return
	refresh_economy()
	table_delay = 0.45
	refresh_table()

func play_action(kind: String, expected_revision: int, raise_target: int = -1) -> void:
	if paused or services_panel.visible or table_game == null or table_delay > 0:
		return
	if table_game.act("player", kind, expected_revision, raise_target):
		table_delay = 0.45
		refresh_table()

func continue_hand(expected_revision: int) -> void:
	if not paused and not services_panel.visible and table_game != null and table_game.next_hand(expected_revision):
		table_delay = 0.45
		refresh_table()

func _process(delta: float) -> void:
	if saving_enabled:
		save_clock += delta
		if save_clock >= 0.5:
			save_clock = 0
			save_checkpoint()
	if services_panel.visible:
		return
	if table_game == null or paused or not seated:
		return
	if table_delay > 0:
		table_delay = maxf(0, table_delay - delta)
		if table_delay == 0:
			seat_panel.refresh(table_game.public_state(), false)
		return
	if table_game.state.status != "playing" or table_game.state.currentActorId == "player":
		return
	advance_table_beat()

func advance_table_beat() -> void:
	if services_panel.visible or table_game == null or paused or table_game.state.status != "playing":
		return
	var actor_id: String = table_game.state.currentActorId
	if actor_id.is_empty():
		table_game.advance(table_game.revision)
	elif actor_id != "player":
		var actor: Dictionary = table_game.find_player(actor_id)
		var decision := OpponentRules.choose(table_game.state, actor, table_game.legal_actions(actor_id), table_content.opponents[actor_id], table_game.rng.next())
		table_game.act(actor_id, decision, table_game.revision)
	else:
		return
	table_delay = 0.55
	refresh_table()

func refresh_table() -> void:
	var view: Dictionary = table_game.public_state()
	seat_panel.refresh(view, table_delay > 0)
	clear_cards()
	for i in range(view.community.size()):
		draw_card(view.community[i], Vector3(-0.89 + i * 0.22, 0.866, -0.80))
	for i in range(view.players[0].holeCards.size()):
		draw_card(view.players[0].holeCards[i], Vector3(-0.60 + i * 0.22, 0.866, -0.17))
	# Bounded visual stacks; exact chip amounts always remain in the HUD.
	for i in range(mini(12, int(view.pot) / 10)):
		var chip := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.032
		mesh.bottom_radius = 0.032
		mesh.height = 0.01
		chip.mesh = mesh
		chip.material_override = materials["brass"]
		chip.position = Vector3(-0.40, 0.87 + i * 0.012, -1.16)
		cards_root.add_child(chip)

func clear_cards() -> void:
	for child in cards_root.get_children():
		cards_root.remove_child(child)
		child.queue_free()

func draw_card(card: Dictionary, pos: Vector3) -> void:
	var node := box(cards_root, "Card", pos, Vector3(0.18, 0.008, 0.25), "ivory", false)
	var text := Label3D.new()
	text.text = TableHUD.card_text(card)
	text.font_size = 64
	text.pixel_size = 0.00125
	text.outline_size = 0
	text.modulate = Color("b92329") if card.suit in ["H", "D"] else Color("18221f")
	text.position = Vector3(0, 0.006, 0)
	text.rotation.x = -PI / 2
	node.add_child(text)

func refresh_economy() -> void:
	if run_game.active:
		economy_label.text = "金库 %d  ·  随身 %d  ·  风声 %d / 6  ·  出口%s" % [run_game.vault, run_game.cash, run_game.heat, "已知" if run_game.public_exit else "未知：查看门旁告示"]
	elif not run_game.last_result.is_empty():
		var result: Dictionary = run_game.last_result
		economy_label.text = "金库 %d  ·  上局到账 %d / 费用 %d / 净变化 %+d" % [run_game.vault, result.net, result.fee, result.profit]
		if result.get("forced", false):
			economy_label.text += " · 风声封锁，已触发紧急结算"
	else:
		economy_label.text = "金库 %d  ·  每次最多带出 300  ·  自动存档，可关闭后继续" % run_game.vault

func show_run_panel(action: String, preview_only := false) -> void:
	selected_route = action.trim_prefix("route:") if action.begins_with("route:") else "general"
	run_action = "extract" if action.begins_with("route:") else action
	run_revision = run_game.revision
	run_confirm.disabled = false
	forfeit_button.hide()
	if action == "enter":
		run_heading.text = "前往烟雾酒馆"
		var amount := mini(int(table_content.standardBankroll), int(run_game.vault))
		run_body.text = "金库 %d → %d，随身带出 %d。\n货运桌买入 60；撤离需要找到门旁的出口告示。\n自动存档，可关闭后继续。" % [run_game.vault, run_game.vault - amount, amount]
		run_confirm.text = "带钱出发"
		if run_game.vault < 120:
			run_action = "reset"
			run_body.text = "金库不足 120，暂时无法出发。\n可将试玩资金重置为 1,200，再开始新局。"
			run_confirm.text = "重置试玩资金"
	elif action == "abandon":
		run_heading.text = "放弃本局"
		run_body.text = "损失随身现金 %d 及全部背包物品。\n夹层钱包可保留至多 80 现金；其余损失。\n当前金库 %d。\n确认后返回藏匿点，这笔损失会保存。" % [run_game.cash, run_game.vault]
		run_confirm.text = "确认放弃并损失随身财物"
	else:
		var quote: Dictionary = run_game.extraction_quote(selected_route)
		run_heading.text = run_game.Routes.NAMES[selected_route] + " · 撤离结算"
		run_body.text = "现金 %d · 费用 %d\n舍弃现金 %d · 舍弃贵重物价值 %d\n带回贵重物 %d · 最终到账 %d\n本局净变化 %+d" % [run_game.cash, quote.fee, quote.lostCash, quote.lostGoods, quote.valuables, quote.net, quote.net - run_game.bankroll]
		run_confirm.text = "支付费用并返回藏匿点"
		if not quote.reason.is_empty():
			run_body.text += "\n" + quote.reason
			run_confirm.disabled = true
			forfeit_button.visible = run_game.active and run_game.table == null
	if preview_only:
		run_confirm.disabled = true
		run_confirm.text = "到实际入口按 E 撤离"
		run_body.text += "\n" + {"general":"大厅入口门旁。", "fixed":"后勤通道直走到库房，右侧货梯。", "service-stairs":"后勤通道左转，经后厨楼梯上楼。", "river-launch":"后勤通道右转，沿装卸坡道下到河边。", "dropbag-cash":"后勤走廊最左端的检修口。", "dropbag-valuables":"后勤走廊最左端的检修口。"}.get(selected_route, "")
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	crosshair.hide()
	hint_label.text = ""
	run_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_run_panel() -> void:
	run_panel.hide()
	run_action = ""
	player.controls_enabled = not paused and not seated
	crosshair.visible = not paused and not seated
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if player.controls_enabled else Input.MOUSE_MODE_VISIBLE

func confirm_run_action() -> void:
	if not run_panel.visible or paused or run_confirm.disabled:
		return
	if run_action == "enter":
		if not run_game.start(run_revision):
			return
		exit_notice.title = "查看出口告示"
		close_run_panel()
		travel("tavern")
	elif run_action == "extract":
		if not run_game.extract(run_revision, selected_route):
			return
		close_run_panel()
		travel("stash")
	elif run_action == "abandon":
		if not run_game.abandon(run_revision):
			return
		close_run_panel()
		travel("stash")
	elif run_action == "reset":
		if run_game.reset_demo(run_revision):
			refresh_economy()
			show_run_panel("enter")

func select_table_room(room_name: String) -> void:
	var setup: Dictionary = table_rooms[room_name]
	cards_root = setup.cards
	seat_camera = setup.camera
	table_target = setup.target
	active_table_id = "ledger-cellar" if room_name == "LedgerCellar" else "cargo-table"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if services_panel.visible:
			close_services()
		else:
			open_services()
		get_viewport().set_input_as_handled()

func open_services(mode := "bag", item := "") -> void:
	if paused or run_panel.visible:
		return
	service_mode = mode
	product_id = item
	services_panel.refresh(run_game.service_view(service_mode, product_id))
	services_panel.show()
	hint_label.text = ""
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	seat_panel.hide()
	crosshair.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_services() -> void:
	services_panel.hide()
	player.controls_enabled = not seated and not paused
	seat_panel.visible = seated and not paused
	crosshair.visible = player.controls_enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if player.controls_enabled else Input.MOUSE_MODE_VISIBLE

func service_action(kind: String, item_id: String, revision: int, target_id := "") -> void:
	if not services_panel.visible or paused:
		return
	var offered := false
	for action in run_game.service_view(service_mode, product_id).actions:
		if action.kind == kind and action.id == item_id and action.get("target", "") == target_id:
			offered = true
	if not offered:
		return
	if kind == "route":
		close_services()
		show_run_panel("route:" + item_id, true)
		return
	if run_game.service_action(kind, item_id, revision, target_id):
		refresh_economy()
		if table_game != null:
			refresh_table()
		services_panel.refresh(run_game.service_view(service_mode, product_id))
		bar_display.refresh()
		if kind == "buy":
			close_services()
			var focus: Vector3 = Vector3(21.57 if current_room == "ledger" else 11.57, 1.34, 0.4) - player.camera.global_position
			player.rotation.y = atan2(-focus.x, -focus.z)
			player.camera.rotation = Vector3(atan2(focus.y, Vector2(focus.x, focus.z).length()), 0, 0)
			bar_display.deliver(item_id)
			hint_label.text = "酒保递给你：" + run_game.item_name(item_id) + " · 已放入背包（B）"
			var feedback := create_tween()
			feedback.tween_interval(2.0)
			feedback.tween_callback(func():
				if not services_panel.visible and not run_panel.visible:
					show_focus(player.focused))
		check_pressure()

func checkpoint_state() -> Dictionary:
	return {"run": RunCheckpoint.capture(run_game), "room": current_room, "player": player.global_transform, "look": player.camera.rotation, "seated": seated, "return": return_transform, "caseOpen": case_open, "props": props.states.duplicate()}

func save_checkpoint() -> bool:
	var state := checkpoint_state()
	var bytes := var_to_bytes(state)
	if bytes == last_saved:
		return true
	var error := SaveStore.write_checkpoint(save_path, state)
	if error != OK:
		save_notice.text = "保存失败：%s，请保留窗口并检查磁盘" % error_string(error)
		return false
	last_saved = bytes
	save_notice.text = "已自动保存"
	return true

func load_checkpoint() -> void:
	var loaded := SaveStore.read_checkpoint(save_path)
	if loaded.status == "missing":
		saving_enabled = true
		return
	if loaded.status != "ok" or not restore_checkpoint(loaded.state):
		save_notice.text = "存档损坏或版本不兼容，已保留原文件；本次不覆盖存档"
		saving_enabled = false
		return
	saving_enabled = true
	pause_game()
	save_notice.text = "已恢复进度，点击继续"

func restore_checkpoint(state: Dictionary) -> bool:
	if state.get("room") not in ["stash", "tavern", "ledger"] or not state.get("player") is Transform3D or not state.get("look") is Vector3 or not state.get("return") is Transform3D or not state.get("seated") is bool or not state.get("run") is Dictionary or not state.get("caseOpen") is bool:
		return false
	var restored := RunCheckpoint.restore(state.run, table_content)
	if restored == null:
		return false
	if (state.room == "stash") == restored.active or (restored.table != null and not state.seated):
		return false
	if restored.table != null and restored.table.state.tableDef.id != ("ledger-cellar" if state.room == "ledger" else "cargo-table"):
		return false
	run_game = restored
	props.restore(state.get("props", {}))
	case_open = state.caseOpen
	lid.rotation = lid_open_rotation if case_open else lid_open_rotation + Vector3(deg_to_rad(102), 0, 0)
	case_target.title = "合上皮箱" if case_open else "打开皮箱"
	travel(state.room)
	player.global_transform = state.player
	player.camera.rotation = state.look
	return_transform = state.return
	seated = state.seated
	table_game = run_game.table
	if seated:
		seat_camera.current = true
		player.controls_enabled = false
		explore_instructions.hide()
		seat_panel.show()
		if table_game != null:
			refresh_table()
		else:
			seat_panel.pregame(run_game.cash, table_content.tables[active_table_id])
	refresh_economy()
	return true

func check_pressure() -> void:
	if run_game.enforce_pressure():
		if services_panel.visible:
			close_services()
		travel("stash")

func install_detail(room: Node3D, asset: PackedScene) -> void:
	# Keep all collision bodies and interaction anchors; replace only their visible meshes.
	for node in room.get_children():
		if str(node.get_meta("visual_role", "")).begins_with("Floor") or (room.name != "Stash" and ["PokerTable", "Felt", "TableLeg", "OpponentChair", "BarCounter", "BarTop", "BarStool", "BottleShelf", "Bottle"].any(func(prefix): return str(node.get_meta("visual_role", "")).begins_with(prefix))):
			for child in node.get_children():
				if child is MeshInstance3D:
					child.hide()
	var detail := asset.instantiate()
	detail.name = "BlenderDetail"
	room.add_child(detail)

func make_detailed_prop(id: String) -> Node3D:
	var kit := PROPS_ASSET.instantiate()
	var item: Node3D = kit.get_node(id)
	kit.remove_child(item)
	kit.free()
	return item

func install_prop(parent: Node3D, id: String) -> void:
	for child in parent.get_children():
		if child is Node3D and not child is Area3D:
			child.hide()
	parent.add_child(make_detailed_prop(id))
