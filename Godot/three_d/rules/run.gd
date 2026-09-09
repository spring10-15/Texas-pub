extends RefCounted
## Run economy and services. Owns the table reference so callers cannot settle arbitrary stacks.
const TableRules = preload("res://three_d/rules/table.gd")
const Routes = preload("res://three_d/rules/routes.gd")
const Advanced = preload("res://three_d/rules/advanced_services.gd")
const SUPPORTED_ITEMS := ["marked-lens", "steadying-drink", "sleeve-clip", "signal-lighter", "player-notes", "disposable-phone", "kitchen-pass", "dock-passkey", "false-bottom-wallet"]
const ITEM_NAMES := {"marked-lens": "标记镜片", "steadying-drink": "镇定酒", "sleeve-clip": "袖口夹", "signal-lighter":"信号打火机", "player-notes":"玩家笔记", "disposable-phone":"一次性手机", "kitchen-pass":"后厨通行证", "dock-passkey":"码头密钥", "false-bottom-wallet":"夹层钱包"}
const SCENE_NAMES := {"smoky-den":"烟雾酒馆", "high-rise-suite":"高层套房", "rooftop-club":"屋顶会所", "neon-poker-club":"霓虹扑克俱乐部"}
var scene_id := "smoky-den"
var collateral := ""
var last_table_result: Dictionary = {}
var inventory: Array[String] = []
var known_rules: Array[String] = []
var used_tools: Array[String] = []
var preview: Dictionary = {}
var preview_hand := 0
var action_points := 2
var search_index := 1
var heat_reduced := false
var service_message := ""
var last_reward := ""
var route_flags: Dictionary = {}
var reservation: Dictionary = {}
var offer_index := 0
var full_intel: Dictionary = {}
var opponent_notes: Dictionary = {}
var content: Dictionary
var vault: int
var active := false
var cash := 0
var bankroll := 0
var heat := 0
var public_exit := false
var completed: Array[String] = []
var table: RefCounted
var last_result: Dictionary = {}
var revision := 0

func _init(definitions: Dictionary) -> void:
	content = definitions
	vault = int(content.startingVault)

func start(expected_revision: int, destination := "smoky-den") -> bool:
	if expected_revision != revision or active or vault < 120 or not content.scenes.has(destination):
		return false
	scene_id = destination
	bankroll = mini(int(content.standardBankroll), vault)
	vault -= bankroll
	cash = bankroll
	heat = 0
	public_exit = false
	completed.clear()
	collateral = ""
	last_table_result = {}
	inventory.clear()
	known_rules.clear()
	action_points = int(content.searchActions)
	search_index = 1
	heat_reduced = false
	preview = {}
	service_message = ""
	last_result = {}
	last_reward = ""
	used_tools.clear()
	route_flags.clear()
	reservation.clear()
	full_intel.clear()
	opponent_notes.clear()
	offer_index = 0
	active = true
	revision += 1
	return true

func table_blocked_reason(table_id := "cargo-table") -> String:
	if not content.tables.has(table_id):
		return "该牌桌尚未开放"
	if not active:
		return "先从藏匿点进入酒馆"
	if table != null:
		return "当前牌桌尚未结算"
	if table_id in completed:
		return "本局已完成此桌，可继续探索或撤离"
	var definition: Dictionary = content.tables[table_id]
	if definition.unlocksAfter != null and definition.unlocksAfter not in completed:
		return "先完成" + table_name(definition.unlocksAfter) + "并离座"
	if cash < int(definition.buyIn):
		return "随身现金不足 %d，无法买入" % int(definition.buyIn)
	return ""

func enter_table(seed_value: int, expected_revision: int, table_id := "cargo-table", pledged_item := "") -> RefCounted:
	if expected_revision != revision or not table_blocked_reason(table_id).is_empty():
		return null
	var definition: Dictionary = content.tables[table_id]
	if not pledged_item.is_empty():
		if not definition.get("allowCollateral", false) or pledged_item not in inventory or content.items[pledged_item].kind != "valuable":
			return null
		inventory.erase(pledged_item)
	collateral = pledged_item
	cash -= int(definition.buyIn)
	heat = mini(6, heat + int(definition.heatGain) + int(scene_definition().entryHeatBonus))
	used_tools.clear()
	preview = {}
	table = TableRules.new()
	table.start(definition, seed_value)
	revision += 1
	return table

