extends SceneTree
## A deterministic contact sheet of the live survivor rig, with no gameplay input.
## Run graphically with --script res://tests/character_motion_preview.gd.

const Survivor = preload("res://reference_survivor.gd")
const TILE_SIZE := Vector2i(460, 540)
const PREVIEW_PATH := "res://previews/survivor-motion-sheet.png"
const POSES := [
	{"key":"walk", "label":"WALK / CONTACT", "speed":1.8, "phase":0.10, "height":0.0},
	{"key":"run", "label":"RUN / RECOVERY", "speed":7.8, "phase":0.30, "height":0.0},
	{"key":"turn", "label":"TURN / WEIGHT SHIFT", "speed":1.8, "phase":0.12, "height":0.0},
	{"key":"rise", "label":"JUMP / ASCENT", "speed":1.8, "phase":0.12, "height":0.38},
	{"key":"fall", "label":"JUMP / DESCENT", "speed":1.8, "phase":0.12, "height":0.24},
	{"key":"land", "label":"LAND / ABSORB IMPACT", "speed":0.0, "phase":0.12, "height":0.0}
]

var viewports: Array[SubViewport] = []

func _initialize() -> void:
	call_deferred("render_poses")

func render_poses() -> void:
	root.size=Vector2i(1380,1080)
	root.content_scale_size=Vector2i(1380,1080)
	DirAccess.make_dir_recursive_absolute("res://previews")
	for pose in POSES:
		var viewport := SubViewport.new()
		viewport.size=TILE_SIZE
		viewport.own_world_3d=true
		viewport.msaa_3d=Viewport.MSAA_4X
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewports.append(viewport)
		_build_scene(viewport,pose)
		var display := TextureRect.new()
		display.texture=viewport.get_texture()
		display.position=Vector2((viewports.size()-1)%3,(viewports.size()-1)/3)*Vector2(TILE_SIZE)
		display.size=Vector2(TILE_SIZE)
		root.add_child(display)
	# Wait for shader compilation and shadow/SSAO warm-up; pose clocks stay frozen.
	for frame in 24: await process_frame
	await RenderingServer.frame_post_draw
	var sheet := Image.create(TILE_SIZE.x*3,TILE_SIZE.y*2,false,Image.FORMAT_RGBA8)
	for i in viewports.size():
		var tile := viewports[i].get_texture().get_image()
		tile.convert(Image.FORMAT_RGBA8)
		tile.save_png("res://previews/survivor-motion-%s.png" % POSES[i].key)
		sheet.blit_rect(tile,Rect2i(Vector2i.ZERO,TILE_SIZE),Vector2i(i%3,i/3)*TILE_SIZE)
	var error := sheet.save_png(PREVIEW_PATH)
	if error!=OK:
		push_error("Failed to save motion contact sheet: %s" % error_string(error))
		quit(1)
		return
	print("CHARACTER MOTION PREVIEW SAVED: "+PREVIEW_PATH)
	quit()

func _build_scene(viewport: SubViewport, pose: Dictionary) -> void:
	var world := Node3D.new()
	viewport.add_child(world)
	var rig=Survivor.new()
	world.add_child(rig)
	_pose_rig(rig,pose)
	rig.position.y=pose.height
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("1c2426")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b5c4ca")
	environment.ambient_light_energy=.5
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled=true
	environment.ssao_radius=.3
	environment.ssao_intensity=1.25
	var env := WorldEnvironment.new()
	env.environment=environment
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-38,-28,0)
	light.light_color=Color("ffdfbc")
	light.light_energy=2.2
	light.shadow_enabled=true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-18,145,0)
	fill.light_color=Color("b7d5e1")
	fill.light_energy=.8
	world.add_child(fill)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size=Vector2(40,40)
	floor_node.mesh=floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color=Color("353c3a")
	floor_mat.roughness=.95
	floor_node.material_override=floor_mat
	world.add_child(floor_node)
	var camera := Camera3D.new()
	camera.fov=36
	world.add_child(camera)
	camera.position=Vector3(2.4,1.65,-3.55)
	camera.look_at(Vector3(0,1.11,0))
	camera.current=true
	var title := Label.new()
	title.text=pose.label
	title.position=Vector2(20,18)
	title.add_theme_font_size_override("font_size",18)
	title.add_theme_color_override("font_color",Color("e2d4bb"))
	viewport.add_child(title)
	var detail := Label.new()
	detail.text="LIVE RIG · FIXED POSE · SAME CAMERA"
	detail.position=Vector2(20,TILE_SIZE.y-32)
	detail.add_theme_font_size_override("font_size",11)
	detail.add_theme_color_override("font_color",Color("a7b6b5"))
	viewport.add_child(detail)

func _pose_rig(rig: Node3D, pose: Dictionary) -> void:
	rig.reset_motion()
	for frame in 90: rig.animate(1.0/60.0,pose.speed,true)
	if pose.key=="turn":
		rig.set_motion_context(Vector3(-7.0,0.0,-4.0),4.0)
		for frame in 25: rig.animate(1.0/60.0,pose.speed,true)
	if pose.key in ["rise","fall","land"]:
		var velocity := 5.4 if pose.key=="rise" else -5.4
		for frame in 18: rig.animate(1.0/60.0,pose.speed,false,velocity)
		if pose.key=="land": rig.animate(1.0/60.0,0.0,true,0.0)
	else:
		rig.phase=TAU*pose.phase
		rig.animate(0.0,pose.speed,true)
