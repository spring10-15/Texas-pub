extends SceneTree
## Compare consecutive seeds in one venue without changing gameplay or player saves.
const Run = preload("res://three_d/rules/run.gd")
const FIRST_SEED := 1
const LAST_SEED := 100

func _initialize() -> void:
	call_deferred("run")

func plan_for(content: Dictionary, scene: String, seed_value: int) -> Dictionary:
	var session := Run.new(content)
	if not session.start(session.revision, scene, seed_value):
		return {}
	return session.variant_plan

func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var venues := {}
	for scene in Run.SCENE_NAMES:
		var counts := {"pairs": 0, "opponents_changed": 0, "shelves_changed": 0, "first_table_opponents_changed": 0, "first_stage_shelf_changed": 0, "first_route_changed": 0, "room_layout_changed": 0, "opening_choice_changed": 0, "at_least_two_of_three_changed": 0, "all_three_changed": 0, "none_of_four_changed": 0}
		var previous := plan_for(content, scene, FIRST_SEED)
		if previous.is_empty():
			quit(1)
			return
		for seed_value in range(FIRST_SEED + 1, LAST_SEED + 1):
			var current := plan_for(content, scene, seed_value)
			if current.is_empty():
				quit(1)
				return
			var opponents_changed: bool = JSON.stringify(previous.opponents) != JSON.stringify(current.opponents)
			var shelves_changed: bool = JSON.stringify(previous.shelves) != JSON.stringify(current.shelves)
			var route_changed: bool = int(previous.initial_offer) != int(current.initial_offer)
			var room_changed: bool = str(previous.room_layout) != str(current.room_layout)
			var first_opponents_changed: bool = JSON.stringify(previous.opponents["cargo-table"]) != JSON.stringify(current.opponents["cargo-table"])
			var first_shelf_changed: bool = JSON.stringify(previous.shelves["1"]) != JSON.stringify(current.shelves["1"])
			var choice_changes := int(opponents_changed) + int(shelves_changed) + int(route_changed)
			counts.pairs += 1
			counts.opponents_changed += int(opponents_changed)
			counts.shelves_changed += int(shelves_changed)
			counts.first_table_opponents_changed += int(first_opponents_changed)
			counts.first_stage_shelf_changed += int(first_shelf_changed)
			counts.first_route_changed += int(route_changed)
			counts.room_layout_changed += int(room_changed)
			counts.opening_choice_changed += int(first_opponents_changed or first_shelf_changed or route_changed or room_changed)
			counts.at_least_two_of_three_changed += int(choice_changes >= 2)
			counts.all_three_changed += int(opponents_changed and shelves_changed and route_changed)
			counts.none_of_four_changed += int(choice_changes == 0 and not room_changed)
			previous = current
		venues[scene] = counts
	var result := {"first_seed": FIRST_SEED, "last_seed": LAST_SEED, "comparison": "adjacent_seed_pairs", "scope": "Generated full opponent roster and five-stage shelves, plus first-table opponents, first-stage shelf, first fixed route and room layout; not human-perceived difference or completed playthroughs.", "venues": venues}
	var path := ProjectSettings.globalize_path("res://../output/3d/replay-variation.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("REPLAY_VARIATION ", path)
	quit()
