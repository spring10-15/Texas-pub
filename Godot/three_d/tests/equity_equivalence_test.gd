extends SceneTree
const Poker = preload("res://three_d/rules/poker.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
# Frozen equity algorithm before score-only evaluation and completed-board caching.
func reference(hole: Array, board: Array, opponents: int, seed_value: int, trials := 85) -> float:
	var known := hole + board
	var remaining := Poker.create_deck().filter(func(card): return not known.has(card))
	var score := 0.0
	for trial in range(trials):
		var deck := Poker.shuffle_deck(remaining, Poker.DeterministicRng.new(seed_value + trial * 31 + opponents * 17))
		var community := board.duplicate(true)
		while community.size() < 5: community.append(deck.pop_back())
		var player_hand := Poker.evaluate_best_hand(hole + community)
		var result := 1.0
		var tied := 1
		for i in range(opponents):
			var opponent_hand := Poker.evaluate_best_hand([deck.pop_back(),deck.pop_back()] + community)
			var comparison := Poker.compare_hands(player_hand,opponent_hand)
			if comparison < 0:
				result = 0.0
				break
			if comparison == 0: tied += 1
		score += result / tied
	return score / trials
func _initialize() -> void:
	var cases := 0
	for seed_value in [1,41,301,2147483646]:
		var deck := Poker.shuffle_deck(Poker.create_deck(),Poker.DeterministicRng.new(seed_value))
		for size in [0,3,4,5]:
			for opponents in [1,2]:
				var hole: Array = deck.slice(0,2)
				var board: Array = deck.slice(2,2+size)
				var before := [hole.duplicate(true),board.duplicate(true)]
				verify(Opponent.estimate_odds(hole,board,opponents,seed_value) == reference(hole,board,opponents,seed_value), "Exact equity parity: %d/%d/%d" % [seed_value,size,opponents])
				verify([hole,board] == before,"Equity leaves caller cards unchanged")
				cases += 1
	var royal := [{"rank":10,"suit":"S"},{"rank":11,"suit":"S"},{"rank":12,"suit":"S"},{"rank":13,"suit":"S"},{"rank":14,"suit":"S"}]
	var hole := [{"rank":2,"suit":"H"},{"rank":3,"suit":"D"}]
	for opponents in [1,2]:
		verify(Opponent.estimate_odds(hole,royal,opponents,41) == reference(hole,royal,opponents,41), "Board-only tied equity preserved")
		cases += 1
	print("EQUITY_EQUIVALENCE cases=",cases," checks=",checks," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
