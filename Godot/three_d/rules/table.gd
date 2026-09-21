extends RefCounted
## Pure, synchronous table state. UI owns delays; all chip changes happen here.
const Poker = preload("res://three_d/rules/poker.gd")
var state: Dictionary
var rng: Poker.DeterministicRng
var revision := 0

func start(definition: Dictionary, seed_value: int) -> void:
	rng = Poker.DeterministicRng.new(seed_value)
	state = {"tableDef": definition.duplicate(true), "seed": seed_value, "players": [], "handNumber": 1, "totalHands": int(definition.hands), "playerPattern": {"raiseCount": 0}, "log": [], "status": "playing"}
	var ids: Array = ["player"] + definition.opponentIds
	for i in range(ids.size()):
		state.players.append({"id": ids[i], "archetypeId": ids[i], "seatIndex": i, "stack": int(definition.buyIn), "holeCards": [], "currentBet": 0, "handContribution": 0, "folded": false, "lastAction": ""})
	start_hand()

func ordered_after(pivot: int, include_pivot := true, require_chips := true) -> Array:
	var ordered: Array = []
	for step in range(1, state.players.size() + (1 if include_pivot else 0)):
		var player: Dictionary = state.players[(pivot + step) % state.players.size()]
		if not player.folded and (not require_chips or player.stack > 0):
			ordered.append(player)
	return ordered

func start_hand(rotate_dealer := false) -> void:
	revision += 1
	state.merge({"pot": 0, "currentBet": 0, "community": [], "street": "preflop", "raiseUsed": false, "firstAggressionDiscountAvailable": state.tableDef.id == "cargo-table", "turnCounter": 0, "pendingNextHand": false, "pendingConclusion": false, "status": "playing", "summary": {}, "currentActorId": ""}, true)
	for player in state.players:
		player.merge({"folded": player.stack <= 0, "currentBet": 0, "handContribution": 0, "holeCards": [], "lastAction": ""}, true)
	var dealer: int = int(state.get("dealerSeat",0))
	var funded := ordered_after(dealer)
	if funded.size() < 2 or state.players[0].stack <= 0:
		state.status = "finished"
		state.pendingConclusion = true
		return
	if rotate_dealer or state.players[dealer].folded:
		dealer = funded[0].seatIndex
	state.dealerSeat = dealer
	var starters := ordered_after(dealer)
	# Heads-up: dealer posts small blind; preserve all starters before posting all-in blinds.
	var small: Dictionary = state.players[state.dealerSeat] if starters.size() == 2 else starters[0]
	var big: Dictionary = starters[0] if starters.size() == 2 else starters[1]
	state.smallBlindSeat = small.seatIndex
	state.bigBlindSeat = big.seatIndex
	commit(small, mini(small.stack, int(state.tableDef.smallBlind)))
	commit(big, mini(big.stack, int(state.tableDef.openBet)))
	state.currentBet = maxi(small.currentBet, big.currentBet)
	state.deck = Poker.shuffle_deck(Poker.create_deck(), rng)
	for round_index in range(2):
		for player in starters:
			player.holeCards.append(state.deck.pop_back())
	set_queue(ordered_after(state.bigBlindSeat))
	log_event("hand", "", state.handNumber)

func commit(player: Dictionary, amount: int) -> void:
	player.stack -= amount
	player.currentBet += amount
	player.handContribution += amount
	state.pot += amount

func legal_actions(id: String) -> Dictionary:
	if state.status != "playing" or state.currentActorId != id:
		return {}
	var player := find_player(id)
	if player.is_empty() or player.folded or player.stack <= 0:
		return {}
	var cost := maxi(0, state.currentBet - player.currentBet)
	var discount := 10 if state.firstAggressionDiscountAvailable else 0
	var open_cost := maxi(0, int(state.tableDef.openBet) - discount)
	var raise_cost := maxi(0, int(state.tableDef.raiseIncrement) - discount)
	var can_raise: bool
	if cost == 0:
		can_raise = player.stack > open_cost if state.currentBet == 0 else not state.raiseUsed and player.stack > raise_cost
	else:
		can_raise = not state.raiseUsed and player.stack > cost + raise_cost
	return {"fold": true, "check": cost == 0, "call": cost > 0 and player.stack >= cost, "raise": can_raise, "allIn": player.stack > 0}

