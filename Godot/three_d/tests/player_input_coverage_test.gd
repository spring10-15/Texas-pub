extends SceneTree

const IDS := ["player.look_changed", "player.movement", "world.prop_on", "world.raycast_unfocused"]
var hits := {}
var failures: Array[String] = []
var checks := 0

func verify(id: String, ok: bool) -> void:
	checks += 1
	if ok:
		hits[id] = {"test":"player_input_coverage_test.gd", "postcondition_verified":true}
	else:
		failures.append(id)
		push_error(id)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	for i in range(3): await physics_frame
	world.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: CharacterBody3D = world.player
	var before_look: Dictionary = world.checkpoint_state()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 2000)
	player._unhandled_input(motion)
	var after_look: Dictionary = world.checkpoint_state()
	verify("player.look_changed", not after_look.player.is_equal_approx(before_look.player) and is_equal_approx(player.rotation.y, -0.2) and is_equal_approx(player.camera.rotation.x, -player.LOOK_PITCH_LIMIT))

	player.position = Vector3(1.0, 0.02, 2.5)
	player.rotation = Vector3(0, -PI / 2, 0)
	player.camera.rotation = Vector3.ZERO
	var before_move: Dictionary = world.checkpoint_state()
	Input.action_press("move_forward")
	for i in range(45): await physics_frame
	Input.action_release("move_forward")
	var after_move: Dictionary = world.checkpoint_state()
	verify("player.movement", after_move.player.origin.x > before_move.player.origin.x + 0.2 and after_move.player.origin.x < 2.7 and is_equal_approx(after_move.player.origin.z, before_move.player.origin.z))

	var lamp: Area3D = world.props.entries.lamp.anchor
	player.position = Vector3(1.6, 0.02, -1.1)
	player.camera.look_at(lamp.global_position)
	for i in range(3): await physics_frame
	var lamp_before: bool = world.props.states.lamp
	var requested: Array[Area3D] = []
	player.interaction_requested.connect(func(target): requested.append(target))
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.keycode = KEY_E
	interact.pressed = true
	player._unhandled_input(interact)
	verify("world.prop_on", player.focused == lamp and requested == [lamp] and world.props.states.lamp != lamp_before)

	player.position = Vector3(0, 0.05, 100)
	player.velocity = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.ray.enabled = true
	player.focused = null
	requested.clear()
	var before_unfocused: Dictionary = world.checkpoint_state()
	player._unhandled_input(interact)
	verify("world.raycast_unfocused", player.focused == null and requested.is_empty() and world.checkpoint_state() == before_unfocused)

	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return row.id in IDS).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var rules_hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			rules_hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/" + file).sha256_text()
	var report := {"scope":"Captured mouse look, collision-aware movement and unfocused interact input","source_sha256":rules_hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/player_input_coverage_test.gd").sha256_text(),"player_source_sha256":FileAccess.get_file_as_string("res://three_d/scripts/player.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"overall_state_transition_coverage":null}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/3d"))
	FileAccess.open("res://../output/3d/player-input-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("PLAYER_INPUT checks=", checks, " failures=", failures)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() and missing.is_empty() and expected.size() == IDS.size() else 1)
