extends RefCounted
## A committed run plan. Shelf variation removes one optional tool, never basic information/cooling.
const Poker = preload("res://three_d/rules/poker.gd")
const SearchEvents = preload("res://three_d/rules/search_events.gd")
const TABLES := ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]
const ESSENTIALS := ["steadying-drink", "player-notes", "disposable-phone"]
static func generate(content: Dictionary, scene: String, seed_value: int) -> Dictionary:
	var rng := Poker.DeterministicRng.new(seed_value)
	var shelves := {}
	for stage in range(1, 6):
		var stock: Array = content.shops[scene][str(stage)].duplicate()
		if stage == 2 and "disposable-phone" not in stock:
			stock.append("disposable-phone")
		var optional := stock.filter(func(id): return id not in ESSENTIALS)
		if seed_value != 0 and optional.size() > 1:
			stock.erase(optional[int(rng.next() * optional.size())])
		shelves[str(stage)] = stock
	var table_seeds := {}
	for id in TABLES:
		table_seeds[id] = int(rng.next() * 2147483647)
	var offer := int(rng.next() * content.routes[scene].fixedRoutes.size()) if seed_value != 0 else 0
	var events := {}
	for pair in SearchEvents.PAIRS:
		var swap := seed_value != 0 and rng.next() < 0.5
		events[pair[0]] = pair[1] if swap else pair[0]
		events[pair[1]] = pair[0] if swap else pair[1]
	return {"version":2,"shelves":shelves,"table_seeds":table_seeds,"initial_offer":offer,"events":events}

static func valid(plan: Dictionary, content: Dictionary, scene: String) -> bool:
	if plan.get("version") not in [1, 2] or not plan.get("shelves") is Dictionary or not plan.get("table_seeds") is Dictionary:
		return false
	if not plan.get("initial_offer") is int or plan.initial_offer < 0 or plan.initial_offer >= content.routes[scene].fixedRoutes.size():
		return false
	for stage in range(1, 6):
		var stock: Variant = plan.shelves.get(str(stage))
		if not stock is Array or stock.is_empty(): return false
		var allowed: Array = content.shops[scene][str(stage)].duplicate()
		if stage == 2: allowed.append("disposable-phone")
		var seen := {}
		for id in stock:
			if not id is String or id not in allowed or seen.has(id): return false
			seen[id] = true
		for id in ESSENTIALS:
			if id in allowed and id not in stock: return false
	for id in TABLES:
		var value: Variant = plan.table_seeds.get(id)
		if not value is int or value < 0 or value >= 2147483647: return false
	if plan.version == 2:
		if not plan.get("events") is Dictionary or plan.events.size() != TABLES.size(): return false
		for pair in SearchEvents.PAIRS:
			if plan.events.get(pair[0]) not in pair or plan.events.get(pair[1]) not in pair or plan.events[pair[0]] == plan.events[pair[1]]: return false
	elif plan.has("events"):
		return false
	return true
