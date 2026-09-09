extends RefCounted
var world: Node3D
var entries := {}
var states := {}
var rain: CPUParticles3D
func _init(owner: Node3D) -> void:
	world = owner
func register(id: String, node: Node3D, anchor: Area3D, property: String, closed: Variant, opened: Variant) -> void:
	entries[id] = {"node":node, "anchor":anchor, "property":property, "closed":closed, "opened":opened}
	states[id] = false
func interact(id: String) -> void:
	var entry: Dictionary = entries[id]
	states[id] = not states[id]
	world.action_busy = true
	var tween := world.create_tween()
	tween.tween_property(entry.node, entry.property, entry.opened if states[id] else entry.closed, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): world.action_busy = false)
func restore(values: Dictionary) -> void:
	for id in entries:
		states[id] = bool(values.get(id, false))
		var entry: Dictionary = entries[id]
		entry.node.set_indexed(NodePath(entry.property), entry.opened if states[id] else entry.closed)
func build_stash(room: Node3D, lamp: OmniLight3D) -> void:
	var anchor: Area3D = world.target(room, "LampSwitch", Vector3(0.55, 1.35, -1.15), Vector3(0.22, 0.55, 0.22), "prop:lamp", "台灯 · 开关")
	register("lamp", lamp, anchor, "light_energy", 1.7, 0.0)
	for i in range(3):
		var drawer := Node3D.new()
		drawer.position = Vector3(-2.47, 0.42 + i * 0.4, -1.93)
		room.add_child(drawer)
		world.box(drawer, "DrawerFront", Vector3.ZERO, Vector3(0.64, 0.32, 0.035), "dark", false)
		world.box(drawer, "Pull", Vector3(0, 0, 0.05), Vector3(0.18, 0.035, 0.06), "brass", false)
		world.box(drawer, "DrawerTray", Vector3(0, -0.14, -0.25), Vector3(0.6, 0.035, 0.5), "wood", false)
		world.box(drawer, "Letter", Vector3(0, -0.11, -0.2), Vector3(0.3, 0.015, 0.18), "ivory", false)
		var id := "drawer" + str(i)
		anchor = world.target(drawer, "DrawerTarget", Vector3(0, 0, 0.08), Vector3(0.63, 0.32, 0.10), "prop:" + id, "抽屉 · 拉开 / 推回")
		register(id, drawer, anchor, "position", drawer.position, drawer.position + Vector3(0, 0, 0.4))
		world.install_prop(drawer, "drawer")
	# A hinged sash sits inside a real wall opening; the sill prevents walking outside.
	var window := Node3D.new()
	window.position = Vector3(2.84, 1.9, -2.3)
	room.add_child(window)
	for z in [0.0, 1.8]:
		world.box(window, "Sash", Vector3(0, 0, z), Vector3(0.07, 1.6, 0.07), "wood", false)
	for y in [-0.8, 0.8]:
		world.box(window, "Sash", Vector3(0, y, 0.9), Vector3(0.07, 0.07, 1.8), "wood", false)
	var pane: Node3D = world.box(window, "Glass", Vector3(0, 0, 0.9), Vector3(0.018, 1.5, 1.7), "dark", false)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.4, 0.58, 0.65, 0.22)
	glass.roughness = 0.16
	pane.get_child(0).material_override = glass
	world.box(window, "Latch", Vector3(-0.06, 0, 1.55), Vector3(0.1, 0.2, 0.06), "brass", false)
	anchor = world.target(room, "WindowLatch", Vector3(2.7, 1.75, -0.72), Vector3(0.2, 0.55, 0.25), "prop:window", "窗户 · 打开 / 关上")
	register("window", window, anchor, "rotation:y", 0.0, -0.95)
	world.box(room, "WetStreet", Vector3(4.4, 0, -1.3), Vector3(2.7, 0.12, 5), "dark", false)
	world.box(room, "OppositeFacade", Vector3(5.7, 2, -1.3), Vector3(0.2, 4, 5), "wall", false)
	for z in [-2.5, -0.7, 1.1]:
		world.box(room, "StreetWindow", Vector3(5.55, 2.4, z), Vector3(0.05, 1.1, 0.65), "ivory", false)
	world.point_light(room, Vector3(4.3, 2.8, -1.5), Color("93b2ce"), 1.6, 5)
	rain = CPUParticles3D.new()
	rain.position = Vector3(4.2, 3, -1.4)
	rain.amount = 200
	rain.lifetime = 0.65
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(1, 0.1, 2)
	rain.direction = Vector3(0, -1, 0)
	rain.initial_velocity_min = 4
	rain.initial_velocity_max = 6
	var drop := BoxMesh.new()
	drop.size = Vector3(0.009, 0.13, 0.009)
	rain.mesh = drop
	rain.material_override = world.materials.ivory
	room.add_child(rain)
	var card := Node3D.new()
	card.position = Vector3(0.55, 0.83, -0.18)
	room.add_child(card)
	world.box(card, "CardFace", Vector3.ZERO, Vector3(0.12, 0.006, 0.18), "ivory", false)
	world.box(card, "CardBack", Vector3(0, -0.004, 0), Vector3(0.118, 0.003, 0.178), "green", false)
	var face := Label3D.new()
	face.text = "A ♠"
	face.font_size = 40
	face.pixel_size = 0.001
	face.position.y = 0.005
	face.rotation.x = -PI / 2
	face.modulate = Color("18221f")
	card.add_child(face)
	anchor = world.target(room, "LooseCard", card.position + Vector3(0, 0.04, 0), Vector3(0.16, 0.10, 0.22), "prop:card", "桌上扑克牌 · 翻面")
	register("card", card, anchor, "rotation:z", 0.0, PI)
	world.install_prop(card, "loose-card")
	var chip := Node3D.new()
	chip.position = Vector3(0.88, 0.845, -0.35)
	room.add_child(chip)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.065
	cylinder.bottom_radius = 0.065
	cylinder.height = 0.02
	mesh.mesh = cylinder
	mesh.material_override = world.materials.brass
	chip.add_child(mesh)
	world.box(chip, "ChipStripe", Vector3(0, 0.012, 0), Vector3(0.1, 0.004, 0.02), "dark", false)
	anchor = world.target(room, "LooseChip", chip.position, Vector3(0.17, 0.12, 0.17), "prop:chip", "桌上筹码 · 转动")
	register("chip", chip, anchor, "rotation:y", 0.0, PI * 1.5)
	world.install_prop(chip, "loose-chip")