func settle_table(expected_revision: int) -> bool:
	if expected_revision != revision or not active or table == null or table.state.status != "finished":
		return false
	var stack: int = table.state.players[0].stack
	cash += stack
	last_reward = ""
	var definition: Dictionary = table.state.tableDef
	var summary: Dictionary = table.state.summary
	var won_final: bool = "player" in summary.pots[0].winnerIds if not summary.get("pots", []).is_empty() else int(summary.get("awards", {}).get("player", 0)) > 0
	var returned := not collateral.is_empty() and won_final
	if returned:
		inventory.append(collateral)
	var reward := ""
	var reward_added := false
	if stack > int(definition.buyIn):
		match definition.id:
			"cargo-table": reward = "ivory-chip" if "ivory-chip" not in inventory else ("ruby-cufflink" if stack >= 90 else "old-silver-lighter")
			"ledger-cellar": reward = "pearl-necklace" if stack >= 130 else "emerald-brooch"
			"mirror-hall": reward = "antique-coin" if returned else ("sealed-bond" if stack >= 170 else "gold-cased-watch")
			"embers-table": reward = "vault-promissory" if stack >= 220 else "obsidian-idol"
		if slots_used() + int(content.items[reward].slots) <= int(content.inventorySlots):
			inventory.append(reward)
			reward_added = true
			last_reward = "获得 " + item_name(reward)
		else:
			last_reward = "背包已满，未能带走 " + item_name(reward)
		heat = maxi(0, heat - int(definition.get("winHeatRelief", 0)))
	last_table_result = {"table":definition.id, "net":stack - int(definition.buyIn), "collateral":collateral, "returned":returned, "reward":reward, "reward_added":reward_added}
	if not collateral.is_empty():
		last_reward += "\n抵押物" + ("已归还：" if returned else "已失去：") + item_name(collateral)
	collateral = ""
	completed.append(table.state.tableDef.id)
	table = null
	search_index += 1
	action_points = int(content.searchActions)
	heat_reduced = false
	public_exit = true
	revision += 1
	return true

func discover_exit() -> bool:
	if not active or table != null or public_exit:
		return false
	public_exit = true
	revision += 1
	return true

func extraction_quote(kind := "general") -> Dictionary:
	return Routes.quote(self, kind)

func extract(expected_revision: int, kind := "general") -> bool:
	var quote := extraction_quote(kind)
	if expected_revision != revision or not quote.reason.is_empty():
		return false
	last_result = {"cash": cash, "valuables": quote.valuables, "fee": quote.fee, "net": quote.net, "profit": quote.net - bankroll, "route":kind, "lostCash":quote.lostCash, "lostGoods":quote.lostGoods}
	vault += int(quote.net)
	cash = 0
	inventory.clear()
	active = false
	revision += 1
	return true

func reset_demo(expected_revision: int) -> bool:
	if expected_revision != revision or active or vault >= 120:
		return false
	vault = int(content.startingVault)
	last_result = {}
	revision += 1
	return true

func slots_used() -> int:
	var slots := 0
	for item_id in inventory:
		slots += int(content.items[item_id].slots)
	return slots

func service_reason(kind: String, item_id: String, target_id := "") -> String:
	if kind in Advanced.KINDS:
		return Advanced.reason(self, kind, item_id, target_id)
	if not active:
		return "请先带钱进入酒馆"
	if kind in ["lens", "sleeve", "drink"] and item_id != {"lens": "marked-lens", "sleeve": "sleeve-clip", "drink": "steadying-drink"}[kind]:
		return "道具与动作不匹配"
	if kind in ["lens", "sleeve"]:
		if table == null or table.state.status != "playing":
			return "只能在进行中的牌桌使用"
		if item_id not in inventory:
			return "背包中没有此道具"
		if item_id in used_tools:
			return "本桌已经使用过"
		if kind == "lens" and table.state.street == "river":
			return "公共牌已全部揭晓"
		if kind == "sleeve" and (table.state.street != "preflop" or table.state.turnCounter > 0 or table.state.currentActorId != "player"):
			return "只能在翻牌前首次行动前换牌"
		return ""
	if table != null:
		return "请先结束牌桌并离座"
	if action_points <= 0:
		return "本轮行动力已用完，完成牌桌后刷新"
	if kind == "buy":
		if item_id not in SUPPORTED_ITEMS or item_id not in shop_stock():
			return "本轮未上架"
		if cash < int(content.items[item_id].buy):
			return "随身现金不足"
		if slots_used() + int(content.items[item_id].slots) > int(content.inventorySlots):
			return "背包已满"
	elif kind == "sell":
		if item_id not in inventory:
			return "背包中没有此物品"
	elif kind in ["drink", "cool"]:
		if heat_reduced or heat <= 0:
			return "本轮已降过风声或无需降风声"
		if kind == "drink" and "steadying-drink" not in inventory:
			return "背包中没有镇定酒"
		if kind == "cool" and cash < int(scene_definition().heatReductionCost):
			return "随身现金不足"
	elif kind == "intel":
		if not content.tables.has(item_id) or item_id in known_rules:
			return "该牌桌规则已知或尚未开放"
	else:
		return "未知操作"
	return ""

