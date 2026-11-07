extends SceneTree
const Tutorial = preload("res://new_player_tutorial.gd")
var game: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var guide: Node
var checks := 0
var failures: Array[String] = []
var save_path := "/tmp/dustline-tutorial-test-%d.json" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)
func mouse(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=button
	event.button_mask=(1 << (button-1)) if down else 0
	event.pressed=down
	root.push_input(event,true)
func click(button: Button) -> void:
	await frames(4)
	var point := button.get_global_transform_with_canvas()*(button.size*.5)
	mouse(point,true)
	await frames(1)
	mouse(point,false)
	await frames(4)
func teleport(point: Vector3) -> void:
	player.global_position=point
	player.velocity=Vector3.ZERO
	await frames(8)
func jump_to_step(id: String) -> void:
	guide._clear_marker()
	guide.step=Tutorial.STEPS.find(id)
	guide.step_id=id
	guide._ready_time=0.0
	guide._refresh()
func saved_preference() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(guide.preference_path)
	return config

func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","")
	Input.use_accumulated_input=false
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	player=game.player
	hud=game.hud
	guide=game.tutorial
	await frames(10)
	check(not guide.running and not hud._tutorial_panel.is_visible_in_tree(),"Initial menu does not show field tutorial")
	await click(hud._mode_buttons[0])
	check(game.active and guide.running and guide.step_id=="welcome","Actual mode button starts first-time tutorial")
	check(hud._tutorial_panel.is_visible_in_tree() and player.controls_enabled,"Tutorial leaves real movement enabled")
	check(not player.rotating_camera and root.gui_get_focus_owner()==null,"Entry and tutorial do not capture mouse or keyboard focus")
	var before: float=game.elapsed
	var enemy_position: Vector3=game.mutants[0].global_position
	var health: float=game.health
	game.damage_grace=0
	game.take_damage(200,true)
	await frames(65)
	check(game.health==health and game.elapsed==before and game.mutants[0].global_position.is_equal_approx(enemy_position),"Practice freezes mission, wolf simulation and damage")
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="move" and not player.rotating_camera,"Actual tutorial button advances without dragging camera")
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="move","Incomplete movement cannot be skipped with Next")
	await teleport(game._ground(Vector3(0,0,60)))
	check(guide.walked<.1,"Teleport is not counted as walking")
	key(KEY_W,true)
	await frames(210)
	key(KEY_W,false)
	await frames(15)
	check(guide.step_id=="look" and guide.walked>=4,"Actual W movement advances after four metres")
	var point := Vector2(1100,850)
	mouse(point,true,MOUSE_BUTTON_LEFT)
	await frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	motion.relative=Vector2(65,0)
	motion.screen_relative=Vector2(65,0)
	motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion,true)
	await frames(3)
	mouse(point,false,MOUSE_BUTTON_LEFT)
	await frames(45)
	check(guide.step_id=="run_jump" and guide.looked>=.24 and not player.rotating_camera,"Actual mouse drag completes view lesson and releases capture")
	key(KEY_SHIFT,true)
	key(KEY_S,true)
	await frames(65)
	key(KEY_S,false)
	key(KEY_SHIFT,false)
	await frames(5)
	check(guide.step_id=="jump" and guide.sprinted>=2,"Sprinting has its own completed lesson")
	await tap(KEY_SPACE)
	await frames(60)
	await frames(45)
	check(guide.sprinted>=2 and guide.jumped and guide.landed and guide.step_id=="loot","Actual sprint and jump must land before progressing")
	check(is_instance_valid(guide.marker) and is_instance_valid(guide.target),"Loot lesson marks a real collectible")
	var marker: Node=guide.marker
	var count_before: int=guide.pickups_seen
	var bank_before: int=game.profile.assets
	var real_target: Area3D=guide.target
	await teleport(real_target.global_position+Vector3(0,.05,0))
	await frames(45)
	check(guide.pickups_seen>count_before and guide.step_id=="skill","Automatic proximity pickup advances lesson")
	check(not is_instance_valid(marker) and guide.marker==null,"Collected target marker is removed")
	check(game.profile.assets==bank_before,"Practice collection never grants permanent assets")
	game.skills.cooldowns[player.character_id]=1.0
	await tap(KEY_C)
	check(not guide.skill_used and guide.step_id=="skill","Rejected skill activation does not count")
	await frames(65)
	await tap(KEY_C)
	await frames(44)
	check(guide.skill_used and guide.step_id=="survival","Actual successful C skill advances tutorial")
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="repel","Healing and repelling have separate explanations")
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="shelter","Shelter has a dedicated explanation")
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="mission","Mission rules are explained before extraction")
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="extraction" and "3 座" in hud._tutorial_panel._instruction.text,"Final lesson shows current mode extraction requirements")
	await tap(KEY_M)
	var paused_step: String=guide.step_id
	await frames(30)
	check(not game.active and not hud._tutorial_panel.is_visible_in_tree() and guide.step_id==paused_step,"Pause hides guide and preserves progress")
	await click(hud._resume)
	check(game.active and guide.running and hud._tutorial_panel.is_visible_in_tree() and guide.step_id==paused_step,"Resume restores guide at same step")
	await click(hud._tutorial_panel._next)
	check(not guide.running and guide.seen and not hud._tutorial_panel.is_visible_in_tree(),"Final button ends practice and hides guide")
	check(saved_preference().get_value("tutorial","completed",false),"Completion preference saved beside isolated profile")
	await frames(10)
	check(game.elapsed>before,"Mission clock resumes after completion")
	game.damage_grace=0
	game.take_damage(2)
	check(game.health==health-2,"Damage resumes after practice")
	var probe := Tutorial.new()
	probe.game=game
	game.add_child(probe)
	check(probe.seen,"Fresh tutorial controller reads persisted preference")
	probe.queue_free()
	await frames(2)
	game.restart_game()
	await frames(5)
	check(not guide.running,"Completed tutorial does not repeat on next round")
	await tap(KEY_M)
	var entry: Button=hud._menu.find_child("TutorialEntry",true,false)
	check(entry!=null,"Menu exposes tutorial replay")
	game.scrap=5
	game.elapsed=31
	var expedition_id: String=game.expedition.id
	await click(entry)
	check(guide.running and game.active and guide.step_id=="welcome","Actual menu replay button restarts guide")
	check(game.scrap==5 and game.elapsed==31 and game.expedition.id==expedition_id,"Replay retains current round, loot and elapsed time")
	jump_to_step("loot")
	await frames(10)
	marker=guide.marker
	await click(hud._tutorial_panel._skip)
	check(not guide.running and not is_instance_valid(marker),"Skip clears protection and marker")
	check(saved_preference().get_value("tutorial","dismissed",false),"Skip persists dismissal")
	guide.seen=false
	game.restart_game()
	await frames(4)
	await click(hud._tutorial_panel._next)
	game.restart_game()
	await frames(4)
	check(guide.running and guide.step_id=="welcome","Interrupted onboarding restarts on a fresh round")
	guide.skip()
	for mode in [0,1,2]:
		game.start_mode(mode)
		guide.start()
		jump_to_step("extraction")
		var copy: String=hud._tutorial_panel._instruction.text
		check(("3 座" in copy if mode==0 else ("180 秒" in copy and "6 个" in copy if mode==1 else "120 秒" in copy and "2 座" in copy)),"Mode %d has correct conditions"%mode)
		guide.skip()
	for id in 4:
		game.open_menu()
		game._on_character_selected(id)
		game.start_mode(0)
		guide.start()
		await frames(10)
		jump_to_step("skill")
		check(str(game.skills.status(id).name) in hud._tutorial_panel._instruction.text,"Character %d uses its real skill instructions"%id)
		await tap(KEY_C)
		await frames(43)
		check(guide.step_id=="survival","Character %d actual skill completes lesson"%id)
		guide.skip()
	# A late replay can have no remaining pickups; keep it finishable without gifts.
	guide.start()
	for pickup in game.pickups:
		if is_instance_valid(pickup): pickup.queue_free()
	game.pickups.clear()
	await frames(4)
	jump_to_step("loot")
	check(not hud._tutorial_panel._next.disabled and "已经拾完" in hud._tutorial_panel._progress.text,"Exhausted supplies offer an explanatory next step")
	var scrap_before: int=game.scrap
	await click(hud._tutorial_panel._next)
	check(guide.step_id=="skill" and game.scrap==scrap_before and game.profile.assets==bank_before,"Empty-map replay continues without granting resources")
	guide.skip()
	# Events performed early still count when their lesson arrives.
	game.start_mode(0)
	guide.start()
	await frames(12)
	await tap(KEY_C)
	var pickup: Area3D=game.pickups[0]
	game._collect(pickup)
	jump_to_step("loot")
	await frames(44)
	check(guide.step_id=="skill" and guide.pickups_seen==1,"Earlier real pickup is retained across tutorial steps")
	await frames(44)
	check(guide.step_id=="survival","Earlier successful skill avoids waiting for a new cooldown")
	guide.skip()
	for region_id in [1,2,3]:
		game._selected_region=region_id
		game.start_mode(0)
		guide.start()
		jump_to_step("loot")
		await frames(8)
		check(is_instance_valid(guide.target) and is_instance_valid(guide.marker) and not game._extraction_hint().is_empty(),"Region %d has real tutorial supplies and extraction guidance"%region_id)
		guide.skip()
	game.start_mode(1)
	guide.start()
	jump_to_step("loot")
	await frames(5)
	marker=guide.marker
	game._finish(false,"测试结束","测试")
	await frames(4)
	check(not guide.running and not is_instance_valid(marker) and not hud._tutorial_panel.is_visible_in_tree(),"Round result removes guide and its marker")
	for code in [KEY_W,KEY_S,KEY_SHIFT,KEY_SPACE,KEY_C,KEY_M]: key(code,false)
	game.queue_free()
	await frames(3)
	for suffix in ["",".bak",".tmp",".bak.tmp",".tutorial.cfg",".tutorial.cfg.tmp"]:
		DirAccess.remove_absolute(save_path+suffix)
	print("TUTORIAL REGRESSION: %s; %d checks; %d failures"%["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
