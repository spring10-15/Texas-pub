extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var layouts := {}
	for seed_value in range(1,101):
		var plan := Run.Variants.generate(content,"smoky-den",seed_value)
		layouts[JSON.stringify(plan.events)] = seed_value
	verify(layouts.size()==4,"Both independent event pairs generate four layouts")
	for scene in Run.SCENE_NAMES:
		for seed_value in layouts.values():
			for site in Run.Variants.TABLES:
				var preview := Run.new(content)
				preview.start(preview.revision,scene,seed_value)
				for option in Run.SearchEvents.event_for(preview,site).choices:
					var r := Run.new(content)
					r.start(r.revision,scene,seed_value)
					r.completed.assign(Run.Variants.TABLES.slice(0,Run.Variants.TABLES.find(site)))
					r.heat = 3
					var saved := Checkpoint.capture(r)
					var view: Dictionary = r.service_view("search",site)
					verify(Checkpoint.capture(r)==saved,"Inspect does not redraw or spend")
					verify(view.actions.any(func(action): return action.target==option.id and action.label==option.label and action.reason.is_empty()),"Displayed choice is available with disclosed terms")
					var loaded: RefCounted = Checkpoint.restore(saved,content)
					verify(loaded != null and loaded.service_view("search",site)==view,"Unresolved event survives reload exactly")
					verify(loaded.service_action("search",site,loaded.revision,option.id),"Selected pooled event resolves")
					verify(loaded.cash==300+int(option.get("cash",0))-int(option.get("cost",0)) and loaded.action_points==1,"Disclosed cash and AP apply exactly")
					verify(loaded.heat==3+int(option.get("heat",0))-(1 if option.get("cool",false) else 0),"Disclosed heat applies exactly")
					if option.has("item"): verify(loaded.inventory==[option.item],"Correct valuable granted once")
					if option.has("route"): verify(loaded.route_known(option.route),"Correct route revealed")
					if option.has("intel"): verify(loaded.full_intel.has(option.intel),"Correct table intelligence revealed")
					verify(loaded.search_results[site].event==loaded.variant_plan.events[site],"Result records actual event identity")
					var after := Checkpoint.capture(loaded)
					var again: RefCounted = Checkpoint.restore(after,content)
					verify(not again.service_action("search",site,again.revision,option.id) and Checkpoint.capture(again)==after,"Resolved event cannot be farmed after reload")
	var legacy := Run.new(content)
	legacy.start(legacy.revision,"smoky-den",42)
	var saved := Checkpoint.capture(legacy)
	saved.variant_plan.version = 1
	saved.variant_plan.erase("events")
	saved.variant_plan.erase("opponents")
	saved.variant_plan.erase("room_layout")
	var restored: RefCounted = Checkpoint.restore(saved,content)
	verify(restored != null and Run.SearchEvents.event_id(restored,"cargo-table")=="cargo-table","Version 1 retains original event placement")
	for corruption in ["missing","duplicate","unknown"]:
		var bad := Checkpoint.capture(legacy)
		if corruption=="missing": bad.variant_plan.erase("events")
		elif corruption=="duplicate": bad.variant_plan.events["embers-table"] = bad.variant_plan.events["cargo-table"]
		else: bad.variant_plan.events["cargo-table"] = "unknown"
		verify(Checkpoint.restore(bad,content)==null,"Invalid event plan rejected: "+corruption)
	print("EVENT_POOL checks=",checks," failed=",failures.size()," layouts=",layouts.size())
	quit(0 if failures.is_empty() else 1)
