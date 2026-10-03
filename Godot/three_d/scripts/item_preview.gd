extends TextureRect
## Static inventory render; refresh once instead of rendering every frame.
func _init(item_id: String) -> void:
	custom_minimum_size = Vector2(164,120)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kit: Node3D = preload("res://three_d/assets/interactive-props.glb").instantiate()
	if not kit.has_node(NodePath(item_id)):
		kit.free()
		kit = preload("res://three_d/assets/valuable-props.glb").instantiate()
	if not kit.has_node(NodePath(item_id)):
		kit.free()
		var symbol := Label.new()
		symbol.text = "◇"
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.add_theme_font_size_override("font_size",64)
		symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(symbol)
		return
	var item: Node3D = kit.get_node(NodePath(item_id))
	kit.remove_child(item)
	kit.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(164,120)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	texture = viewport.get_texture()
	var stage := Node3D.new()
	viewport.add_child(stage)
	stage.add_child(item)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in item.find_children("*","MeshInstance3D",true,false):
		var local := mesh.transform
		var parent := mesh.get_parent()
		while parent != item:
			local = parent.transform * local
			parent = parent.get_parent()
		var box: AABB = local * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var longest := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	item.position = -bounds.get_center()
	stage.scale = Vector3.ONE * (0.65/longest)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	camera.position = Vector3(-1.6,1.0,1.4)
	camera.rotation = Basis.looking_at(-camera.position,Vector3.UP).get_euler()
	camera.current = true
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("17201e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d4cbb8")
	settings.ambient_light_energy = 0.7
	# Metals need an environment to reflect, even with a solid card background.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("a7b9cc")
	sky_material.sky_horizon_color = Color("ddd6c7")
	sky_material.ground_bottom_color = Color("343a38")
	sky_material.ground_horizon_color = Color("b5aa92")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	settings.sky = sky
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.65,-0.5,0)
	light.light_color = Color("ffe1b3")
	light.light_energy = 1.5
	viewport.add_child(light)
func _ready() -> void:
	if texture == null: return
	await RenderingServer.frame_post_draw
	get_child(0).render_target_update_mode = SubViewport.UPDATE_DISABLED
