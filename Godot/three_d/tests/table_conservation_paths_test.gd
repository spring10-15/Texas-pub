extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
var checks := 0
var failures: Array[String] = []
var actions := {}

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func conserved(game: RefCounted, initial: int) -> bool:
	var chips := int(game.state.pot) if game.state.status == "playing" else 0
	for player in game.state.players:
		if int(player.stack) < 0 or int(player.handContribution) < 0:
			return false
		chips += int(player.stack)
	return chips == initial

func play(definition: Dictionary, seed_value: int) -> void:
	var game := Table.new()
	game.start(definition, seed_value)
	var initial: int = int(definition.buyIn) * game.state.players.size()
	var choice := RandomNumberGenerator.new()
	choice.seed = seed_value * 1009 + int(definition.buyIn)
	var label := "%s/%d" % [definition.id, seed_value]
	verify(conserved(game, initial), label + " initial blinds conserve chips")
	var steps := 0
	while game.state.status != "finished" and steps < 250:
		steps += 1
		var accepted := false
		if game.state.status == "hand_over":
			accepted = game.next_hand(game.revision)
		elif game.state.currentActorId.is_empty():
			accepted = game.advance(game.revision)
		else:
			var actor: String = game.state.currentActorId
			var legal: Dictionary = game.legal_actions(actor)
			var options: Array[String] = []
			for kind in ["fold", "check", "call", "raise", "all-in"]:
				var key: String = "allIn" if kind == "all-in" else kind
				if legal.get(key, false):
					options.append(kind)
			if options.is_empty():
				verify(false, label + " has no legal action at step " + str(steps))
				break
			var kind: String = options[choice.randi_range(0, options.size() - 1)]
			var target := -1
			if kind == "raise" and choice.randi_range(0, 1) == 1:
				target = int(definition.openBet) if int(game.state.currentBet) == 0 else int(game.state.currentBet) + int(definition.raiseIncrement)
				if choice.randi_range(0, 1) == 1:
					target += int(definition.raiseIncrement)
			accepted = game.act(actor, kind, game.revision, target)
			actions[kind] = int(actions.get(kind, 0)) + 1
		verify(accepted, label + " transition accepted at step " + str(steps))
		if not accepted:
			break
		verify(conserved(game, initial), label + " chips conserved at step " + str(steps))
	verify(game.state.status == "finished", label + " reaches table conclusion")

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for definition in content.tables.values():
		for seed_value in range(1, 65):
			play(definition, seed_value)
	for kind in ["fold", "check", "call", "raise", "all-in"]:
		verify(int(actions.get(kind, 0)) > 0, kind + " exercised")
	print("TABLE_CONSERVATION_PATHS ", JSON.stringify({"checks": checks, "failed": failures.size(), "failures": failures, "tables": 256, "actions": actions}))
	quit(0 if failures.is_empty() else 1)
