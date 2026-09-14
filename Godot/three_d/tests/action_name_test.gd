extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for id in content.tables:
		for action in ["allIn","","unknown","ALL-IN"]:
			var t := Table.new()
			t.start(content.tables[id],7)
			var before := Checkpoint.capture(t)
			verify(not t.act(t.state.currentActorId,action,t.revision) and Checkpoint.capture(t) == before,id+" rejects "+action)
		var t := Table.new()
		t.start(content.tables[id],7)
		var actor: String = t.state.currentActorId
		var stack: int = t.find_player(actor).stack
		var pot: int = t.state.pot
		verify(t.act(actor,"all-in",t.revision) and t.find_player(actor).stack == 0 and t.state.pot == pot+stack,id+" canonical all-in commits chips")
	print("ACTION_NAMES checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
