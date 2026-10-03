extends SceneTree
## Run this external script with --main-pack, outside the project directory.
var failures := 0
var checked := 0

func _initialize() -> void:
	checked += 1
	if ProjectSettings.get_setting("application/run/main_scene", "") != "res://three_d/scenes/main.tscn":
		failures += 1
		push_error("Player pack has an unexpected main scene")
	checked += 1
	if FileAccess.file_exists("res://soak_main.gd") or FileAccess.file_exists("res://soak_main.tscn"):
		failures += 1
		push_error("Automated soak entry included in player pack")
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	if not content is Dictionary:
		push_error("Pack is missing readable content.json")
		quit(1)
		return
	var ids: Array = content.opponents.keys()
	ids.append("bartender")
	for id in ids:
		var path := "res://three_d/assets/characters/%s.glb" % id
		var resource = load(path)
		checked += 1
		if not resource is PackedScene:
			failures += 1
			push_error("Cannot load packed character: " + path)
		else:
			var instance = resource.instantiate()
			if instance == null: failures += 1
			else: instance.free()
	for tile in ["walnut", "plaster", "leather", "fabric"]:
		for channel in ["color", "normal", "roughness"]:
			checked += 1
			if load("res://three_d/assets/materials/%s-%s.png" % [tile, channel]) == null: failures += 1
	for path in ["res://three_d/assets/interactive-props.glb", "res://three_d/assets/tavern-detail.glb", "res://three_d/assets/stash-room-detail.glb", "res://three_d/assets/stash.glb", "res://three_d/scenes/main.tscn"]:
		checked += 1
		if load(path) == null: failures += 1
	for path in ["res://three_d/tests", "res://three_d/tools"]:
		if DirAccess.dir_exists_absolute(path):
			failures += 1
			push_error("Development directory included in pack: " + path)
	print("Export pack: %d resources checked, %d failures" % [checked, failures])
	quit(1 if failures else 0)