func shop_stock() -> Array:
	var shops: Dictionary = content.shops[scene_id]
	var stock: Array = shops.get(str(search_index), shops["3"]).duplicate()
	# The two-table slice must offer the phone before its final table.
	if search_index == 2 and "disposable-phone" not in stock:
		stock.append("disposable-phone")
	return stock

func service_action(kind: String, item_id: String, expected_revision: int, target_id := "") -> bool:
	if expected_revision != revision or not service_reason(kind, item_id, target_id).is_empty():
		return false
	if kind in Advanced.KINDS:
		Advanced.apply(self, kind, item_id, target_id)
		revision += 1
		return true
	if kind == "buy":
		cash -= int(content.items[item_id].buy)
		inventory.append(item_id)
		service_message = "已购买 " + item_name(item_id)
	elif kind == "sell":
		cash += sale_value(item_id)
		inventory.erase(item_id)
		service_message = "已出售 " + item_name(item_id)
	elif kind in ["drink", "cool"]:
		if kind == "drink":
			inventory.erase("steadying-drink")
		else:
			cash -= int(scene_definition().heatReductionCost)
		heat -= 1
		heat_reduced = true
		service_message = "风声降低 1"
	elif kind == "intel":
		known_rules.append(item_id)
		service_message = "已查明牌桌规则"
	elif kind == "lens":
		preview = table.state.deck.back().duplicate()
		preview_hand = table.state.handNumber
		service_message = "已记录下一张公共牌；翻牌时会出现此牌"
	elif kind == "sleeve":
		# Preserve a previously previewed top card for the next community draw.
		var index: int = table.state.deck.size() - 1
		if not preview.is_empty() and preview_hand == table.state.handNumber and table.state.deck[index] == preview:
			index -= 1
		table.state.players[0].holeCards[1] = table.state.deck.pop_at(index)
		service_message = "已替换第二张手牌"
	if kind in ["lens", "sleeve"]:
		inventory.erase(item_id)
		used_tools.append(item_id)
		heat = mini(6, heat + int(content.items[item_id].heat) + int(table.state.tableDef.get("tableToolHeatBonus", 0)))
		table.revision += 1
	else:
		action_points -= 1
	revision += 1
	return true

