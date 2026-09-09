extends RefCounted
var world: Node3D
var displays := {}
var hands := {}
func _init(owner: Node3D) -> void:
	world = owner
func build(room: Node3D) -> void:
	var display := Node3D.new()
	display.name = "ShopObjects"
	room.add_child(display)
	displays[room.name] = display
	# Deliberately coarse attendant and a handoff surface, ready for a rigged character later.
	world.box(room, "BartenderTorso", Vector3(2.55, 1.25, 0.4), Vector3(0.38, 0.62, 0.34), "cloth", false)
	world.box(room, "BartenderHead", Vector3(2.55, 1.74, 0.4), Vector3(0.24, 0.3, 0.24), "ivory", false)
	var hand: Node3D = world.box(room, "BartenderHand", Vector3(2.2, 0.95, 0.4), Vector3(0.38, 0.12, 0.14), "cloth", false)
	hands[room.name] = hand
	refresh()
func refresh() -> void:
	for room_id in displays:
		var display: Node3D = displays[room_id]
		for child in display.get_children():
			display.remove_child(child)
			child.queue_free()
		var stock: Array = world.run_game.shop_stock()
		for i in range(stock.size()):
			var id: String = stock[i]
			var pos := Vector3(2.55, 1.88, -2.3 + i * 0.38)
			var prop := make_item(display, id, pos)
			var label := Label3D.new()
			label.text = "%s\n%d" % [world.run_game.item_name(id), world.table_content.items[id].buy]
			label.font_size = 32
			label.pixel_size = 0.0018
			label.position = Vector3(-0.13, 0.22, 0)
			label.rotation.y = -PI / 2
			prop.add_child(label)
			world.target(display, "ShelfItem", pos + Vector3(-0.12, 0, 0), Vector3(0.18, 0.3, 0.3), "shop:" + id, "%s · 查看 / 购买" % world.run_game.item_name(id))
func deliver(id: String) -> void:
	var room_id := "LedgerCellar" if world.current_room == "ledger" else "Tavern"
	var room: Node3D = displays[room_id].get_parent()
	var prop := make_item(room, id, Vector3(2.2, 0.85, 0.4))
	var hand: Node3D = hands[room_id]
	var tween := world.create_tween()
	tween.set_parallel(true)
	tween.tween_property(prop, "position", Vector3(1.57, 1.34, 0.4), 0.6)
	tween.tween_property(hand, "position", Vector3(1.85, 1.25, 0.4), 0.6)
	tween.chain().tween_interval(0.65)
	tween.chain().tween_property(prop, "scale", Vector3.ONE * 0.05, 0.25)
	tween.parallel().tween_property(hand, "position", Vector3(2.2, 0.95, 0.4), 0.4)
	tween.chain().tween_callback(prop.queue_free)

func make_item(parent: Node3D, id: String, pos: Vector3) -> Node3D:
	var item := Node3D.new()
	item.position = pos
	parent.add_child(item)
	if id == "steadying-drink":
		var bottle := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.045
		shape.bottom_radius = 0.075
		shape.height = 0.23
		bottle.mesh = shape
		bottle.material_override = world.materials.green
		item.add_child(bottle)
		world.box(item, "BottleNeck", Vector3(0, 0.15, 0), Vector3(0.045, 0.1, 0.045), "brass", false)
	elif id in ["disposable-phone", "player-notes", "false-bottom-wallet", "kitchen-pass", "dock-passkey"]:
		world.box(item, "Body", Vector3.ZERO, Vector3(0.055, 0.2, 0.14), "dark" if id in ["disposable-phone", "false-bottom-wallet"] else "cloth", false)
		world.box(item, "Face", Vector3(-0.03, 0.025, 0), Vector3(0.008, 0.11, 0.10), "green" if id == "disposable-phone" else "ivory", false)
		world.box(item, "Binding", Vector3(-0.035, -0.07, 0), Vector3(0.009, 0.013, 0.11), "brass", false)
	else:
		world.box(item, "Tool", Vector3.ZERO, Vector3(0.06, 0.15, 0.09), "brass", false)
		world.box(item, "ToolInset", Vector3(-0.035, 0.035, 0), Vector3(0.008, 0.06, 0.07), "dark", false)
	return item
