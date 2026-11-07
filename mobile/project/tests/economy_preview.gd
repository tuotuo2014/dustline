extends SceneTree
var game: Node3D
var view: SubViewport
var save_path := "/tmp/dustline-economy-preview-%d.json" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://previews/"+name+".png")
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	root.size=Vector2i(1200,760)
	view=SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game=load("res://main.tscn").instantiate()
	var run_data: Dictionary=game.profile.begin_expedition()
	game.profile.finish_expedition(run_data.id,true,1350,0)
	game.profile.purchase("repulsor")
	game.profile.purchase("armor")
	game.profile.purchase("field_kit")
	game.profile.purchase("ammo_pack")
	game.profile.upgrade(0)
	view.add_child(game)
	game.hud.show_camp()
	await capture("economy-camp-shop")
	view.size=Vector2i(1050,760)
	await capture("economy-camp-compact")
	view.size=Vector2i(1600,1000)
	game.open_menu()
	await capture("economy-character-menu")
	game.start_mode(1)
	game.damage_grace=9999
	game.player.global_position=game._ground(Vector3(0,0,60))
	game.player.velocity=Vector3.ZERO
	game.player.camera_yaw=0
	game.player.camera_pitch=-.19
	game.player.camera_distance=5
	game.player.get_node("Body").rotation.y=0
	game.player._update_camera()
	for i in 5: await physics_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.expedition.bag_items=4
	game.expedition.bag_value=350
	game.mutants[0].global_position=game._ground(Vector3(0,0,49))
	game.mutants[1].global_position=game._ground(Vector3(3,0,47))
	game.mutants[2].global_position=game._ground(Vector3(-3,0,46))
	for wolf in game.mutants: wolf._set_state("chase")
	for i in 3: await physics_frame
	game.arsenal.fire()
	game._update_hud()
	await capture("economy-field-firearm")
	game._finish(true,"成功撤离","你已经带着物资安全离开荒野。")
	await capture("economy-extraction-result")
	game.queue_free()
	for i in 3: await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	print("ECONOMY GPU PREVIEW: PASS")
	quit()
