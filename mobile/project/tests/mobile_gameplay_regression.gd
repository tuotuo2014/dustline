extends SceneTree
## Integration uses the real game, its real HUD, and engine-dispatched touches.
## No player save is read or written: the temporary profile is set before startup.
var game: Node3D
var player: CharacterBody3D
var controls: CanvasLayer
var hud: CanvasLayer
var failures: Array[String] = []
var checks := 0
var profile_path := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: " + message)
	else:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap_point(position: Vector2, finger: int = 0) -> void:
	touch(finger, position, true)
	await frames(2)
	touch(finger, position, false)
	await frames(3)

func tap_action(action: String, finger: int = 0) -> void:
	await tap_point(controls.button_regions[action].center, finger)

func tap_control(button: Control, finger: int = 0) -> void:
	# Scroll the same UI a player can scroll, without invoking its button signal.
	var parent := button.get_parent()
	while parent:
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await frames(4)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * .5)
	check(root.get_visible_rect().has_point(point), "GUI target is visible and reachable: " + button.name)
	await tap_point(point, finger)

func run() -> void:
	profile_path = "/tmp/dustline-mobile-gameplay-%d.json" % Time.get_ticks_usec()
	OS.set_environment("DUSTLINE_PROFILE_PATH", profile_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED", "1")
	Input.use_accumulated_input = false
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	player = game.player
	controls = player.mobile_controls
	hud = game.hud
	await frames(8)
	check(game.profile.save_path == profile_path, "Integrated test uses its independent temporary profile")
	check(not game.active and not controls.controls_visible, "Initial menu keeps touch gameplay hidden")
	game.profile.assets = 500
	var purchased: Dictionary = game.profile.purchase("repulsor")
	check(purchased.ok and game.profile.equipped=="repulsor", "Test purchase equips an actual firearm")
	await tap_control(hud._mode_buttons[0])
	check(game.active and player.controls_enabled and hud._hud.visible, "Screen touch on the real entry button starts the game")
	if not game.active:
		await finish()
		return
	check(controls.controls_visible and not player.rotating_camera, "Entering with a tap does not leak into camera dragging")
	game.damage_grace = 9999.0
	player.global_position = game._ground(Vector3(0,0,65)) + Vector3(0,.08,0)
	player.velocity = Vector3.ZERO
	await frames(30)
	check(player.is_on_floor(), "Actual world provides a grounded movement start")
	game.health = 40.0
	var medkits_before: int = game.medkits
	await tap_action("heal")
	check(game.health>74.9 and game.medkits==medkits_before-1, "Heal touch reaches main controller and consumes one medkit")
	await tap_action("character_skill")
	check(game.skills.cooldowns[player.character_id]>1.0 and game.skills.active_id==player.character_id, "Skill touch activates real character skill and starts cooldown")
	var ammo_before: int = game.round_ammo
	await tap_action("fire_weapon")
	check(game.round_ammo==ammo_before-1, "Fire touch consumes exactly one real round")
	check(not Input.is_action_pressed("fire_weapon"), "Fire action does not remain pressed after a tap")
	await tap_action("aim_scope")
	check(player.scope_enabled and hud._weapon_aim.scoped, "Aim touch enters the actual scope")
	check(hud._weapon_aim.screen_point().distance_to(root.get_visible_rect().size*.5)<.1, "Mobile aim remains at the center of the screen")
	check(Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED, "Touch scope does not capture the pointer")
	var scope_yaw: float = player.camera_yaw
	var look_at := Vector2(780,380)
	touch(1,look_at,true)
	drag(1,look_at+Vector2(55,0),Vector2(55,0))
	await frames(2)
	touch(1,look_at,false)
	check(absf(angle_difference(scope_yaw,player.camera_yaw))>.05, "Right-side drag turns the actual scoped camera")
	await tap_action("aim_scope")
	check(not player.scope_enabled, "Second aim touch exits scope through the real HUD")
	var flares_before: int = game.flares
	await tap_action("repel")
	check(game.flares==flares_before-1 and game._repel_cooldown>0, "Repel touch consumes the real flare and starts cooldown")
	game.scrap = 0
	await tap_action("build_shelter")
	check(game.toast_remaining>0 and "3 个零件" in game.toast, "Shelter touch reaches the real resource validation")
	# Simultaneous movement, view, and jump with the full HUD still present.
	var stick: Vector2 = controls.joystick_center
	var radius: float = controls.joystick_radius
	var start: Vector3 = player.global_position
	touch(0,stick,true)
	drag(0,stick+Vector2(0,-radius),Vector2(0,-radius))
	touch(1,look_at,true)
	var yaw_before: float = player.camera_yaw
	drag(1,look_at+Vector2(25,0),Vector2(25,0))
	await frames(15)
	touch(2,controls.button_regions.jump.center,true)
	await frames(6)
	check(player.global_position.distance_to(start)>.2 and player.velocity.y>2.0, "Actual character moves and jumps with three simultaneous touches")
	check(absf(angle_difference(yaw_before,player.camera_yaw))>.05 and controls.move_finger==0 and controls.look_finger==1, "Full HUD preserves independent movement and camera fingers")
	touch(2,controls.button_regions.jump.center,false)
	# The GUI pause button must remain usable while virtual controls are held.
	await tap_control(hud._menu_button,3)
	check(not game.active and hud._menu.visible, "Real pause menu button accepts touch during movement")
	check(controls.touch_roles.is_empty() and not Input.is_action_pressed("move_forward") and not player.touch_look_active, "Opening menu clears all held touches")
	if game.active: game.open_menu()
	touch(0,stick,false)
	touch(1,look_at,false)
	await tap_control(hud._resume)
	check(game.active and player.controls_enabled, "Resume works by touching the real menu")
	var runtime: Node = game.get_node("MobileRuntime")
	touch(0,stick,true)
	drag(0,stick+Vector2(0,-radius),Vector2(0,-radius))
	runtime._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	check(not game.active and hud._menu.visible and controls.touch_roles.is_empty(), "Android back request pauses the single-player expedition")
	touch(0,stick,false)
	await tap_control(hud._resume)
	check(game.active, "Resume after Android back preserves the round")
	await tap_action("sprint")
	runtime._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await frames(3)
	check(not game.active and not Input.is_action_pressed("sprint") and not controls.sprint_toggled, "Backgrounding pauses gameplay and releases sprint")
	await tap_control(hud._resume)
	check(game.active and game.medkits==medkits_before-1, "Returning from background preserves real gameplay resources")
	game.open_menu()
	await finish()

func finish() -> void:
	game.queue_free()
	await frames(4)
	for suffix in ["", ".bak", ".tmp", ".tutorial.cfg", ".tutorial.cfg.tmp"]:
		if FileAccess.file_exists(profile_path+suffix): DirAccess.remove_absolute(profile_path+suffix)
	print("MOBILE GAMEPLAY REGRESSION: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
