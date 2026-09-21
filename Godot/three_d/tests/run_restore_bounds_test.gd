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
	var legacy := original.duplicate(true)
	for field in ["route_flags","reservation","offer_index","full_intel","opponent_notes","collateral","last_table_result","scene_id","search_results","run_seed","variant_plan","venue_history","arrival_completed","transfer_log"]: legacy.erase(field)
	verify(Checkpoint.restore(legacy,content) != null,"Legacy optional fields still migrate")
	print("RUN_RESTORE_BOUNDS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
