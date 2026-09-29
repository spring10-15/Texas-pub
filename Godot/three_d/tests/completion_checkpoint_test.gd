extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",0)
	r.completed.append("cargo-table")
	r.search_index = 2
	r.public_exit = true
	verify(r.transfer_venue("rooftop-club",r.revision),"Initial transfer fixture accepted")
	r.discover_exit()
	var clean := Checkpoint.capture(r)
	var loaded: RefCounted = Checkpoint.restore(clean,content)
	verify(loaded != null and not loaded.transfer_quote("neon-poker-club").reason.is_empty(),"Arrival requires another completed table")
	for invalid in [["cargo-table","cargo-table"],["cargo-table","unknown-table"]]:
		var bad := clean.duplicate(true)
		bad.completed.assign(invalid)
		verify(Checkpoint.restore(bad,content)==null,"Invalid completion cannot count as another table: "+str(invalid))
	for invalid in [["ledger-cellar"], ["cargo-table", "mirror-hall"], ["cargo-table", "ledger-cellar", "embers-table"]]:
		var bad := clean.duplicate(true)
		bad.completed.assign(invalid)
		verify(Checkpoint.restore(bad,content)==null,"Linear completion cannot skip prerequisite: "+str(invalid))
	var fork := clean.duplicate(true)
	fork.variant_plan.room_layout = "fork"
	fork.completed.assign(["cargo-table", "mirror-hall", "ledger-cellar", "embers-table"])
	verify(Checkpoint.restore(fork,content)!=null,"Fork accepts either middle-table order")
	fork.completed.assign(["cargo-table", "embers-table"])
	verify(Checkpoint.restore(fork,content)==null,"Fork rejects embers before both middle tables")
	var playing := Run.new(content)
	playing.start(playing.revision,"smoky-den",0)
	verify(playing.enter_table(7,playing.revision)!=null,"Build active table snapshot")
	var active_save := Checkpoint.capture(playing)
	active_save.completed.append("cargo-table")
	verify(Checkpoint.restore(active_save,content)==null,"Active table cannot already be completed")
	playing.table = null
	playing.completed.assign(["cargo-table", "ledger-cellar"])
	verify(playing.enter_table(7,playing.revision,"mirror-hall")!=null,"Build unlocked mirror snapshot")
	active_save = Checkpoint.capture(playing)
	active_save.completed.assign(["cargo-table"])
	verify(Checkpoint.restore(active_save,content)==null,"Active table cannot bypass its room prerequisite")
	verify(Checkpoint.capture(r)==clean,"Rejected snapshots leave original run intact")
	for count in range(1,5):
		var saved := clean.duplicate(true)
		saved.completed.assign(Run.Variants.TABLES.slice(0,count))
		saved.search_index = count+1
		verify(Checkpoint.restore(saved,content)!=null,"Valid completion prefixes remain loadable")
	print("COMPLETION_CHECKPOINT checks=",checks," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
