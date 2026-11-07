extends SceneTree
## Deterministic, real-time-rate capture of the actual four playable rigs.
const Catalog = preload("res://character_catalog.gd")
const Survivor = preload("res://reference_survivor.gd")
const Roster = preload("res://wasteland_roster_survivor.gd")
const FRAME_DIR := "/tmp/dustline-reference-motion-frames"
const FPS := 30
var views: Array[SubViewport] = []
var worlds: Array[Node3D] = []
var cameras: Array[Camera3D] = []
var labels: Array[Label] = []
var rigs: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	for column in 2:
		make_view(column)
	var frame_index := 0
	for id in 4:
		for column in 2:
			if rigs.size() > column:
				rigs[column].free()
			var rig: Node3D = Survivor.new() if id == 0 else Roster.new()
			if id > 0: rig.archetype = id
			worlds[column].add_child(rig)
			if rigs.size() > column: rigs[column] = rig
			else: rigs.append(rig)
			rig.reset_motion()
			labels[column].text = Catalog.get_info(id).name
		# Warm up the rig and shaders without changing the deterministic capture rate.
		for tick in 60: step(1.0/60.0)
		for tick in 4:
			await process_frame
			RenderingServer.force_draw(false)
		for tick in FPS * 3:
			step(1.0/60.0)
			step(1.0/60.0)
			await process_frame
			RenderingServer.force_draw(false)
			var sheet := Image.create(1280,720,false,Image.FORMAT_RGBA8)
			for column in 2:
				var tile := views[column].get_texture().get_image()
				tile.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(tile,Rect2i(0,0,640,720),Vector2i(column*640,0))
			sheet.save_png(FRAME_DIR+"/%04d.png" % frame_index)
			frame_index += 1
		print("MOTION CAPTURE: character %d, %d frames" % [id,frame_index])
	for view in views: view.queue_free()
	await process_frame
	print("REFERENCE MOTION CAPTURE: 360 frames at 30 fps")
	quit()

func step(delta: float) -> void:
	var heights: Array[float] = [0.0,0.0]
	var normals: Array[Vector3] = [Vector3.UP,Vector3.UP]
	var valid: Array[bool] = [true,true]
	for column in 2:
		var rig := rigs[column]
		var speed := 1.8 if column == 0 else 7.8
		rig.position.z -= speed * delta
		rig.set_ground_context(heights,normals,valid)
		rig.animate(delta,speed,true)
		var offset := Vector3(2.9,1.65,-4.1) if column == 0 else Vector3(4.7,1.5,-1.6)
		cameras[column].position = rig.position + offset
		cameras[column].look_at(rig.position+Vector3(0,.92,0))

func make_view(column: int) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(640,720)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	views.append(view)
	var display := TextureRect.new()
	display.position.x = column * 640
	display.size = Vector2(640,720)
	display.texture = view.get_texture()
	root.add_child(display)
	var world := Node3D.new()
	view.add_child(world)
	worlds.append(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("282723")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5cecf")
	env.ambient_light_energy = .6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = .25
	env.ssao_intensity = 1.2
	var environment := WorldEnvironment.new()
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_color = Color("ffe5c2")
	light.light_energy = 2.1
	light.shadow_enabled = true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,150,0)
	fill.light_color = Color("c4d8e0")
	fill.light_energy = .65
	world.add_child(fill)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(200,200)
	plane.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; varying vec3 world_pos; void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; } void fragment(){ vec2 line=abs(fract(world_pos.xz)-0.5); float grid=smoothstep(0.48,0.496,max(line.x,line.y)); ALBEDO=mix(vec3(0.20,0.19,0.16),vec3(0.29,0.27,0.22),grid*0.45); ROUGHNESS=0.94; }"
	plane.material_override = material
	world.add_child(plane)
	var camera := Camera3D.new()
	camera.fov = 32
	world.add_child(camera)
	camera.current = true
	cameras.append(camera)
	var font := load("res://assets/fonts/NotoSansSC.ttf")
	var title := Label.new()
	title.position = Vector2(30,24)
	title.text = "步行 · 自然摆臂与重心转移" if column == 0 else "奔跑 · 蹬地、屈膝与腾空"
	title.add_theme_font_override("font",font)
	title.add_theme_font_size_override("font_size",23)
	title.add_theme_color_override("font_color",Color("e9cd8f"))
	view.add_child(title)
	var label := Label.new()
	label.position = Vector2(30,660)
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",24)
	view.add_child(label)
	labels.append(label)
