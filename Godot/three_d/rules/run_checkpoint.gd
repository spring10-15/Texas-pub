extends RefCounted
const Run = preload("res://three_d/rules/run.gd")
const TableCheckpoint = preload("res://three_d/rules/table_checkpoint.gd")
const FIELDS := ["vault", "active", "cash", "bankroll", "heat", "public_exit", "completed", "last_result", "revision", "inventory", "known_rules", "used_tools", "preview", "preview_hand", "action_points", "search_index", "heat_reduced", "service_message", "last_reward", "route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan", "venue_history", "arrival_completed", "transfer_log"]

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
	for field in ["route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan", "venue_history", "arrival_completed", "transfer_log"]:
		if not values.has(field):
			values[field] = run.get(field)
	for field in FIELDS:
		if not values.has(field) or typeof(values[field]) != typeof(run.get(field)):
			return null
	if values.venue_history.is_empty() and values.active:
		values.venue_history = [values.scene_id]
	if values.vault < 0 or values.cash < 0 or values.heat < 0 or values.heat > 6 or not values.get("table") is Dictionary:
		return null
	if values.bankroll < 0 or values.revision < 0 or values.search_index < 1:
		return null
	if values.action_points < 0 or values.action_points > int(content.searchActions):
		return null
	if values.preview_hand < 0:
		return null
	if not values.preview.is_empty():
		if not values.preview.get("rank") is int or values.preview.rank < 2 or values.preview.rank > 14 or values.preview.get("suit") not in ["S", "H", "D", "C"] or values.preview_hand < 1:
			return null
	for id in values.known_rules:
		if not id is String or not content.tables.has(id): return null
	for id in values.used_tools:
		if not id is String or not content.items.has(id): return null
	for id in values.full_intel:
		if not id is String or not content.tables.has(id) or not values.full_intel[id] is bool: return null
	var archetypes: Array = content.opponents.values().map(func(actor): return actor.archetype)
	for id in values.opponent_notes:
		if not id is String or not content.opponents.has(id) or not values.opponent_notes[id] is String or values.opponent_notes[id] not in archetypes: return null
	for id in values.route_flags:
		if id not in ["fixed", "service-stairs", "river-launch"] or not values.route_flags[id] is bool: return null
	for site in values.search_results:
		if not site is String or not Run.SearchEvents.EVENTS.has(site): return null
		var result: Variant = values.search_results[site]
		if not result is Dictionary or not result.get("message") is String or not result.get("choice") is String: return null
		var event: Variant = result.get("event", site)
		if not event is String or not Run.SearchEvents.EVENTS.has(event): return null
		if not Run.SearchEvents.EVENTS[event].choices.any(func(option): return option.id == result.choice): return null
		if not result.has("event"):
			result["event"] = site
	if not values.last_table_result.is_empty():
		var summary: Dictionary = values.last_table_result
		if not summary.get("table") is String or not content.tables.has(summary.table): return null
		if not (summary.get("net") is int or summary.get("net") is float): return null
		var net := float(summary.net)
		if not is_finite(net) or net != floor(net): return null
	if not content.scenes.has(values.scene_id):
		return null
	if not values.reservation.is_empty():
		var booking: Dictionary = values.reservation
		if not booking.get("id") is String:
			return null
		var matching_offers: Array = content.routes[values.scene_id].fixedRoutes.filter(func(route): return route.id == booking.id)
		if matching_offers.size() != 1:
			return null
		var offer: Dictionary = matching_offers[0]
		for field in ["reserveCost", "finalCost", "maxHeat", "expiresAfterSearch"]:
			if not (booking.get(field) is int or booking.get(field) is float): return null
			var amount := float(booking[field])
			if not is_finite(amount) or amount < 0 or amount != floor(amount): return null
		if booking.maxHeat > 6 or booking.expiresAfterSearch < 1: return null
		var expected_reserve_cost: int = maxi(10, int(offer.reserveCost) - int(content.scenes[values.scene_id].fixedRouteReserveDiscount))
		if int(booking.reserveCost) != expected_reserve_cost or int(booking.finalCost) != int(offer.finalCost) or int(booking.maxHeat) != int(offer.maxHeat):
			return null
	if not values.variant_plan.is_empty() and not Run.Variants.valid(values.variant_plan, content, values.scene_id):
		return null
	if values.offer_index < 0 or values.offer_index >= content.routes[values.scene_id].fixedRoutes.size():
		return null
	var completed_ids := {}
	for id in values.completed:
		if not content.tables.has(id) or completed_ids.has(id): return null
		completed_ids[id] = true
	if values.arrival_completed < 0 or values.arrival_completed > values.completed.size(): return null
	var visited := {}
	for id in values.venue_history:
		if not id is String or not content.scenes.has(id) or visited.has(id): return null
		visited[id] = true
	if not values.venue_history.is_empty() and values.venue_history.back() != values.scene_id: return null
	if values.transfer_log.size() != maxi(0,values.venue_history.size()-1): return null
	var previous_tables := 0
	for i in range(values.transfer_log.size()):
		var hop: Variant = values.transfer_log[i]
		if not hop is Dictionary or hop.get("from") != values.venue_history[i] or hop.get("to") != values.venue_history[i+1] or not hop.get("fee") is int or hop.fee < 15: return null
		if not hop.get("after_tables") is int or hop.after_tables <= previous_tables or hop.after_tables >= 4 or hop.after_tables > values.completed.size(): return null
		previous_tables = hop.after_tables
	if values.arrival_completed != previous_tables: return null
	var occupied := 0
	for id in values.inventory:
		if not id is String or not content.items.has(id):
			return null
		occupied += int(content.items[id].slots)
	if occupied > int(content.inventorySlots): return null
	if not values.collateral.is_empty() and (not content.items.has(values.collateral) or content.items[values.collateral].kind != "valuable" or values.table.is_empty()):
		return null
	for field in FIELDS:
		if run.get(field) is Array:
			run.get(field).assign(values[field])
		else:
			run.set(field, values[field])
	if not values.table.is_empty():
		var stored_state: Variant = values.table.get("state")
		if not stored_state is Dictionary or not stored_state.get("tableDef") is Dictionary:
			return null
		var id: Variant = stored_state.tableDef.get("id")
		if not id is String or not content.tables.has(id) or stored_state.tableDef != run.table_definition(id):
			return null
		run.table = TableCheckpoint.restore(values.table)
		if run.table == null or not run.active:
			return null
	return run
