extends CharacterBody3D
signal interaction_requested(target: Area3D)
signal focus_changed(target: Area3D)
signal pause_requested

const MOVE_SPEED := 2.5
const REACH := 2.0
const LOOK_SENSITIVITY := 0.002
const LOOK_PITCH_LIMIT := 1.25
var camera: Camera3D
var ray: RayCast3D
var controls_enabled := true
var focused: Area3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.7
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 75
	camera.current = true
	camera.near = 0.04
	add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = 3
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	camera.add_child(ray)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_SENSITIVITY, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		update_focus()
		if is_instance_valid(focused):
			interaction_requested.emit(focused)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled else Vector2.ZERO
	var direction := transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = direction.x * MOVE_SPEED
	velocity.z = direction.z * MOVE_SPEED
	move_and_slide()
	update_focus()

func update_focus() -> void:
	ray.force_raycast_update()
	var hit := ray.get_collider() if controls_enabled else null
	var next: Area3D = hit as Area3D if hit is Area3D and hit.has_method("prompt") else null
	if next != focused:
		focused = next
		focus_changed.emit(focused)

func can_interact(target: Area3D) -> bool:
	update_focus()
	return controls_enabled and is_instance_valid(target) and target == focused and target.enabled
