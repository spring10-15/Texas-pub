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
	for scenario in ["known", "completed", "rules_only", "new"]:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		r.inventory.append("disposable-phone")
		if scenario == "known": r.full_intel["mirror-hall"] = true
		if scenario == "completed": r.completed.assign(["cargo-table","ledger-cellar","mirror-hall"])
		if scenario == "rules_only": r.known_rules.append("mirror-hall")
		var before := Checkpoint.capture(r)
		var accepted: bool = r.service_action("phone-table","disposable-phone",r.revision,"mirror-hall")
		if scenario in ["known","completed"]:
			verify(not accepted and Checkpoint.capture(r) == before,"Phone preserves all state for "+scenario)
		else:
			verify(accepted and r.full_intel.has("mirror-hall") and r.inventory.is_empty() and r.action_points == before.action_points-1,"Phone adds useful full intel for "+scenario)
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",0)
	r.inventory.assign(["player-notes","player-notes"])
	r.enter_table(7,r.revision)
	var target: String = r.table.state.players[1].id
	verify(r.service_action("notes","player-notes",r.revision,target),"First notes reveal opponent")
	var before := Checkpoint.capture(r)
	verify(not r.service_action("notes","player-notes",r.revision,target) and Checkpoint.capture(r) == before,"Known opponent does not consume second notes")
	var other: String = r.table.state.players[2].id
	verify(r.service_action("notes","player-notes",r.revision,other) and r.opponent_notes.has(other),"Second notes can reveal a different opponent")
	print("REDUNDANT_INTEL checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
