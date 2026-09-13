extends RefCounted
## A committed run plan. Shelf variation removes one optional tool, never basic information/cooling.
const Poker = preload("res://three_d/rules/poker.gd")
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
	return {"version":1,"shelves":shelves,"table_seeds":table_seeds,"initial_offer":int(rng.next() * content.routes[scene].fixedRoutes.size()) if seed_value != 0 else 0}

static func valid(plan: Dictionary, content: Dictionary, scene: String) -> bool:
	if plan.get("version") != 1 or not plan.get("shelves") is Dictionary or not plan.get("table_seeds") is Dictionary:
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
	return true
