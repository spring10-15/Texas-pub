extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	var collider: CollisionShape3D = world.player.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.collision_mask = world.player.collision_mask
	query.exclude = [world.player.get_rid()]
	query.transform = collider.global_transform
	check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "initial spawn capsule clear")
	for room in ["stash", "tavern", "ledger", "mirror", "embers"]:
		world.travel(room)
		await physics_frame
		query.transform = collider.global_transform
		var hits: Array = world.get_world_3d().direct_space_state.intersect_shape(query)
		check(hits.is_empty(), "landing capsule clear: " + room)
	# Negative control inside a known wall, using the same capsule and physics mask.
	world.player.position = Vector3(3.1, 0.05, 0)
	await physics_frame
	query.transform = collider.global_transform
	check(not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "wall penetration detected")
	world.queue_free()
	await process_frame
	print("LANDING_COLLISION checks=", checks, " failed=", failures.size())
	quit(0 if failures.is_empty() else 1)
