extends RefCounted
const Odds = preload("res://three_d/rules/opponent.gd")
const KINDS := ["signal", "notes", "phone-route", "phone-table", "pass", "reserve"]
static func reason(run: RefCounted, kind: String, item: String, target: String) -> String:
	if not run.active:
		return "尚未出发"
	var expected: String = {"signal":"signal-lighter", "notes":"player-notes", "phone-route":"disposable-phone", "phone-table":"disposable-phone", "pass":item, "reserve":""}[kind]
	if item != expected or (kind != "reserve" and item not in run.inventory):
		return "背包中没有对应物品"
	if kind in ["signal", "notes"]:
		if run.table == null or run.table.state.status != "playing":
			return "只能在进行中的牌桌使用"
		var actor: Dictionary = run.table.find_player(target)
		if actor.is_empty() or target == "player" or (kind == "signal" and actor.folded):
			return "请选一位有效对手"
		if kind == "signal" and item in run.used_tools:
			return "本桌已使用过信号打火机"
		return ""
	if run.table != null:
		return "请先结束牌桌并离座"
	if run.action_points <= 0:
		return "行动力不足"
	if kind == "reserve":
		if not run.fixed_known():
			return "先完成货运桌或使用手机获取接应线索"
		if not run.reservation.is_empty() and run.search_index <= run.reservation.expiresAfterSearch:
			return "已有有效预约"
		if run.cash < run.reserve_fee():
			return "预约现金不足"
	elif kind == "phone-table" and not run.content.tables.has(target):
		return "请选择有效牌桌"
	elif kind == "pass":
		if item not in ["kitchen-pass", "dock-passkey"]:
			return "不是路线通行证"
		if run.route_flags.get(run.content.items[item].unlockRoute, false):
			return "此路线已揭示"
	return ""
static func apply(run: RefCounted, kind: String, item: String, target: String) -> void:
	if kind == "reserve":
		run.reservation = run.route_offer().duplicate(true)
		var fee: int = run.reserve_fee()
		run.cash -= fee
		run.reservation.reserveCost = fee
		run.reservation.expiresAfterSearch = run.search_index + maxi(1, int(run.scene_definition().fixedRouteGraceSearches))
		run.service_message = "已预约接应，预付 %d；到达时另付 %d" % [fee, run.reservation.finalCost]
	elif kind == "pass":
		run.route_flags[run.content.items[item].unlockRoute] = true
		run.service_message = "已揭示 " + run.route_name(run.content.items[item].unlockRoute)
	elif kind == "phone-route":
		run.offer_index = (run.offer_index + 1) % run.content.routes[run.scene_id].fixedRoutes.size()
		run.route_flags.fixed = true
		run.service_message = "手机已更新接应路线"
	elif kind == "phone-table":
		if target not in run.known_rules:
			run.known_rules.append(target)
		run.full_intel[target] = true
		run.service_message = "已查明该桌规则、对手与奖励"
	elif kind == "notes":
		run.opponent_notes[target] = run.content.opponents[target].archetype
		run.service_message = "已记录对手风格：" + run.archetype_name(run.opponent_notes[target])
	elif kind == "signal":
		var actor: Dictionary = run.table.find_player(target)
		var count := 0
		for other in run.table.state.players:
			if other.id != target and not other.folded:
				count += 1
		var odds := Odds.estimate_odds(actor.holeCards, run.table.state.community, count, int(run.table.state.seed) + int(run.table.state.handNumber) * 51 + int(actor.seatIndex) * 17, 75)
		run.service_message = "对手牌力：" + ("强" if odds >= 0.66 else ("中" if odds >= 0.4 else "弱")) + "（概率判断，不展示底牌）"
	if kind != "reserve":
		run.inventory.erase(item)
	if kind in ["notes", "signal"]:
		run.used_tools.append(item)
		run.heat = mini(6, run.heat + int(run.content.items[item].heat) + int(run.table.state.tableDef.get("tableToolHeatBonus", 0)))
		run.table.revision += 1
	else:
		run.action_points -= 1