func service_view(mode := "bag", product := "") -> Dictionary:
	var actions: Array = []
	if table == null:
		for item_id in shop_stock():
			if item_id in SUPPORTED_ITEMS:
				actions.append({"kind": "buy", "id": item_id, "label": "买 %s · %d" % [item_name(item_id), content.items[item_id].buy]})
		actions.append({"kind": "cool", "id": "", "label": "找酒保降风声 · %d" % scene_definition().heatReductionCost})
		for table_id in content.tables:
			actions.append({"kind": "intel", "id": table_id, "label": "调查%s规则 · 1 行动力" % table_name(table_id)})
	for item_id in inventory.duplicate():
		if item_id in ["steadying-drink", "marked-lens", "sleeve-clip"]:
			var kind: String = {"steadying-drink": "drink", "marked-lens": "lens", "sleeve-clip": "sleeve"}[item_id]
			actions.append({"kind": kind, "id": item_id, "label": "使用 " + item_name(item_id)})
		if table == null:
			actions.append({"kind": "sell", "id": item_id, "label": "卖 %s · %d" % [item_name(item_id), sale_value(item_id)]})
	if table == null:
		if "disposable-phone" in inventory:
			actions.append({"kind":"phone-route", "id":"disposable-phone", "label":"使用手机 · 更新接应路线"})
			for table_id in content.tables:
				actions.append({"kind":"phone-table", "id":"disposable-phone", "target":table_id, "label":"使用手机 · 查明" + table_name(table_id) + "全部情报"})
		for pass_id in ["kitchen-pass", "dock-passkey"]:
			if pass_id in inventory:
				actions.append({"kind":"pass", "id":pass_id, "label":"使用 " + item_name(pass_id)})
		actions.append({"kind":"reserve", "id":"", "label":"预约%s · 预付 %d / 尾款 %d" % [offer_name(route_offer().id), reserve_fee(), route_offer().finalCost]})
		for route in Routes.NAMES:
			actions.append({"kind":"route", "id":route, "label":"查看路线 · " + route_name(route)})
	else:
		for item_id in ["signal-lighter", "player-notes"]:
			if item_id in inventory:
				for actor in table.state.players.slice(1):
					actions.append({"kind":"signal" if item_id == "signal-lighter" else "notes", "id":item_id, "target":actor.id, "label":"%s → %s" % [item_name(item_id), actor_name(actor.id)]})
	var visible: Array = []
	for action in actions:
		if mode == "product":
			if action.kind == "buy" and action.id == product:
				visible.append(action)
		elif mode == "bar":
			if action.kind in ["cool", "intel"] or (action.kind == "reserve" and fixed_known()):
				visible.append(action)
		else:
			if action.kind == "route":
				if route_known(action.id):
					visible.append(action)
			elif action.kind not in ["buy", "sell", "cool", "intel", "reserve"]:
				visible.append(action)
	# Selling belongs to the bartender, and only lists held objects.
	if mode == "bar":
		for action in actions:
			if action.kind == "sell":
				visible.append(action)
	actions = visible
	for action in actions:
		action.reason = "" if action.kind == "route" else service_reason(action.kind, action.id, action.get("target", ""))
	var text := "" if mode == "bag" else last_reward + "\n" + service_message
	if not reservation.is_empty():
		text += "\n%s：当前第 %d 轮，第 %d 轮结束前有效，尾款 %d" % [offer_name(reservation.id), search_index, reservation.expiresAfterSearch, reservation.finalCost]
	for table_id in full_intel:
		text += "\n%s：对手 %s；奖励 %s" % [table_name(table_id), "、".join(content.tables[table_id].opponentIds.map(func(id): return actor_name(id))), "、".join(content.tables[table_id].baseRewardPool.map(func(id): return item_name(id)))]
	for actor in opponent_notes:
		text += "\n%s 风格：%s" % [actor_name(actor), archetype_name(opponent_notes[actor])]
	for table_id in known_rules:
		text += "\n" + table_name(table_id) + "：" + rule_text(table_id)
	if not preview.is_empty():
		text += "\n镜片记录（第 %d 手）：%s%s" % [preview_hand, str({11:"J", 12:"Q", 13:"K", 14:"A"}.get(int(preview.rank), str(preview.rank))), {"S":"♠", "H":"♥", "D":"♦", "C":"♣"}[preview.suit]]
	var bag: PackedStringArray = []
	for item_id in inventory:
		bag.append(item_name(item_id))
	return {"mode": mode, "product": product, "productName": item_name(product), "description": item_description(product), "revision": revision, "cash": cash, "heat": heat, "points": action_points, "slots": slots_used(), "capacity": content.inventorySlots, "bag": "、".join(bag), "text": text, "actions": actions}

func item_name(id: String) -> String:
	return {"ivory-chip": "象牙筹码", "ruby-cufflink": "红宝石袖扣", "old-silver-lighter": "旧银打火机", "pearl-necklace": "珍珠项链", "emerald-brooch": "翡翠胸针", "antique-coin":"古董纪念币", "sealed-bond":"密封债券", "gold-cased-watch":"金壳怀表", "vault-promissory":"金库本票", "obsidian-idol":"黑曜石雕像"}.get(id, ITEM_NAMES.get(id, id))

func sale_value(id: String) -> int:
	var item: Dictionary = content.items[id]
	return int(item.value if item.kind == "valuable" else item.sell)

func valuable_total() -> int:
	var total := 0
	for id in inventory:
		if content.items[id].kind == "valuable":
			total += int(content.items[id].value)
	return total

func abandon(expected_revision: int) -> bool:
	if expected_revision != revision or not active or table != null:
		return false
	var salvaged := mini(80, cash) if "false-bottom-wallet" in inventory else 0
	vault += salvaged
	last_result = {"cash": cash, "valuables": valuable_total(), "fee": 0, "net": salvaged, "profit": salvaged - bankroll, "abandoned": true}
	cash = 0
	inventory.clear()
	active = false
	revision += 1
	return true

