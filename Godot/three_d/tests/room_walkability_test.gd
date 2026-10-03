extends SceneTree
var world: Node3D
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void: call_deferred("run")
func walk(local: Vector2, offset: float, label: String, floor_height := 0.0) -> void:
	var destination := Vector2(offset + local.x, local.y)
	var frames := 0
	while Vector2(world.player.position.x, world.player.position.z).distance_to(destination) > 0.12 and frames < 300:
		var direction := Vector3(destination.x - world.player.position.x, 0, destination.y - world.player.position.z)
		world.player.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press("move_forward")
		await physics_frame
		frames += 1
	Input.action_release("move_forward")
	for i in range(3): await physics_frame
	verify(frames < 300, "Continuous walk reaches " + label)
	verify(world.player.is_on_floor() and absf(world.player.position.y - floor_height) < 0.15, "Walk remains on room floor: " + label)
func focus(anchor: Area3D, label: String) -> void:
	world.player.camera.look_at(anchor.global_position)
	for i in range(3): await physics_frame
	world.player.update_focus()
	verify(world.player.focused == anchor, "Walked position can focus " + label)
func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.player.controls_enabled = true
	# Room entry uses production travel; all subsequent movement uses WASD input.
	world.travel("stash")
	await walk(Vector2(0.3, 0.6), 0, "stash case")
	await focus(world.case_target, "stash case")
	await walk(Vector2(1.95, 1.7), 0, "stash door")
	await focus(world.door_target, "stash door")
	for room in ["tavern", "ledger", "mirror", "embers"]:
		world.travel(room)
		var offset: float = world.ROOMS[room].x
		var node: Node3D = world.get_node(world.ROOMS[room].node)
		await walk(Vector2(-1.8, 0.7), offset, room + " front aisle")
		await walk(Vector2(-0.45, 0.65), offset, room + " table")
		await focus(node.get_node("TableSeat"), room + " table")
		await walk(Vector2(1.2, 0.65), offset, room + " bar")
		await focus(node.get_node("BarService"), room + " bar")
		await walk(Vector2(-1.8, 0.7), offset, room + " left aisle")
		await walk(Vector2(-1.8, -2.1), offset, room + " search cabinet")
		await focus(node.get_node("SearchSite"), room + " search cabinet")
		if room == "tavern":
			await walk(Vector2(-1.8, -2.65), offset, "rear aisle")
			await walk(Vector2(0, -2.65), offset, "hall doorway")
			await walk(Vector2(0, -7), offset, "service junction")
			await walk(Vector2(-2.75, -7), offset, "maintenance hatch")
			await focus(node.get_node("EmergencyCash"), "maintenance cash exit")
			await focus(node.get_node("EmergencyGoods"), "maintenance goods exit")
			await walk(Vector2(-2.75, -8.6), offset, "kitchen preparation area")
			await walk(Vector2(-2.75, -12.25), offset, "upper kitchen exit", 1.2)
			await focus(node.get_node("KitchenExit"), "upper kitchen exit")
			await walk(Vector2(-2.75, -7), offset, "kitchen stair return")
			await walk(Vector2(0, -7), offset, "storeroom junction")
			await walk(Vector2(0, -11.6), offset, "loading lift")
			await focus(node.get_node("FixedExit"), "loading lift")
			await walk(Vector2(0, -7), offset, "loading corridor junction")
			await walk(Vector2(2.75, -7), offset, "loading ramp entrance")
			await walk(Vector2(2.75, -13), offset, "river quay", -1.2)
			await focus(node.get_node("RiverExit"), "river quay")
			await walk(Vector2(2.75, -7), offset, "loading ramp return")
			await walk(Vector2(0, -7), offset, "service hall return")
			await walk(Vector2(0, -2.65), offset, "hall doorway return")
			await walk(Vector2(-1.8, -2.65), offset, "rear aisle return")
		await walk(Vector2(-1.8, 1.7), offset, room + " return door")
		var doors: Array = node.get_children().filter(func(child): return child is Area3D and str(child.action_id) in ["enter_stash", "back_tavern"])
		verify(doors.size() == 1, "One return door in " + room)
		if doors.size() == 1: await focus(doors[0], room + " return door")
	world.queue_free()
	await process_frame
	print("ROOM_WALKABILITY checks=", checks, " failed=", failures.size())
	quit(0 if failures.is_empty() else 1)
