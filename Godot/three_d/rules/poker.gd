extends RefCounted
## Pure rules port from src/poker.js. Card format remains {rank: int, suit: String}.
const HAND_NAMES := ["High Card", "Pair", "Two Pair", "Three of a Kind", "Straight", "Flush", "Full House", "Four of a Kind", "Straight Flush"]

class DeterministicRng:
	extends RefCounted
	var value: int
	func _init(seed_value: int) -> void:
		value = (seed_value & 0xffffffff) + 0x6d2b79f5
	func multiply32(a: int, b: int) -> int:
		return ((a & 65535) * (b & 65535) + (((a >> 16) * (b & 65535) + (a & 65535) * (b >> 16)) << 16)) & 0xffffffff
	func next() -> float:
		value = (value + 0x6d2b79f5) & 0xffffffff
		var t := multiply32(value ^ (value >> 15), 1 | value)
		t = (t ^ (t + multiply32(t ^ (t >> 7), 61 | t))) & 0xffffffff
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

static func create_deck() -> Array:
	var deck: Array = []
	for suit in ["S", "H", "D", "C"]:
		for rank in range(2, 15):
			deck.append({"rank": rank, "suit": suit})
	return deck

static func shuffle_deck(deck: Array, rng: DeterministicRng) -> Array:
	var result := deck.duplicate(true)
	for i in range(result.size() - 1, 0, -1):
		var j := int(floor(rng.next() * (i + 1)))
		var temporary: Dictionary = result[i]
		result[i] = result[j]
		result[j] = temporary
	return result

static func compare_hands(a: Dictionary, b: Dictionary) -> int:
	if a.rank != b.rank:
		return int(a.rank) - int(b.rank)
	for i in range(maxi(a.values.size(), b.values.size())):
		var left: int = a.values[i] if i < a.values.size() else 0
		var right: int = b.values[i] if i < b.values.size() else 0
		if left != right:
			return left - right
	return 0

static func evaluate_best_hand(cards: Array) -> Dictionary:
	if cards.size() < 5:
		return {"rank": -1, "values": [], "name": "Incomplete", "cards": cards.duplicate(true)}
	var best: Dictionary = {}
	var best_cards: Array = []
	# Hold'em supplies at most seven cards; explicit 5-card combinations avoid mutation.
	for a in range(cards.size() - 4):
		for b in range(a + 1, cards.size() - 3):
			for c in range(b + 1, cards.size() - 2):
				for d in range(c + 1, cards.size() - 1):
					for e in range(d + 1, cards.size()):
						var candidate := [cards[a], cards[b], cards[c], cards[d], cards[e]]
						var hand := evaluate_five_score(candidate)
						if best.is_empty() or compare_hands(hand, best) > 0:
							best = hand
							best_cards = candidate
	return make_hand(best.rank, best.values, best_cards)

static func evaluate_five(cards: Array) -> Dictionary:
	var score := evaluate_five_score(cards)
	return make_hand(score.rank, score.values, cards)

static func evaluate_five_score(cards: Array) -> Dictionary:
	var ranks: Array = []
	var counts := {}
	var flush := true
	for card in cards:
		var rank := int(card.rank)
		ranks.append(rank)
		counts[rank] = counts.get(rank, 0) + 1
		flush = flush and card.suit == cards[0].suit
	ranks.sort()
	ranks.reverse()
	var unique: Array = counts.keys()
	unique.sort()
	unique.reverse()
	if unique.has(14):
		unique.append(1)
	var run := 1
	var straight := 0
	for i in range(unique.size() - 1):
		if unique[i] - 1 == unique[i + 1]:
			run += 1
			if run >= 5:
				straight = unique[i - 3]
				break
		else:
			run = 1
	var groups: Array = counts.keys()
	groups.sort_custom(func(a, b): return counts[a] > counts[b] if counts[a] != counts[b] else a > b)
	if flush and straight:
		return {"rank": 8, "values": [straight]}
	if counts[groups[0]] == 4:
		return {"rank": 7, "values": [groups[0], groups[1]]}
	if counts[groups[0]] == 3 and counts[groups[1]] == 2:
		return {"rank": 6, "values": groups}
	if flush:
		return {"rank": 5, "values": ranks}
	if straight:
		return {"rank": 4, "values": [straight]}
	if counts[groups[0]] == 3:
		return {"rank": 3, "values": groups}
	if counts[groups[0]] == 2 and counts[groups[1]] == 2:
		return {"rank": 2, "values": groups}
	if counts[groups[0]] == 2:
		return {"rank": 1, "values": groups}
	return {"rank": 0, "values": ranks}

static func make_hand(rank: int, values: Array, cards: Array) -> Dictionary:
	var ordered := cards.duplicate(true)
	ordered.sort_custom(func(a, b): return a.rank > b.rank)
	return {"rank": rank, "values": values.duplicate(), "name": HAND_NAMES[rank], "cards": ordered}

static func build_pots(players: Array) -> Array:
	var levels: Array = []
	for player in players:
		var amount := int(player.handContribution)
		if amount > 0 and not levels.has(amount):
			levels.append(amount)
	levels.sort()
	var pots: Array = []
	var previous := 0
	for level in levels:
		var contributors := 0
		var eligible: Array = []
		for player in players:
			if player.handContribution >= level:
				contributors += 1
				if not player.folded:
					eligible.append(player.id)
		pots.append({"amount": (level - previous) * contributors, "eligibleIds": eligible})
		previous = level
	return pots

static func settle_pots(players: Array, board: Array) -> Dictionary:
	var hands := {}
	var awards := {}
	var seats := {}
	for player in players:
		awards[player.id] = 0
		seats[player.id] = player.seatIndex
		if not player.folded:
			hands[player.id] = evaluate_best_hand(player.holeCards + board)
	var pots := build_pots(players)
	for pot in pots:
		var winners: Array = []
		for id in pot.eligibleIds:
			if winners.is_empty() or compare_hands(hands[id], hands[winners[0]]) > 0:
				winners = [id]
			elif compare_hands(hands[id], hands[winners[0]]) == 0:
				winners.append(id)
		winners.sort_custom(func(a, b): return seats[a] < seats[b])
		if not winners.is_empty():
			@warning_ignore("integer_division")
			var split: int = int(pot.amount) / winners.size()
			var remainder: int = int(pot.amount) % winners.size()
			for i in range(winners.size()):
				awards[winners[i]] += split + (remainder if i == 0 else 0)
		pot["winnerIds"] = winners
	return {"awards": awards, "pots": pots, "hands": hands}
