extends SceneTree
const Poker = preload("res://three_d/rules/poker.gd")
var checks := 0
var failures: Array[String] = []
var ranks_seen := {}
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func compare(cards: Array, label: String) -> void:
	var before := cards.duplicate(true)
	var expected := Poker.evaluate_best_hand(cards)
	var actual := Poker.score_seven(cards)
	verify(actual.rank == expected.rank and actual.values == expected.values, "Seven-card score equals exhaustive selection: " + label)
	verify(cards == before, "Score preserves input: " + label)
	ranks_seen[expected.rank] = true
func _initialize() -> void:
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/tests/poker-fixtures.json"))
	for i in range(fixtures.hands.size()):
		if fixtures.hands[i].cards.size() == 7: compare(fixtures.hands[i].cards,"fixture " + str(i))
	for seed_value in range(10000):
		var deck := Poker.shuffle_deck(Poker.create_deck(),Poker.DeterministicRng.new(seed_value+1))
		compare(deck.slice(0,7),"seed " + str(seed_value))
	# All categories must appear in this corpus, including rare straight flushes.
	verify(ranks_seen.size() == 9,"All nine complete hand categories compared")
	print("SEVEN_CARD_SCORE checks=",checks," ranks=",ranks_seen.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
