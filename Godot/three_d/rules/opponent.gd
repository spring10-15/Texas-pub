extends RefCounted
const Poker = preload("res://three_d/rules/poker.gd")

static func estimate_odds(hole: Array, board: Array, opponents: int, seed_value: int, trials := 85) -> float:
	var known := hole + board
	var remaining := Poker.create_deck().filter(func(card): return not known.has(card))
	var score := 0.0
	for trial in range(trials):
		var deck := Poker.shuffle_deck(remaining, Poker.DeterministicRng.new(seed_value + trial * 31 + opponents * 17))
		var community := board.duplicate(true)
		while community.size() < 5:
			community.append(deck.pop_back())
		var player_hand := Poker.evaluate_best_hand(hole + community)
		var result := 1.0
		var tied := 1
		for i in range(opponents):
			var opponent_hand := Poker.evaluate_best_hand([deck.pop_back(), deck.pop_back()] + community)
			var comparison := Poker.compare_hands(player_hand, opponent_hand)
			if comparison < 0:
				result = 0.0
				break
			if comparison == 0:
				tied += 1
		score += result / tied
	return score / trials

static func choose(table: Dictionary, actor: Dictionary, legal: Dictionary, definition: Dictionary, random_value: float) -> String:
	# Opponent private/folded cards are never supplied to the estimator.
	var others: int = table.players.filter(func(p): return p.id != actor.id and not p.folded).size()
	var odds := estimate_odds(actor.holeCards, table.community, others, table.seed + table.handNumber * 137 + table.turnCounter * 19 + actor.seatIndex * 11)
	return choose_with_odds(table, actor, legal, definition, random_value, odds)

static func choose_with_odds(table: Dictionary, actor: Dictionary, legal: Dictionary, definition: Dictionary, random_value: float, odds: float) -> String:
	var profile: Dictionary = definition.profile.duplicate(true)
	var trailing: bool = actor.stack < table.tableDef.buyIn * 0.5
	match definition.archetype:
		"Nit":
			profile.aggression = maxf(0.08, profile.aggression - 0.12)
			profile.caution = minf(0.92, profile.caution + 0.16)
			profile.bluff = maxf(0.01, profile.bluff - 0.04)
		"Fish":
			profile.aggression = maxf(0.12, profile.aggression - 0.04)
			profile.caution = maxf(0.08, profile.caution - 0.12)
			profile.bluff = minf(0.24, profile.bluff + 0.02)
		"Calling Station":
			profile.aggression = maxf(0.12, profile.aggression - 0.08)
			profile.caution = maxf(0.08, profile.caution - 0.18)
			profile.bluff = maxf(0.01, profile.bluff - 0.03)
		"Maniac":
			profile.aggression = minf(0.95, profile.aggression + 0.18)
			profile.caution = maxf(0.04, profile.caution - 0.14)
			profile.bluff = minf(0.42, profile.bluff + 0.1)
			profile.finalHandSpike = minf(0.32, profile.finalHandSpike + 0.06)
		"Shark":
			profile.aggression = minf(0.88, profile.aggression + 0.04)
			profile.caution = minf(0.88, profile.caution + 0.06)
			profile.patternPunish = minf(0.24, profile.patternPunish + 0.05)
		"Tilt King":
			profile.aggression = minf(0.98, profile.aggression + (0.22 if trailing else 0.1))
			profile.caution = maxf(0.02, profile.caution - 0.2)
			profile.bluff = minf(0.48, profile.bluff + 0.14)
	var biases: Array = {"preflop": [0.06,0.09,0.01], "flop": [0.04,0.05,0.02], "turn": [0.02,0.02,0.04], "river": [0.0,-0.04,0.08]}[table.street]
	var hand_factor: float = profile.finalHandSpike if table.handNumber == table.totalHands else 0.0
	var pressure: float = float(table.currentBet) / maxf(1.0, actor.stack + table.currentBet) if table.currentBet > 0 else 0.0
	var raise_chance: float = profile.aggression * 0.3 + hand_factor * 0.55 + biases[0] + minf(0.18, table.playerPattern.raiseCount * profile.patternPunish * 0.06) - pressure * 0.18
	var all_in_chance: float = profile.aggression * 0.16 + hand_factor * 0.62 + biases[2] + maxf(0, odds - 0.66) * 0.42 - pressure * 0.08
	var bluff_chance: float = profile.bluff * 0.4 + hand_factor * 0.18 + biases[1] - maxf(0, odds - 0.55) * 0.25
	var caution: float = profile.caution * 0.22 + pressure * 0.18
	var value_raise_shift: float = 0.0
	if profile.has("valueRaiseShift"):
		value_raise_shift = float(profile.valueRaiseShift) - hand_factor * 0.3 - minf(0.1, table.playerPattern.raiseCount * profile.patternPunish * 0.08)
	if profile.has("repeatRaiseCounter"):
		value_raise_shift -= minf(0.32, table.playerPattern.raiseCount * float(profile.repeatRaiseCounter))
	if table.currentBet == 0:
		if legal.get("allIn", false) and actor.stack <= table.tableDef.openBet * 2.5 and odds > 0.63 and random_value < 0.18 + all_in_chance:
			return "all-in"
		if legal.get("raise", false) and (odds > 0.62 - raise_chance * 0.3 + value_raise_shift or (odds < 0.42 and random_value < bluff_chance)):
			return "raise"
		return "check"
	if legal.get("allIn", false) and (table.handNumber == table.totalHands or actor.stack <= maxf(table.currentBet, table.tableDef.openBet) * 2.5) and odds > 0.68 and random_value < 0.16 + all_in_chance:
		return "all-in"
	if legal.get("raise", false) and (odds > 0.72 - raise_chance * 0.25 + value_raise_shift or (odds < 0.38 and random_value < bluff_chance * 0.85)):
		return "raise"
	if legal.get("call", false) and (odds > 0.24 + caution * 0.55 + float(profile.get("callOddsShift", 0.0)) or pressure < 0.18):
		return "call"
	return "check" if legal.get("check", false) else "fold"
