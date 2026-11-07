extends SceneTree
## Real menu, tutorial, aiming, and modal layout in phone viewports.
var game: Node3D
var hud: CanvasLayer
var failures: Array[String]=[]
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks+=1
	if ok: print("PASS: "+caption)
	else:
		failures.append(caption)
		push_error("FAIL: "+caption)
func frames(count: int=5) -> void:
	for i in count: await process_frame
func touch(point: Vector2, down: bool, finger: int=0) -> void:
	var event := InputEventScreenTouch.new()
	event.index=finger
	event.position=point
	event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH","/tmp/dustline-mobile-ui-%d.json"%OS.get_process_id())
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	hud=game.hud
	await frames(12)
	for extent in [Vector2i(1280,720),Vector2i(1560,720)]:
		root.size=extent
		root.content_scale_size=extent
		hud._layout()
		await frames(8)
		check(hud._menu_panel.size.x<=extent.x-24,"Menu fits phone width %d"%extent.x)
		check(hud._modal_scrolls[0].get_v_scroll_bar().visible or hud._menu_panel.size.y<=extent.y-24,"Tall mobile menu has vertical scrolling")
		check(hud._mode_buttons[0].size.y>=48 and hud._character_buttons[0].size.y>=48,"Start and character choices have finger-sized hit areas")
		check(hud._region_picker.size.y>=48,"Map selector is touch-sized")
	# Verify actual touchscreen character preview input without changing the desktop original.
	var start_yaw: float=hud._preview_yaw
	var finger := InputEventScreenTouch.new()
	finger.index=3
	finger.pressed=true
	hud._preview_input(finger)
	var drag := InputEventScreenDrag.new()
	drag.index=3
	drag.relative=Vector2(34,18)
	hud._preview_input(drag)
	check(hud._preview_yaw>start_yaw and hud._preview_distance>1.85,"Touch dragging rotates and zooms the character preview")
	finger.pressed=false
	hud._preview_input(finger)
	# A real touch is translated by Godot into a UI activation; no direct gameplay call.
	hud._modal_scrolls[0].scroll_vertical=0
	await frames(8)
	var start_point: Vector2=hud._mode_buttons[0].get_global_rect().get_center()
	touch(start_point,true)
	await frames(2)
	touch(start_point,false)
	await frames(12)
	check(game.active and hud._hud.visible,"A touchscreen tap on Start enters gameplay")
	if not game.active:
		print("START POINT ",start_point," BUTTON ",hud._mode_buttons[0].get_global_rect())
		game.start_mode(0)
		await frames(8)
	for extent in [Vector2i(1280,720),Vector2i(1560,720)]:
		root.size=extent
		root.content_scale_size=extent
		hud._layout()
		game._update_hud()
		await frames(10)
		check(hud._vitals.get_global_rect().end.y<152,"Vitals stay above the play area at %d"%extent.x)
		check(hud._minimap.size.x<=200 and hud._minimap.get_global_rect().end.y<260,"Compact map preserves the movement thumb zone")
		check(hud._mission_box.get_global_rect().end.y<extent.y-310,"Mission card stays above the right action buttons")
		check(hud._menu_button.size.y>=48,"Pause button has a finger-sized target")
		game.tutorial.start()
		for step in game.tutorial.STEPS:
			game.tutorial.step=game.tutorial.STEPS.find(step)
			game.tutorial.step_id=step
			game.tutorial._refresh()
			await frames(7)
			var card: Rect2=hud._tutorial_panel._card.get_global_rect()
			check(card.end.y<=extent.y-230 and card.position.x>210,"Tutorial %s reserves both thumb zones at %d"%[step,extent.x])
			check(not hud._tutorial_panel._illustration.visible,"Mobile tutorial hides desktop keyboard diagrams")
			check(not "按 E" in hud._tutorial_panel._instruction.text and not "鼠标" in hud._tutorial_panel._instruction.text,"Tutorial instructions describe touch controls")
		game.tutorial.end_round()
	game.tutorial.start()
	await frames(8)
	var next_point: Vector2=hud._tutorial_panel._next.get_global_rect().get_center()
	touch(next_point,true)
	await frames(2)
	touch(next_point,false)
	await frames(5)
	check(game.tutorial.step_id=="move","A real touch advances the tutorial without steering the camera")
	game.tutorial.step=game.tutorial.STEPS.find("look")
	game.tutorial.step_id="look"
	game.tutorial._refresh()
	await frames(5)
	var look_point := Vector2(root.get_visible_rect().size.x*.70,390)
	touch(look_point,true,2)
	await physics_frame
	var look_drag := InputEventScreenDrag.new()
	look_drag.index=2
	look_drag.position=look_point+Vector2(70,0)
	look_drag.relative=Vector2(70,0)
	Input.parse_input_event(look_drag)
	Input.flush_buffered_events()
	for i in 3: await physics_frame
	check(game.tutorial.looked>.24,"Tutorial camera progress counts an actual touchscreen swipe")
	touch(look_point,false,2)
	var skip_point: Vector2=hud._tutorial_panel._skip.get_global_rect().get_center()
	touch(skip_point,true)
	await frames(2)
	touch(skip_point,false)
	await frames(4)
	check(not game.tutorial.running,"Touch Skip ends the tutorial")
	var aim: Control=hud._weapon_aim
	aim.has_cursor=true
	aim.cursor=Vector2(40,20)
	check(aim.screen_point().is_equal_approx(root.get_visible_rect().size*.5),"Touch aiming stays at screen center, independent of finger position")
	check(not "按 E" in hud._objective.text and not "右键" in hud._weapon.text,"Field hints use mobile actions")
	hud.show_camp()
	await frames(8)
	check(hud._camp.visible and not hud._hud.visible,"Shop still opens as a scrollable mobile modal")
	print("MOBILE_UI: %d checks, %d failures"%[checks,failures.size()])
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
