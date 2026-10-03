extends PanelContainer
## Historical settlement receipt; never awards or restores inventory.
var displayed: Dictionary = {}
var rows := VBoxContainer.new()
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)
	hide()
func sync(run: RefCounted) -> void:
	visible = run.active and run.table == null and not run.last_table_result.is_empty()
	if not visible: return
	var result: Dictionary = run.last_table_result
	if displayed == result: return
	displayed = result.duplicate(true)
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = "最近牌桌结算 · %+d" % int(result.net)
	heading.add_theme_font_size_override("font_size", 20)
	rows.add_child(heading)
	var cards := HBoxContainer.new()
	rows.add_child(cards)
	if not str(result.get("reward", "")).is_empty():
		add_item(cards, result.reward, "奖励已入包" if result.get("reward_added", false) else "背包已满 · 未获得", run)
	if not str(result.get("collateral", "")).is_empty():
		add_item(cards, result.collateral, "抵押物已归还" if result.get("returned", false) else "抵押物已失去", run)
func add_item(parent: Control, item: String, status: String, run: RefCounted) -> void:
	var card := VBoxContainer.new()
	card.set_meta("settlement_item", item)
	card.set_meta("settlement_status", status)
	parent.add_child(card)
	var title := Label.new()
	title.text = status + "\n" + run.item_name(item)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	card.add_child(preload("res://three_d/scripts/item_preview.gd").new(item))
