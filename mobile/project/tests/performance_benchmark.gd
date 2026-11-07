extends SceneTree
## Run at a fixed output size with an isolated save. Wall-clock includes real GPU work.
var save_path := "/private/tmp/dustline-performance-%d.json" % OS.get_process_id()
var game: Node3D
var view: SubViewport

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled=false
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1440,900)
	root.position=Vector2i(50,60)
	root.grab_focus()
	view=SubViewport.new()
	view.size=Vector2i(1440,900)
	view.own_world_3d=true
	view.msaa_3d=ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	var started := Time.get_ticks_msec()
	game=load("res://main.tscn").instantiate()
	view.add_child(game)
	game.start_mode(0)
	game.damage_grace=99999
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1440,900)
	root.grab_focus()
	print("PERF startup_ms=",Time.get_ticks_msec()-started)
	for shot in [Vector3(0,0,25),Vector3(-69,0,-34),Vector3(73,0,-51)]:
		game.player.reset_for_round(game._ground(shot))
		for i in 60:
			await process_frame
			RenderingServer.force_draw(false)
		var samples: Array[float]=[]
		var draw_calls := 0.0
		var primitives := 0.0
		var physics_ms := 0.0
		var gpu_ms := 0.0
		var previous := Time.get_ticks_usec()
		for i in 120:
			game.player.camera_yaw+=.003
			await process_frame
			RenderingServer.force_draw(false)
			var now := Time.get_ticks_usec()
			samples.append((now-previous)/1000.0)
			previous=now
			draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
			gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
		var total := 0.0
		for sample in samples: total+=sample
		samples.sort()
		print("PERF ",JSON.stringify({"position":str(shot),"frame_ms":total/samples.size(),"p95_ms":samples[int(samples.size()*.95)],"fps":1000.0/(total/samples.size()),"draw_calls":draw_calls/samples.size(),"primitives":primitives/samples.size(),"physics_ms":physics_ms/samples.size(),"gpu_ms":gpu_ms/samples.size(),"output_size":str(view.size),"scale":view.scaling_3d_scale}))
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png("res://previews/performance-gameplay.png")
	game.free()
	for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	quit()
