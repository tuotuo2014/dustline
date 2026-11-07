extends SceneTree
var views: Array[SubViewport]=[]
var cameras: Array[Camera3D]=[]
var rigs: Array[Node3D]=[]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,760)
	root.content_scale_size=Vector2i(1200,760)
	for id in 4:
		var view := SubViewport.new()
		view.size=Vector2i(448,840)
		view.own_world_3d=true
		view.msaa_3d=Viewport.MSAA_4X
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		views.append(view)
		var rig: Node3D=preload("res://reference_survivor.gd").new() if id==0 else preload("res://wasteland_roster_survivor.gd").new()
		if id>0: rig.archetype=id
		view.add_child(rig)
		rigs.append(rig)
		var env := Environment.new()
		env.background_mode=Environment.BG_COLOR
		env.background_color=Color("252e31")
		env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color=Color("c1cbd1")
		env.ambient_light_energy=.55
		env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
		env.ssao_enabled=true
		env.ssao_radius=.10
		env.ssao_intensity=1.2
		env.glow_enabled=true
		env.glow_intensity=.25
		var we := WorldEnvironment.new()
		we.environment=env
		view.add_child(we)
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-30,-28,0)
		light.light_color=Color("ffdfbd")
		light.light_energy=1.75
		light.shadow_enabled=true
		view.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees=Vector3(-14,145,0)
		fill.light_color=Color("a0becf")
		fill.light_energy=.9
		view.add_child(fill)
		var camera := Camera3D.new()
		camera.fov=29
		view.add_child(camera)
		camera.position=Vector3(.22,1.16,-3.85)
		camera.look_at(Vector3(0,.91,0))
		cameras.append(camera)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	_save("res://previews/roster-lineup.png")
	for i in 4:
		cameras[i].fov=25
		cameras[i].position=Vector3(.06,1.735,-.97)
		cameras[i].look_at(Vector3(0,1.703,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	_save("res://previews/roster-faces.png")
	for i in 4:
		cameras[i].fov=30
		cameras[i].position=Vector3(.9,1.20,3.4)
		cameras[i].look_at(Vector3(0,.95,0))
		rigs[i].animate(.016,7.8,true,0)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	_save("res://previews/roster-backs.png")
	for i in 4:
		cameras[i].fov=30
		cameras[i].position=Vector3(.9,1.25,-3.6)
		cameras[i].look_at(Vector3(0,.95,0))
		for frame in 74:
			rigs[i].set_motion_context(Vector3(0,0,-1),.2)
			rigs[i].animate(1.0/60.0,7.8,true,0)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	_save("res://previews/roster-running.png")
	print("ROSTER ACTUAL GPU PREVIEWS: PASS")
	quit()
func _save(path: String) -> void:
	var composite := Image.create(448*4,840,false,Image.FORMAT_RGBA8)
	for i in views.size():
		var shot := views[i].get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		composite.blit_rect(shot,Rect2i(0,0,448,840),Vector2i(i*448,0))
	composite.save_png(path)
