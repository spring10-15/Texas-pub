extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const HUD = preload("res://three_d/scripts/table_hud.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var hud := HUD.new()
	root.add_child(hud)
	for table_id in content.tables:
		var t := Table.new()
		t.start(content.tables[table_id],7)
		hud.refresh(t.public_state())
		var due: int = maxi(0, int(t.state.currentBet)-int(t.state.players[0].currentBet))
		verify(hud.status.text.contains("跟注实付 %d" % due) and hud.status.text.contains("跟注后底池 %d" % (int(t.state.pot)+due)), "Call cost and resulting pot visible "+table_id)
		var discount: int = int(content.tables[table_id].get("firstAggressionDiscount", 0))
		var minimum: int = int(t.state.currentBet)+int(t.state.tableDef.raiseIncrement)
		verify(hud.raise_preview.visible and hud.raise_preview.text.contains("实付 %d" % (minimum-discount)),"Minimum cost "+table_id)
		hud.raise_amount.value = minimum+1
		verify(hud.raise_preview.text.contains("实付 %d" % (minimum+1-discount)),"Edited cost "+table_id)
		var paid: int = t.state.players[0].stack
		verify(t.act("player","raise",t.revision,int(hud.raise_amount.value)),"Raise accepted "+table_id)
		paid -= int(t.state.players[0].stack)
		verify(hud.raise_preview.text.contains("实付 %d" % paid),"Preview equals real debit "+table_id)
		hud.refresh(t.public_state())
		verify(not hud.raise_preview.visible,"Hidden on opponent turn "+table_id)
		var boundary := Table.new()
		boundary.start(content.tables[table_id],7)
		hud.refresh(boundary.public_state())
		hud.raise_amount.value = hud.raise_amount.max_value
		var before: int = boundary.state.players[0].stack
		verify(hud.raise_preview.text.begins_with("加注到" if discount else "转为全押"),"Maximum action type "+table_id)
		verify(boundary.act("player","raise",boundary.revision,int(hud.raise_amount.value)),"Maximum raise accepted "+table_id)
		verify(hud.raise_preview.text.contains("实付 %d" % (before-int(boundary.state.players[0].stack))),"Maximum preview debit "+table_id)
	var adjusted: Dictionary = content.tables["cargo-table"].duplicate(true)
	adjusted.firstAggressionDiscount = 5
	var configured := Table.new()
	configured.start(adjusted, 7)
	hud.refresh(configured.public_state())
	var configured_target: int = int(configured.state.currentBet) + int(adjusted.raiseIncrement)
	var configured_due: int = configured_target - int(configured.state.players[0].currentBet) - 5
	verify(hud.raise_preview.text.contains("实付 %d" % configured_due) and hud.raise_preview.text.contains("少付 5"), "Preview amount and reminder read configured discount")
	var configured_stack: int = configured.state.players[0].stack
	verify(configured.act("player", "raise", configured.revision, configured_target), "Configured raise accepted")
	verify(configured_stack - int(configured.state.players[0].stack) == configured_due and not configured.state.firstAggressionDiscountAvailable, "Configured discount charged once")
	var fresh := Table.new()
	fresh.start(content.tables["cargo-table"],7)
	hud.refresh(fresh.public_state())
	var short_view: Dictionary = fresh.public_state()
	short_view.players[0].stack = 5
	short_view.legal.call = false
	hud.refresh(short_view)
	verify(hud.status.text.contains("筹码仅 5") and hud.status.text.contains("全押或弃牌"), "Short stack sees affordable choices")
	hud.pregame(300,content.tables["cargo-table"])
	verify(not hud.raise_preview.visible,"Hidden before hand")
	if OS.get_cmdline_user_args().has("--capture"):
		hud.refresh(fresh.public_state())
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../output/3d/raise-preview.png")
	print("RAISE_PREVIEW checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
