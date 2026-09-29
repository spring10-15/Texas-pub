extends SceneTree
## Export current interaction positions without changing the game or saved runs.

const ROOM_NAMES := ["Stash", "Tavern", "LedgerCellar", "MirrorHall", "EmbersRoom"]

func _initialize() -> void:
	call_deferred("run")

func xyz(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]

func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	var anchors := []
	var per_room := {}
	for room_name in ROOM_NAMES:
		var room: Node3D = world.get_node(room_name)
		var count := 0
		for anchor in room.find_children("*", "Area3D", true, false):
			if not anchor is Area3D or not anchor.has_method("prompt"):
				continue
			var bounds := []
			for child in anchor.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D:
					bounds = xyz(child.shape.size)
					break
			anchors.append({
				"room": room_name,
				"path": str(room.get_path_to(anchor)),
				"action_id": str(anchor.action_id),
				"local_position_m": xyz(room.to_local(anchor.global_position)),
				"world_position_m": xyz(anchor.global_position),
				"box_size_m": bounds,
			})
			count += 1
		per_room[room_name] = count
	var path := ProjectSettings.globalize_path("res://../output/3d/phase-3-interaction-anchors.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rooms": per_room, "anchors": anchors}, "\t") + "\n")
	print("ANCHOR_EXPORT ", anchors.size(), " ", path)
	quit()
