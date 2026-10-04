extends RefCounted
## Derived tabletop visual; the Run alone owns collateral and its settlement.
var world: Node3D
var prop: Node3D
var item_id := ""
func _init(owner: Node3D) -> void: world=owner
func sync() -> void:
	var desired: String=world.run_game.collateral if world.table_game!=null else ""
	var room: Node3D=world.table_target.get_parent()
	if desired==item_id and (desired.is_empty() or (is_instance_valid(prop) and prop.get_parent()==room)): return
	if is_instance_valid(prop): prop.free()
	item_id=desired
	if desired.is_empty(): return
	var kit: Node3D=preload("res://three_d/assets/valuable-props.glb").instantiate()
	prop=kit.get_node(NodePath(desired))
	kit.remove_child(prop)
	kit.free()
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
		var box: AABB=mesh.transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
	prop.position=Vector3(0.28,0.857-bounds.position.y,-0.42)
	prop.set_meta("pledged_item",desired)
	room.add_child(prop)
	var label := Label3D.new()
	label.text="抵押物 · "+world.run_game.item_name(desired)
	label.font_size=32
	label.pixel_size=0.0015
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.position=Vector3(0,bounds.size.y+0.065,0)
	prop.add_child(label)
