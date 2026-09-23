extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const WINDOWS := [1, 101, 10001]
const WINDOW_SIZE := 100
const MIN_DISTINCT := 50
var checks := 0
var failures: Array[String] = []

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var venues := {}
	for scene in Run.SCENE_NAMES:
		var windows := []
		for first_seed in WINDOWS:
			var configurations := {}
			var rooms := {}
			var offers := {}
			var events := {}
			for seed_value in range(first_seed, first_seed + WINDOW_SIZE):
				var current := Run.new(content)
				if not current.start(current.revision, scene, seed_value):
					verify(false, "%s seed %d starts" % [scene, seed_value])
					continue
				var plan: Dictionary = current.variant_plan
				var offer_id: String = content.routes[scene].fixedRoutes[plan.initial_offer].id
				# Count choices the player can encounter; raw deck seeds and roster permutations are excluded.
				configurations[JSON.stringify([plan.room_layout, plan.shelves, offer_id])] = true
				rooms[plan.room_layout] = true
				offers[offer_id] = true
				events[JSON.stringify(plan.events)] = true
			var result := {"first_seed":first_seed,"distinct_player_configurations":configurations.size(),"room_layouts":rooms.size(),"initial_routes":offers.size(),"event_layouts":events.size()}
			windows.append(result)
			verify(configurations.size() > MIN_DISTINCT, "%s seed %d: more than %d distinct player configurations" % [scene, first_seed, MIN_DISTINCT])
			verify(rooms.size() == 2, "%s seed %d: both room connections appear" % [scene, first_seed])
			verify(offers.size() == 2, "%s seed %d: both first routes appear" % [scene, first_seed])
			verify(events.size() == 4, "%s seed %d: all event layouts appear" % [scene, first_seed])
		venues[scene] = windows
	var report := {"checks":checks,"failed":failures.size(),"failures":failures,"threshold_strictly_greater_than":MIN_DISTINCT,"seeds_per_window":WINDOW_SIZE,"windows_by_venue":venues,"scope":"Rooms, five-stage shelf availability and initial fixed route count toward X. Event layouts are checked separately. Opponents, deck seeds and human strategy are excluded."}
	FileAccess.open("res://../output/3d/seed-diversity.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SEED_DIVERSITY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
