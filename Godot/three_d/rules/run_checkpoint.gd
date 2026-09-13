extends RefCounted
const Run = preload("res://three_d/rules/run.gd")
const TableCheckpoint = preload("res://three_d/rules/table_checkpoint.gd")
const FIELDS := ["vault", "active", "cash", "bankroll", "heat", "public_exit", "completed", "last_result", "revision", "inventory", "known_rules", "used_tools", "preview", "preview_hand", "action_points", "search_index", "heat_reduced", "service_message", "last_reward", "route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan"]

static func capture(run: RefCounted) -> Dictionary:
	var values := {}
	for field in FIELDS:
		values[field] = run.get(field)
	values = values.duplicate(true)
	values["table"] = TableCheckpoint.capture(run.table) if run.table != null else {}
	return values

static func restore(values: Dictionary, content: Dictionary) -> RefCounted:
	var run := Run.new(content)
	values = values.duplicate(true)
	for field in ["route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan"]:
		if not values.has(field):
			values[field] = run.get(field)
	for field in FIELDS:
		if not values.has(field) or typeof(values[field]) != typeof(run.get(field)):
			return null
	if values.vault < 0 or values.cash < 0 or values.heat < 0 or values.heat > 6 or not values.get("table") is Dictionary:
		return null
	if not content.scenes.has(values.scene_id):
		return null
	if not values.variant_plan.is_empty() and not Run.Variants.valid(values.variant_plan, content, values.scene_id):
		return null
	if values.offer_index < 0 or values.offer_index >= content.routes[values.scene_id].fixedRoutes.size():
		return null
	for id in values.inventory:
		if not content.items.has(id):
			return null
	if not values.collateral.is_empty() and (not content.items.has(values.collateral) or content.items[values.collateral].kind != "valuable" or values.table.is_empty()):
		return null
	for field in FIELDS:
		if run.get(field) is Array:
			run.get(field).assign(values[field])
		else:
			run.set(field, values[field])
	if not values.table.is_empty():
		run.table = TableCheckpoint.restore(values.table)
		if run.table == null or not run.active:
			return null
	return run
