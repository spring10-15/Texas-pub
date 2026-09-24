extends RefCounted
const TableRules = preload("res://three_d/rules/table.gd")
const Poker = preload("res://three_d/rules/poker.gd")

static func capture(table: RefCounted) -> Dictionary:
	return {"state": table.state.duplicate(true), "revision": table.revision, "rngValue": table.rng.value}

static func restore(snapshot: Dictionary) -> RefCounted:
	if not snapshot.get("state") is Dictionary or not snapshot.get("revision") is int or not snapshot.get("rngValue") is int:
		return null
	if snapshot.revision < 0 or snapshot.rngValue < 0 or snapshot.rngValue > 0xffffffff:
		return null
	var state: Dictionary = snapshot.state
	if not state.get("tableDef") is Dictionary or not state.get("players") is Array or not state.get("deck") is Array or not state.get("community") is Array or not state.get("toAct") is Array:
		return null
	var definition: Dictionary = state.tableDef
	if not (definition.get("buyIn") is int or definition.get("buyIn") is float) or not is_finite(float(definition.buyIn)) or definition.buyIn <= 0 or definition.buyIn != floor(definition.buyIn) or not definition.get("opponentIds") is Array or definition.opponentIds.size() != 2:
		return null
	if state.players.size() != 3 or state.get("status") not in ["playing", "hand_over", "finished"] or not state.get("seed") is int or not state.get("handNumber") is int or not state.get("totalHands") is int or state.handNumber < 1 or state.handNumber > state.totalHands:
		return null
	if not state.get("pot") is int or state.pot < 0 or not state.get("currentActorId") is String or not state.get("currentBet") is int or state.currentBet < 0:
		return null
	var expected_ids: Array = ["player"] + definition.opponentIds
	var seen := {}
	var chips := 0
	var contributions := 0
	var highest_current_bet := 0
	for i in range(3):
		var player: Variant = state.players[i]
		if not player is Dictionary or player.get("id") != expected_ids[i] or player.get("seatIndex") != i or not player.get("stack") is int or player.stack < 0:
			return null
		if not player.get("currentBet") is int or player.currentBet < 0 or not player.get("handContribution") is int or player.handContribution < 0 or not player.get("folded") is bool or not player.get("holeCards") is Array:
			return null
		if player.currentBet > player.handContribution:
			return null
		chips += player.stack
		contributions += player.handContribution
		highest_current_bet = maxi(highest_current_bet, player.currentBet)
		for card in player.holeCards:
			if not valid_card(card,seen): return null
	for card in state.community + state.deck:
		if not valid_card(card,seen): return null
	if seen.size() != 52 or contributions != state.pot or (state.status == "playing" and highest_current_bet != state.currentBet) or chips + (state.pot if state.status == "playing" else 0) != definition.buyIn * 3:
		return null
	for id in state.toAct:
		if id not in expected_ids: return null
	if state.currentActorId != (state.toAct[0] if not state.toAct.is_empty() else ""):
		return null
	var table := TableRules.new()
	table.state = snapshot.state.duplicate(true)
	table.revision = snapshot.revision
	table.rng = Poker.DeterministicRng.new(0)
	table.rng.value = snapshot.rngValue
	return table

static func valid_card(card: Variant, seen: Dictionary) -> bool:
	if not card is Dictionary or not card.get("rank") is int or not card.get("suit") is String:
		return false
	if card.rank < 2 or card.rank > 14 or card.suit not in ["S", "H", "D", "C"]:
		return false
	var key: String = str(card.rank) + card.suit
	if seen.has(key): return false
	seen[key] = true
	return true