func route_offer() -> Dictionary:
	return content.routes[scene_id].fixedRoutes[offer_index]

func fixed_known() -> bool:
	return "cargo-table" in completed or route_flags.get("fixed", false)

func emergency_known() -> bool:
	return heat >= 4 or not completed.is_empty() or valuable_total() > 0

func actor_name(id: String) -> String:
	return {"player":"你", "dock-braggart":"码头吹牛客", "ledger-clerk":"账房先生", "river-shark":"河道老鲨", "velvet-rook":"绒衣新客", "calm-widow":"沉静寡妇", "smiling-knife":"笑面刀", "house-viper":"庄家毒蛇", "ash-smuggler":"灰烬走私客"}.get(id, id)

func table_name(id: String) -> String:
	return {"cargo-table":"货运桌", "ledger-cellar":"账房地窖", "mirror-hall":"镜厅", "embers-table":"余烬桌"}.get(id, id)

func archetype_name(value: String) -> String:
	return {"Maniac":"激进型", "Nit":"紧手型", "Fish":"松散型", "Shark":"老练型", "Calling Station":"跟注型"}.get(value, value)

func enforce_pressure() -> bool:
	if not active or table != null or heat < 6:
		return false
	var best_route := ""
	var best_cash := -1
	for kind in Routes.NAMES:
		var option := extraction_quote(kind)
		if option.reason.is_empty() and option.net > best_cash:
			best_route = kind
			best_cash = option.net
	if best_route.is_empty():
		abandon(revision)
	else:
		extract(revision, best_route)
	last_result["forced"] = true
	return true

func offer_name(id: String) -> String:
	return {"kitchen-backlift":"后厨货梯接应", "linen-cart":"布草车接应", "vip-elevator":"贵宾电梯", "laundry-trolley":"洗衣推车", "staff-door":"员工通道", "valet-loop":"代客泊车接应", "data-node-gate":"数据节点闸门", "hack-door":"伪装员工门禁"}.get(id, id)

func route_known(kind: String) -> bool:
	if not active:
		return false
	match kind:
		"general": return public_exit
		"fixed": return fixed_known()
		"service-stairs", "river-launch": return route_flags.get(kind, false)
		"dropbag-cash", "dropbag-valuables": return emergency_known()
	return false

func item_description(id: String) -> String:
	if id in ["kitchen-pass", "dock-passkey"]:
		return "离桌后使用，揭示" + route_name(content.items[id].unlockRoute) + "。"
	return {"marked-lens":"牌局中提前看下一张公共牌；本桌限一次，增加风声。", "steadying-drink":"离桌后使用，降低 1 风声；每轮只能降一次。", "sleeve-clip":"翻牌前第一次行动前更换第二张手牌，增加风声。", "signal-lighter":"牌局中选择对手，判断其牌力强弱；不揭示底牌，增加风声。", "player-notes":"牌局中记录一位对手的风格，增加风声。", "disposable-phone":"离桌后查明一桌情报，或更新接应方案；二选一。", "kitchen-pass":"离桌后使用，揭示后厨楼梯出口。", "dock-passkey":"离桌后使用，揭示河边接驳出口。", "false-bottom-wallet":"随身携带，失败时自动保留至多 80 现金。"}.get(id, "")

func rule_text(id: String) -> String:
	return {"cargo-table":"每手首次加注少付 10", "ledger-cellar":"每次桌面道具额外增加 1 风声", "mirror-hall":"可押一件贵重物；最后一手获胜归还，且盈利时获得纪念币", "embers-table":"可押一件贵重物；最后一手获胜归还，整桌盈利降低 1 风声"}.get(id, "")

func scene_definition() -> Dictionary:
	return content.scenes[scene_id]

func reserve_fee() -> int:
	return maxi(10, int(route_offer().reserveCost) - int(scene_definition().fixedRouteReserveDiscount))

func route_name(kind: String) -> String:
	if kind == "fixed":
		return offer_name(reservation.id if not reservation.is_empty() else route_offer().id)
	if kind in ["service-stairs", "river-launch"]:
		var id: String = content.routes[scene_id].specialRoutes[kind].id
		return {"service-stairs":"后厨楼梯", "river-launch":"河边接驳", "service-elevator":"维修电梯", "basement-garage":"地下车库", "emergency-exit":"消防楼梯", "helipad-drop":"停机坪接应", "neural-jammer":"传感器盲区走廊", "quantum-portal":"后台传送门"}[id]
	return Routes.NAMES.get(kind, kind)
