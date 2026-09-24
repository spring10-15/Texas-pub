extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Store = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var checks := 0
var invalid_cases := 0
var legacy_variant_cases := 0
var legacy_search_event_restored := false
var reservation_offer_consistent := false
var reservation_restored := false
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",0)
	var original := Checkpoint.capture(r)
	var cases := {"negative_actions":["action_points",-1],"excess_actions":["action_points",int(content.searchActions)+1],"negative_bankroll":["bankroll",-1],"negative_revision":["revision",-1],"zero_search":["search_index",0],"unknown_rule":["known_rules",["unknown-table"]],"unknown_tool":["used_tools",["unknown-item"]],"unknown_item":["inventory",["unknown-item"]]}
	cases.typed_rule = ["known_rules",[42]]
	cases.typed_tool = ["used_tools",[42]]
	cases.typed_item = ["inventory",[42]]
	cases.intel_unknown = ["full_intel",{"unknown-table":true}]
	cases.intel_key_type = ["full_intel",{42:true}]
	cases.intel_value_type = ["full_intel",{"cargo-table":"yes"}]
	cases.note_unknown = ["opponent_notes",{"unknown-actor":"Nit"}]
	cases.note_value_type = ["opponent_notes",{"ledger-clerk":42}]
	cases.note_archetype = ["opponent_notes",{"ledger-clerk":"unknown-style"}]
	cases.route_unknown = ["route_flags",{"unknown-route":true}]
	cases.route_type = ["route_flags",{"fixed":"yes"}]
	cases.search_unknown = ["search_results",{"missing":{}}]
	cases.search_type = ["search_results",{"cargo-table":"done"}]
	cases.search_event = ["search_results",{"cargo-table":{"event":"missing","choice":"goods","message":"done"}}]
	cases.search_choice = ["search_results",{"cargo-table":{"event":"cargo-table","choice":"missing","message":"done"}}]
	cases.search_message = ["search_results",{"cargo-table":{"event":"cargo-table","choice":"goods","message":42}}]
	cases.summary_missing = ["last_table_result",{"table":"cargo-table"}]
	cases.summary_unknown = ["last_table_result",{"table":"missing","net":10}]
	cases.summary_net = ["last_table_result",{"table":"cargo-table","net":"ten"}]
	cases.preview_rank = ["preview",{"rank":"A","suit":"S"}]
	cases.preview_suit = ["preview",{"rank":14,"suit":"X"}]
	cases.preview_missing = ["preview",{"rank":14}]
	cases.preview_hand_negative = ["preview_hand",-1]
	var heavy: Array = []
	for i in range(int(content.inventorySlots)/2+1): heavy.append("sealed-bond")
	cases.weighted_overfull = ["inventory",heavy]
	var overfull: Array = []
	for i in range(int(content.inventorySlots)+1): overfull.append("ivory-chip")
	cases.overfull = ["inventory",overfull]
	for key in cases:
		var bad := original.duplicate(true)
		bad[cases[key][0]] = cases[key][1]
		var before := bad.duplicate(true)
		var rejected: bool = Checkpoint.restore(bad,content) == null
		var unchanged: bool = bad == before and Checkpoint.capture(r) == original
		verify(rejected,"Reject "+key)
		verify(unchanged,"Rejected input does not mutate live state "+key)
		invalid_cases += 1 if rejected and unchanged else 0
	var reserved := Run.new(content)
	reserved.start(reserved.revision,"smoky-den",2409)
	reserved.route_flags.fixed = true
	var reservation_created: bool = reserved.service_action("reserve","",reserved.revision)
	var valid_reservation: Dictionary = Checkpoint.capture(reserved)
	reservation_restored = reservation_created and Checkpoint.restore(valid_reservation,content) != null
	verify(reservation_restored,"Valid reservation restores against its configured route")
	var reservation_cases := {"advance":"reserveCost", "tail":"finalCost", "heat":"maxHeat", "route":"id"}
	var reservation_rejections := 0
	for case_name in reservation_cases:
		var corrupted_reservation: Dictionary = valid_reservation.duplicate(true)
		var field: String = reservation_cases[case_name]
		corrupted_reservation.reservation[field] = "missing-route" if field == "id" else int(corrupted_reservation.reservation[field]) - 1
		var before_corruption := corrupted_reservation.duplicate(true)
		var rejected_reservation: bool = Checkpoint.restore(corrupted_reservation,content) == null
		var reservation_unchanged: bool = corrupted_reservation == before_corruption and Checkpoint.capture(reserved) == valid_reservation
		verify(rejected_reservation,"Reject reservation offer mismatch: "+case_name)
		verify(reservation_unchanged,"Rejected reservation does not mutate source: "+case_name)
		reservation_rejections += 1 if rejected_reservation and reservation_unchanged else 0
	# Legitimate duplicate valuables are allowed up to capacity.
	for points in [0,int(content.searchActions)]:
		var valid := original.duplicate(true)
		valid.action_points = points
		valid.inventory = []
		for i in range(int(content.inventorySlots)): valid.inventory.append("ivory-chip")
		var restored := Checkpoint.restore(valid,content)
		verify(restored != null and Checkpoint.capture(restored) == valid,"Full bag and boundary actions restore "+str(points))
	var informed := original.duplicate(true)
	informed.full_intel = {"cargo-table":true,"mirror-hall":true}
	informed.opponent_notes = {"ledger-clerk":content.opponents["ledger-clerk"].archetype}
	informed.route_flags = {"fixed":true,"river-launch":false,"service-stairs":true}
	var informed_run := Checkpoint.restore(informed,content)
	verify(informed_run != null and Checkpoint.capture(informed_run) == informed,"Known information restores without changes")
	if informed_run != null:
		verify(not informed_run.service_view("bag").text.is_empty(),"Restored information can be displayed")
	var legacy_v2 := original.duplicate(true)
	legacy_v2.variant_plan.version = 2
	legacy_v2.variant_plan.erase("opponents")
	legacy_v2.variant_plan.erase("room_layout")
	var restored_v2: RefCounted = Checkpoint.restore(legacy_v2,content)
	var v2_ok: bool = restored_v2 != null and restored_v2.table_definition("cargo-table").opponentIds == content.tables["cargo-table"].opponentIds and restored_v2.room_requirements("mirror-hall") == ["ledger-cellar"]
	verify(v2_ok,"Version 2 plan restores historical opponents and linear rooms")
	legacy_variant_cases += 1 if v2_ok else 0
	var legacy_v3 := original.duplicate(true)
	legacy_v3.variant_plan.version = 3
	legacy_v3.variant_plan.erase("room_layout")
	var restored_v3: RefCounted = Checkpoint.restore(legacy_v3,content)
	var v3_ok: bool = restored_v3 != null and restored_v3.table_definition("cargo-table").opponentIds == legacy_v3.variant_plan.opponents["cargo-table"] and restored_v3.room_requirements("mirror-hall") == ["ledger-cellar"]
	verify(v3_ok,"Version 3 plan retains saved opponents and restores linear rooms")
	legacy_variant_cases += 1 if v3_ok else 0
	var searched := Run.new(content)
	searched.start(searched.revision,"smoky-den",0)
	verify(searched.service_action("search","cargo-table",searched.revision,"goods"),"Real search succeeds")
	var searched_save := Checkpoint.capture(searched)
	var searched_run := Checkpoint.restore(searched_save,content)
	verify(searched_run != null and Checkpoint.capture(searched_run) == searched_save,"Search result round trip preserves rewards and state")
	if searched_run != null:
		verify(not searched_run.service_action("search","cargo-table",searched_run.revision,"goods") and Checkpoint.capture(searched_run) == searched_save,"Restored search cannot award twice")
	searched_save.search_results["cargo-table"].erase("event")
	verify(Checkpoint.restore(searched_save,content) != null,"Legacy search without event identity remains accepted")
	var legacy_world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(legacy_world)
	await process_frame
	legacy_world.set_process(false)
	legacy_world.run_game.start(legacy_world.run_game.revision,"smoky-den",0)
	legacy_world.travel("tavern")
	var disk_search := Checkpoint.capture(searched)
	disk_search.search_results["ledger-cellar"] = {"event":"ledger-cellar","choice":"cash","message":"保留的旧站点结果"}
	disk_search.search_results["cargo-table"].erase("event")
	var disk_expected: Dictionary = disk_search.duplicate(true)
	disk_expected.search_results["cargo-table"]["event"] = "cargo-table"
	var legacy_world_state: Dictionary = legacy_world.checkpoint_state()
	legacy_world_state.run = disk_search
	var legacy_search_path := "user://legacy-search-event-test-%d.save" % OS.get_process_id()
	legacy_world.save_path = legacy_search_path
	var legacy_search_written: bool = Store.write_checkpoint(legacy_search_path,legacy_world_state) == OK
	var disk_before_load: Dictionary = Store.read_checkpoint(legacy_search_path)
	var disk_before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(legacy_search_path)
	if legacy_search_written:
		legacy_world.load_checkpoint()
	var disk_after_load: Dictionary = Store.read_checkpoint(legacy_search_path)
	legacy_search_event_restored = legacy_world.checkpoint_state().run.search_results.get("cargo-table",{}).get("event","") == "cargo-table"
	legacy_search_event_restored = legacy_search_event_restored and legacy_world.checkpoint_state().run.search_results.get("ledger-cellar",{}) == disk_expected.search_results["ledger-cellar"]
	legacy_search_event_restored = legacy_search_event_restored and legacy_world.checkpoint_state().run == disk_expected
	legacy_search_event_restored = legacy_search_event_restored and disk_before_load.status == "ok" and disk_before_load.state == legacy_world_state and not disk_before_load.state.run.search_results["cargo-table"].has("event")
	legacy_search_event_restored = legacy_search_event_restored and disk_after_load.status == "ok" and disk_after_load.state == legacy_world_state and FileAccess.get_file_as_bytes(legacy_search_path) == disk_before_bytes
	legacy_search_event_restored = legacy_search_event_restored and legacy_world.saving_enabled and legacy_world.paused
	verify(legacy_search_event_restored,"Version 1 disk checkpoint restores missing search event to site and preserves full state")
	var legacy_search_cleanup: bool = DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_search_path)) == OK
	legacy_search_event_restored = legacy_search_event_restored and legacy_search_cleanup
	legacy_world.queue_free()
	var playing := Run.new(content)
	playing.start(playing.revision,"smoky-den",42)
	verify(playing.enter_table(113,playing.revision,"cargo-table") != null,"Real table opened for checkpoint validation")
	var table_save := Checkpoint.capture(playing)
	verify(Checkpoint.restore(table_save,content) != null,"Canonical table definition restores")
	for label in ["changed_buyin","changed_hands","unknown_table"]:
		var broken := table_save.duplicate(true)
		match label:
			"changed_buyin": broken.table.state.tableDef.buyIn = 120
			"changed_hands": broken.table.state.tableDef.hands = 99
			"unknown_table": broken.table.state.tableDef.id = "unknown"
		verify(Checkpoint.restore(broken,content) == null and Checkpoint.capture(playing) == table_save,"Reject forged table definition: "+label)
	var legacy := original.duplicate(true)
	for field in ["route_flags","reservation","offer_index","full_intel","opponent_notes","collateral","last_table_result","scene_id","search_results","run_seed","variant_plan","venue_history","arrival_completed","transfer_log"]: legacy.erase(field)
	verify(Checkpoint.restore(legacy,content) != null,"Legacy optional fields still migrate")
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("persistence_run.")).map(func(row): return row.id)
	var hits := {}
	if invalid_cases == cases.size() and failures.is_empty():
		hits["persistence_run.invalid_fields_rejected"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true}
	if reservation_restored and failures.is_empty():
		hits["persistence_run.reservation_restored"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true}
	if reservation_created and reservation_rejections == reservation_cases.size() and failures.is_empty():
		hits["persistence_run.reservation_offer_consistent"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"mismatches":reservation_rejections}
	if legacy_variant_cases == 2 and failures.is_empty():
		hits["persistence_run.legacy_variant_plan_restored"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"versions":[2,3]}
	if legacy_search_event_restored and failures.is_empty():
		hits["persistence_run.legacy_search_event_restored"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"fixture":"version-1 disk envelope"}
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for source_file in DirAccess.get_files_at("res://three_d/rules"):
		if source_file.ends_with(".gd") or source_file.ends_with(".json"):
			hashes[source_file] = FileAccess.get_file_as_string("res://three_d/rules/" + source_file).sha256_text()
	var report := {"scope":"Reject malformed run checkpoints and restore legacy variant plans","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/run_restore_bounds_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"failed":failures.size(),"invalid_cases":invalid_cases,"legacy_variant_cases":legacy_variant_cases,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-run-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RUN_RESTORE_BOUNDS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
