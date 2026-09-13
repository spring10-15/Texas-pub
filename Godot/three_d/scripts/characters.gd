extends RefCounted
## Character presentation observes public actions, never opponent hole cards.
var world: Node3D
var rooms := {}
func _init(owner: Node3D) -> void: world = owner
func actor(id: String, parent: Node3D, pos: Vector3, yaw := 0.0) -> Dictionary:
	var model: Node3D = load("res://three_d/assets/characters/" + id + ".glb").instantiate()
	model.name = id
	parent.add_child(model)
	model.position = pos
	model.rotation.y = yaw
	var animation: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var clips := {}
	for key in animation.get_animation_list():
		for label in ["idle", "bet", "win", "fold"]:
			if str(key).ends_with(label): clips[label] = key
	animation.get_animation(clips.idle).loop_mode = Animation.LOOP_LINEAR
	var entry := {"model":model,"player":animation,"clips":clips,"last":""}
	animation.animation_finished.connect(func(_name): animation.play(clips.idle))
	animation.play(clips.idle)
	return entry
func build(room: Node3D, definition: Dictionary) -> void:
	var people := {}
	for i in range(2):
		var id: String = definition.opponentIds[i]
		people[id] = actor(id, room, Vector3(-1.1 if i == 0 else 0.25, 0, -1.9))
	people.bartender = actor("bartender", room, Vector3(2.55, 0, .4), -PI / 2)
	for node in room.get_children():
		if str(node.get_meta("visual_role", "")).begins_with("Bartender"):
			node.hide()
	rooms[room.name] = people
func sync(room: Node3D, definition: Dictionary) -> void:
	var people: Dictionary = rooms[room.name]
	var current: Array = people.keys().filter(func(id): return id != "bartender")
	if current == definition.opponentIds: return
	for id in current:
		room.remove_child(people[id].model)
		people[id].model.queue_free()
		people.erase(id)
	for i in range(2):
		var id: String = definition.opponentIds[i]
		people[id] = actor(id, room, Vector3(-1.1 if i == 0 else 0.25, 0, -1.9))

func refresh(view: Dictionary) -> void:
	var people: Dictionary = rooms[world.ROOMS[world.current_room].node]
	for person in view.players.slice(1):
		var entry: Dictionary = people[person.id]
		var action: String = person.lastAction
		var clip := "fold" if action == "fold" else "bet"
		var token := str(view.handNumber) + ":" + action
		if view.status != "playing":
			clip = "win" if int(view.summary.get("awards", {}).get(person.id, 0)) > 0 else "fold"
			token = str(view.handNumber) + ":result"
		if entry.last != token:
			entry.last = token
			if not action.is_empty() or view.status != "playing": entry.player.play(entry.clips[clip], .12)
func deliver() -> void:
	var entry: Dictionary = rooms[world.ROOMS[world.current_room].node].bartender
	entry.player.play(entry.clips.bet, .12)
