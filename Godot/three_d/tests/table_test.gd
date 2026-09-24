extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
var count := 0
var failures: Array[String] = []
var content: Dictionary
func verify(ok: bool, title: String) -> void:
	count += 1
	if not ok:
		failures.append(title)
		push_error(title)
func fresh(seed_value := 1) -> RefCounted:
	var game := Table.new()
	game.start(content.tables["cargo-table"], seed_value)
	return game
func act(game: RefCounted, kind: String) -> void:
	verify(game.act(game.state.currentActorId, kind, game.revision), "Action accepted " + kind)
func total(game: RefCounted) -> int:
	var amount := int(game.state.pot) if game.state.status == "playing" else 0
	for player in game.state.players:
		amount += player.stack
	return amount
func play_to_end(game: RefCounted, strategy: String) -> void:
	var iterations := 0
	while game.state.status != "finished" and iterations < 150:
		iterations += 1
		if game.state.status == "hand_over":
			game.next_hand(game.revision)
		elif game.state.currentActorId == "":
			game.advance(game.revision)
		else:
			var legal: Dictionary = game.legal_actions(game.state.currentActorId)
			var kind := "check" if legal.get("check", false) else "call"
			if strategy == "all-in" or not legal.get(kind, false):
				kind = "all-in"
			verify(game.act(game.state.currentActorId, kind, game.revision), "Autoplay action")
		verify(total(game) == 180, "Chips conserved after transition")
	verify(game.state.status == "finished", "Table reaches terminal state")

func _initialize() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var game := fresh()
	verify(game.state.pot == 30 and game.state.players[1].stack == 50 and game.state.players[2].stack == 40, "Blinds post 10 and 20")
	verify(game.state.currentActorId == "player", "Dealer acts first in three-handed preflop")
	verify(game.state.players.all(func(p): return p.holeCards.size() == 2), "All starters receive two cards")
	var snapshot := JSON.stringify(game.state)
	verify(not game.act("ledger-clerk", "fold", game.revision), "Out-of-turn action rejected")
	verify(not game.act("player", "check", game.revision), "Check facing bet rejected")
	verify(not game.act("player", "raise", game.revision, 21), "Under-minimum raise rejected")
	verify(JSON.stringify(game.state) == snapshot, "Rejected actions do not mutate state")
	var old_revision: int = game.revision
	act(game, "call")
	verify(not game.act(game.state.currentActorId, "fold", old_revision), "Stale command rejected")
	act(game, "call")
	act(game, "check")
	verify(game.state.currentActorId == "", "Betting round waits for reveal")
	verify(game.advance(game.revision), "Reveal advances street")
	verify(game.state.street == "flop" and game.state.community.size() == 3, "Flop has three cards")
	verify(game.state.currentActorId == "dock-braggart", "Postflop action starts left of dealer")
	var view: Dictionary = game.public_state()
	verify(not view.has("deck") and view.players[1].holeCards.is_empty() and view.players[2].holeCards.is_empty(), "Public state hides deck and opponent hole cards")
	play_to_end(game, "call")
	verify(not game.advance(game.revision) and not game.next_hand(game.revision), "Terminal state cannot settle again")
	verify(total(game) == 180, "Repeated settlement cannot create chips")
	game = fresh()
	act(game, "raise")
	verify(game.state.players[0].stack == 30 and game.state.currentBet == 40 and not game.state.firstAggressionDiscountAvailable, "Cargo first raise discount charged once")
	verify(game.state.toAct == ["dock-braggart", "ledger-clerk"], "Raise reopens opponents only")
	play_to_end(game, "all-in")
	game = fresh()
	act(game, "all-in")
	verify(not game.state.firstAggressionDiscountAvailable and game.state.currentBet == 60, "Opening all-in consumes first aggression discount")
	game = fresh()
	act(game, "fold")
	act(game, "fold")
	verify(game.state.status == "hand_over", "Fold victory does not discard the second hand")
	verify(game.next_hand(game.revision), "Second hand starts")
	verify(game.state.handNumber == 2 and game.state.players.all(func(p): return not p.folded), "Folded funded seats return next hand")
	# A player posting the last chip as a blind must still receive hole cards.
	game = fresh()
	game.state.players[1].stack = 10
	game.state.players[0].stack = 60
	game.state.players[2].stack = 110
	game.start_hand()
	verify(game.state.players[1].stack == 0 and game.state.players[1].holeCards.size() == 2 and not game.state.players[1].folded, "All-in blind receives cards and remains eligible")
	play_to_end(game, "all-in")
	game = fresh()
	game.state.players[1].stack = 0
	game.state.players[0].stack = 90
	game.state.players[2].stack = 90
	game.start_hand()
	verify(game.state.smallBlindSeat == 0 and game.state.bigBlindSeat == 2 and game.state.currentActorId == "player", "Heads-up dealer posts small blind and acts first")
	play_to_end(game, "call")
	for seed_value in range(1, 51):
		play_to_end(fresh(seed_value), "all-in" if seed_value % 2 == 0 else "call")
	# AI decisions must not change when another seat's concealed cards change.
	game = fresh(812)
	act(game, "call")
	var actor: Dictionary = game.find_player("dock-braggart")
	var legal: Dictionary = game.legal_actions(actor.id)
	var definition: Dictionary = content.opponents[actor.id]
	var choice := Opponent.choose(game.state, actor, legal, definition, 0.31)
	game.state.players[0].holeCards = [{"rank": 14, "suit": "S"}, {"rank": 14, "suit": "H"}]
	verify(Opponent.choose(game.state, actor, legal, definition, 0.31) == choice, "AI cannot inspect opponent private cards")
	game.state.players[0].folded = true
	var concealed_fold_choice := Opponent.choose(game.state, actor, legal, definition, 0.31)
	game.state.players[0].holeCards = [{"rank": 2, "suit": "C"}, {"rank": 3, "suit": "C"}]
	verify(Opponent.choose(game.state, actor, legal, definition, 0.31) == concealed_fold_choice, "AI cannot inspect concealed folded cards")
	verify(legal.get("allIn" if choice == "all-in" else choice, false), "AI chooses a legal action")
	var report := {"checks": count, "failed": failures.size(), "failures": failures}
	var file := FileAccess.open("res://../output/3d/table-rules.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("TABLE_RULES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
