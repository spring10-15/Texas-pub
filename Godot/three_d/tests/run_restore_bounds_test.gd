extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
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
		verify(Checkpoint.restore(bad,content) == null,"Reject "+key)
		verify(bad == before and Checkpoint.capture(r) == original,"Rejected input does not mutate live state "+key)
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
	var legacy := original.duplicate(true)
	for field in ["route_flags","reservation","offer_index","full_intel","opponent_notes","collateral","last_table_result","scene_id","search_results","run_seed","variant_plan","venue_history","arrival_completed","transfer_log"]: legacy.erase(field)
	verify(Checkpoint.restore(legacy,content) != null,"Legacy optional fields still migrate")
	print("RUN_RESTORE_BOUNDS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