func act(id: String, kind: String, expected_revision: int, raise_target := -1) -> bool:
	if revision != expected_revision or kind not in ["fold", "check", "call", "raise", "all-in"]:
		return false
	var legal := legal_actions(id)
	var key := "allIn" if kind == "all-in" else kind
	if not legal.get(key, false):
		return false
	var player := find_player(id)
	var reset_queue := false
	var amount := 0
	var old_target := int(state.currentBet)
	if kind == "raise":
		var minimum: int = state.tableDef.openBet if old_target == 0 else old_target + int(state.tableDef.raiseIncrement)
		if raise_target != -1 and raise_target < minimum:
			return false
		var target := maxi(minimum, raise_target)
		amount = target - int(player.currentBet)
		if state.firstAggressionDiscountAvailable:
			amount = maxi(0, amount - 10)
			state.firstAggressionDiscountAvailable = false
		if player.stack <= amount:
			kind = "all-in"
		else:
			commit(player, amount)
			state.currentBet = target
			state.raiseUsed = old_target != 0
			reset_queue = true
	if kind == "fold":
		player.folded = true
	elif kind == "call":
		amount = maxi(0, state.currentBet - player.currentBet)
		commit(player, amount)
	elif kind == "all-in":
		amount = player.stack
		var target: int = player.currentBet + amount
		commit(player, amount)
		reset_queue = target > state.currentBet
		if reset_queue:
			state.currentBet = target
			state.raiseUsed = true
	player.lastAction = kind
	if id == "player" and kind in ["raise", "all-in"]:
		state.playerPattern.raiseCount += 1
	state.turnCounter += 1
	revision += 1
	log_event(kind, id, amount)
	var survivors: Array = state.players.filter(func(p): return not p.folded)
	if survivors.size() == 1:
		var winner: Dictionary = survivors[0]
		winner.stack += state.pot
		state.summary = {"kind": "fold", "awards": {winner.id: state.pot}, "pots": [], "hands": {}}
		finish_hand()
	elif reset_queue:
		set_queue(ordered_after(player.seatIndex, false))
	else:
		state.toAct.pop_front()
		set_queue(state.toAct.map(func(actor_id): return find_player(actor_id)))
	return true

func set_queue(ordered: Array) -> void:
	var available := ordered.filter(func(p): return not p.folded and p.stack > 0)
	var funded: Array = state.players.filter(func(p): return not p.folded and p.stack > 0)
	# A lone funded seat only acts when it still owes a call; otherwise run out the board.
	if funded.size() == 1 and funded[0].currentBet >= state.currentBet:
		available.clear()
	state.toAct = available.map(func(p): return p.id)
	state.currentActorId = state.toAct[0] if not state.toAct.is_empty() else ""

func advance(expected_revision: int) -> bool:
	if revision != expected_revision or state.status != "playing" or not state.currentActorId.is_empty():
		return false
	revision += 1
	if state.street == "river":
		for player in state.players:
			player.currentBet = 0
		state.currentBet = 0
		state.raiseUsed = false
		var result := Poker.settle_pots(state.players, state.community)
		for player in state.players:
			player.stack += result.awards[player.id]
		state.summary = result
		state.summary.kind = "showdown"
		finish_hand()
		return true
	var streets := ["preflop", "flop", "turn", "river"]
	state.street = streets[streets.find(state.street) + 1]
	for i in range(3 if state.street == "flop" else 1):
		state.community.append(state.deck.pop_back())
	for player in state.players:
		player.currentBet = 0
	state.currentBet = 0
	state.raiseUsed = false
	set_queue(ordered_after(state.dealerSeat))
	log_event("street", "", state.community.size())
	return true

func finish_hand() -> void:
	# Folded opponents with remaining chips return next hand; a fold win is not a table end.
	var funded: Array = state.players.filter(func(p): return p.stack > 0)
	state.pendingConclusion = state.handNumber >= state.totalHands or state.players[0].stack <= 0 or funded.size() < 2
	state.pendingNextHand = not state.pendingConclusion
	state.status = "finished" if state.pendingConclusion else "hand_over"
	state.currentActorId = ""
	state.toAct = []
	state.summary.pot = state.pot
	log_event("result", "", state.players[0].stack)

func next_hand(expected_revision: int) -> bool:
	if revision != expected_revision or state.status != "hand_over":
		return false
	state.handNumber += 1
	start_hand(true)
	return true

func find_player(id: String) -> Dictionary:
	for player in state.players:
		if player.id == id:
			return player
	return {}

func log_event(kind: String, actor: String, amount: int) -> void:
	state.log.append({"kind": kind, "actor": actor, "amount": amount, "street": state.street})
	if state.log.size() > 8:
		state.log.pop_front()

func public_state() -> Dictionary:
	var view := state.duplicate(true)
	view.erase("deck")
	view["revision"] = revision
	view["legal"] = legal_actions("player")
	for player in view.players:
		if player.id != "player" and (state.status == "playing" or state.summary.get("kind", "") != "showdown" or player.folded):
			player.holeCards = []
	return view
