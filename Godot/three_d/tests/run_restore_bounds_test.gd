extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Store = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var checks := 0
var invalid_cases := 0
var invalid_case_targets := 0
var legacy_variant_cases := 0
var legacy_search_event_restored := false
var reservation_offer_consistent := false
var reservation_restored := false
var active_table_definition_migrated := false
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
	var route_count: int = content.routes[original.scene_id].fixedRoutes.size()
	for entry in [
		{"name":"negative_vault","field":"vault","value":-1},
		{"name":"negative_cash","field":"cash","value":-1},
		{"name":"negative_heat","field":"heat","value":-1},
		{"name":"heat_above_cap","field":"heat","value":7},
		{"name":"table_not_dictionary","field":"table","value":[]},
		{"name":"unknown_scene","field":"scene_id","value":"unknown-venue"},
		{"name":"negative_offer_index","field":"offer_index","value":-1},
		{"name":"offer_index_at_end","field":"offer_index","value":route_count},
		{"name":"arrival_exceeds_completed","field":"arrival_completed","value":1},
		{"name":"venue_history_non_string","field":"venue_history","value":[42]},
		{"name":"venue_history_unknown_scene","field":"venue_history","value":["missing-venue"]},
		{"name":"venue_history_duplicate","field":"venue_history","value":["smoky-den","smoky-den"]},
		{"name":"venue_history_wrong_tail","field":"venue_history","value":["rooftop-club"]},
	]:
		invalid_case_targets += 1
		invalid_cases += 1 if check_invalid_case(entry.name, original, entry.field, entry.value, content, r, original) else 0
	var invalid_collateral_run := Run.new(content)
	invalid_collateral_run.start(invalid_collateral_run.revision,"smoky-den",0)
	var collateral_base: Dictionary = Checkpoint.capture(invalid_collateral_run)
	for entry in [
		{"name":"collateral_unknown_item","value":"missing-item"},
		{"name":"collateral_not_valuable","value":"kitchen-pass"},
		{"name":"collateral_without_active_table","value":"old-silver-lighter"},
	]:
		var collateral_case := collateral_base.duplicate(true)
		collateral_case.collateral = entry.value
		invalid_case_targets += 1
		invalid_cases += 1 if check_invalid_snapshot(entry.name, collateral_case, content, invalid_collateral_run, collateral_base) else 0
	var transfer_run := Run.new(content)
	transfer_run.start(transfer_run.revision,"smoky-den",82)
	var transfer_table: RefCounted = transfer_run.enter_table(113,transfer_run.revision,"cargo-table")
	if transfer_table != null:
		finish_table(transfer_table)
		verify(transfer_run.settle_table(transfer_run.revision),"Settle a played table for a real transfer checkpoint")
	var transfer_valid: bool = transfer_table != null and transfer_run.completed.has("cargo-table") and transfer_run.transfer_venue("rooftop-club",transfer_run.revision)
	verify(transfer_valid,"Construct valid transfer checkpoint through Run APIs")
	if transfer_valid:
		var transfer_base: Dictionary = Checkpoint.capture(transfer_run)
		for entry in [
			{"name":"transfer_log_count_mismatch","field":"transfer_log","value":[]},
			{"name":"hop_from_mismatch","field":"from","value":"neon-poker-club"},
			{"name":"hop_to_mismatch","field":"to","value":"high-rise-suite"},
			{"name":"hop_fee_not_integer","field":"fee","value":"15"},
			{"name":"hop_fee_below_minimum","field":"fee","value":14},
			{"name":"hop_after_tables_not_integer","field":"after_tables","value":"1"},
			{"name":"hop_after_tables_not_increasing","field":"after_tables","value":0},
			{"name":"hop_after_tables_out_of_range","field":"after_tables","value":4},
			{"name":"arrival_differs_from_hop","field":"arrival_completed","value":0},
		]:
			var transfer_case: Dictionary = transfer_base.duplicate(true)
			if entry.has("field") and entry.field in ["from","to","fee","after_tables"]:
				transfer_case.transfer_log[0][entry.field] = entry.value
			else:
				transfer_case[entry.field] = entry.value
			invalid_case_targets += 1
			invalid_cases += 1 if check_invalid_snapshot(entry.name, transfer_case, content, transfer_run, transfer_base) else 0
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
	var legacy_table_save: Dictionary = table_save.duplicate(true)
	var legacy_table_definition: Dictionary = legacy_table_save.table.state.tableDef
	legacy_table_definition.erase("rewardRules")
	legacy_table_definition.baseRewardPool = ["old-silver-lighter", "ivory-chip", "ruby-cufflink"]
	legacy_table_definition.signatureReward = "ivory-chip"
	legacy_table_definition.hiddenInfo.rule = "The first aggressive action of each hand costs 10 less for the acting player."
	legacy_table_save.table.state.tableDef = legacy_table_definition
	var legacy_table_run: RefCounted = Checkpoint.restore(legacy_table_save,content)
	active_table_definition_migrated = legacy_table_run != null and legacy_table_run.table.state.tableDef == legacy_table_run.table_definition("cargo-table")
	active_table_definition_migrated = active_table_definition_migrated and legacy_table_run.table.state.currentActorId == table_save.table.state.currentActorId and legacy_table_run.table.state.pot == table_save.table.state.pot and legacy_table_run.table.state.players == table_save.table.state.players
	verify(active_table_definition_migrated,"Legacy active table saves migrate content-only table fields and preserve play state")
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
	if invalid_cases == cases.size() + invalid_case_targets and failures.is_empty():
		hits["persistence_run.invalid_fields_rejected"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true}
	if reservation_restored and failures.is_empty():
		hits["persistence_run.reservation_restored"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true}
	if reservation_created and reservation_rejections == reservation_cases.size() and failures.is_empty():
		hits["persistence_run.reservation_offer_consistent"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"mismatches":reservation_rejections}
	if legacy_variant_cases == 2 and failures.is_empty():
		hits["persistence_run.legacy_variant_plan_restored"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"versions":[2,3]}
	if legacy_search_event_restored and failures.is_empty():
		hits["persistence_run.legacy_search_event_restored"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"fixture":"version-1 disk envelope"}
	if active_table_definition_migrated and failures.is_empty():
		hits["persistence_run.active_table_definition_migrated"] = {"test":"run_restore_bounds_test.gd","postcondition_verified":true,"preserved":["actor", "pot", "players"]}
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for source_file in DirAccess.get_files_at("res://three_d/rules"):
		if source_file.ends_with(".gd") or source_file.ends_with(".json"):
			hashes[source_file] = FileAccess.get_file_as_string("res://three_d/rules/" + source_file).sha256_text()
	var report := {"scope":"Reject malformed run checkpoints and restore legacy variant plans","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/run_restore_bounds_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"failed":failures.size(),"invalid_cases":invalid_cases,"legacy_variant_cases":legacy_variant_cases,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-run-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RUN_RESTORE_BOUNDS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func check_invalid_case(label: String, base: Dictionary, field: String, value: Variant, content: Dictionary, live_run: RefCounted, live_before: Dictionary) -> bool:
	var broken := base.duplicate(true)
	broken[field] = value
	return check_invalid_snapshot(label, broken, content, live_run, live_before)

func check_invalid_snapshot(label: String, broken: Dictionary, content: Dictionary, live_run: RefCounted, live_before: Dictionary) -> bool:
	var before := broken.duplicate(true)
	var rejected: bool = Checkpoint.restore(broken,content) == null
	var unchanged: bool = broken == before and Checkpoint.capture(live_run) == live_before
	verify(rejected,"Reject Run checkpoint at expected guard: "+label)
	verify(unchanged,"Rejected Run checkpoint and live state remain unchanged: "+label)
	return rejected and unchanged

func finish_table(table: RefCounted) -> void:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over":
			table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty():
			table.advance(table.revision)
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			table.act(actor,"fold" if actor != "player" else ("check" if legal.check else "call"),table.revision)
	verify(table.state.status == "finished","Checkpoint fixture table finishes")