func build_tavern(room: Node3D, prefix: String) -> void:
	var sconce: OmniLight3D = world.point_light(room, Vector3(-2.7, 2.1, -1.3), Color("ffca85"), 0.8, 3)
	var anchor: Area3D = world.target(room, "SconceSwitch", Vector3(-2.78, 1.4, -1.3), Vector3(0.18, 0.22, 0.18), "prop:" + prefix + "light", "壁灯 · 开关")
	world.box(room, "SwitchPlate", anchor.position, Vector3(0.06, 0.18, 0.13), "brass", false)
	register(prefix + "light", sconce, anchor, "light_energy", 0.8, 0.0)
	var cupboard: Node3D = world.box(room, "Cupboard", Vector3(-2.6, 0.55, 0.5), Vector3(0.6, 1.1, 0.65), "wood")
	var door := Node3D.new()
	door.position = Vector3(0.32, 0, -0.31)
	cupboard.add_child(door)
	world.box(door, "Door", Vector3(0, 0, 0.31), Vector3(0.03, 0.9, 0.62), "green", false)
	anchor = world.target(room, "CupboardTarget", Vector3(-2.22, 0.75, 0.5), Vector3(0.14, 0.8, 0.6), "prop:" + prefix + "cupboard", "餐具柜 · 开合")
	register(prefix + "cupboard", door, anchor, "rotation:y", 0.0, -1.2)
