extends SceneTree
const Poker = preload("res://three_d/rules/poker.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
# Previous best-hand selection, using the independently exposed five-card result.
func reference(cards: Array) -> Dictionary:
	if cards.size() < 5:
		return {"rank":-1,"values":[],"name":"Incomplete","cards":cards.duplicate(true)}
	var best := {}
	for a in range(cards.size()-4):
		for b in range(a+1,cards.size()-3):
			for c in range(b+1,cards.size()-2):
				for d in range(c+1,cards.size()-1):
					for e in range(d+1,cards.size()):
						var hand: Dictionary = Poker.evaluate_five([cards[a],cards[b],cards[c],cards[d],cards[e]])
						if best.is_empty() or Poker.compare_hands(hand,best)>0: best=hand
	return best
func _initialize() -> void:
	var cases: Array = []
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/tests/poker-fixtures.json"))
	for fixture in fixtures.hands: cases.append(fixture.cards)
	for seed_value in range(100):
		var deck := Poker.shuffle_deck(Poker.create_deck(),Poker.DeterministicRng.new(seed_value+1))
		for size in [4,5,6,7]: cases.append(deck.slice(0,size))
	# Equal scores from different suit subsets must keep the original first winner.
	cases.append([{"rank":14,"suit":"S"},{"rank":14,"suit":"H"},{"rank":14,"suit":"D"},{"rank":13,"suit":"S"},{"rank":13,"suit":"H"},{"rank":13,"suit":"D"},{"rank":2,"suit":"C"}])
	for i in range(cases.size()):
		var cards: Array = cases[i]
		var before := cards.duplicate(true)
		var result := Poker.evaluate_best_hand(cards)
		verify(result == reference(cards), "Full result matches prior selection: " + str(i))
		verify(cards == before, "Evaluation leaves input unchanged: " + str(i))
		if not result.cards.is_empty(): result.cards[0].rank = -1
		verify(cards == before, "Returned cards do not alias source: " + str(i))
	print("HAND_EVALUATION_EQUIVALENCE cases=",cases.size()," checks=",checks," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
