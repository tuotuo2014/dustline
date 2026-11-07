extends SceneTree
const Layout = preload("res://world_layout.gd")

var failures: Array[String] = []
var checks := 0
var game: Node3D
var player: CharacterBody3D
var hud: CanvasLayer

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code, true)
	await frames(1)
	key(code, false)
	await frames(1)

func click(button: Button) -> void:
	await frames(3)
	# Transform the visible control center to viewport pixels and send a genuine
	# GUI pointer press/release; emitting Button.pressed would miss entry bugs.
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = point
	down.global_position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	root.push_input(down, true)
	await frames(1)
	var up := InputEventMouseButton.new()
	up.position = point
	up.global_position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up, true)
	await frames(3)

func teleport(position: Vector3, settle: int = 4) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	await frames(settle)

func begin(id: int) -> void:
	game.start_mode(id)
	game.damage_grace = 999.0
	await frames(4)

func interact_at(node: Node3D) -> void:
	await teleport(node.global_position + Vector3(0, 0, 1.3))
	await tap(KEY_E)

func park_mutants() -> void:
	for i in game.mutants.size():
		var mutant: CharacterBody3D = game.mutants[i]
		mutant.global_position = game._ground(Vector3(58, 0, -58 + i * 3))
		mutant.velocity = Vector3.ZERO
		mutant.home = mutant.global_position
		mutant.patrol_goal = mutant.global_position
		mutant._set_state("patrol")

func run() -> void:
	Input.use_accumulated_input = false
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	player = game.get_node("Player")
	hud = game.get_node("UI")
	await frames(8)
	await test_entry_and_pause()
	if not game.active:
		print("GAMEPLAY REGRESSION ABORTED: real entry button did not start gameplay")
		quit(1)
		return
	await test_resources_and_exploration()
	await test_extraction_and_restart()
	await test_survival()
	await test_building()
	await test_flares_and_monsters()
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_Q, KEY_B, KEY_F, KEY_M, KEY_ESCAPE]:
		key(code, false)
	print("GAMEPLAY REGRESSION: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_entry_and_pause() -> void:
	check(not game.active and not player.controls_enabled and hud._menu.visible, "Initial entry menu disables player controls")
	var origin := player.global_position
	var elapsed_before: float = game.elapsed
	key(KEY_W, true)
	await frames(20)
	key(KEY_W, false)
	check(player.global_position.distance_to(origin) < .001 and is_equal_approx(game.elapsed, elapsed_before), "Initial menu freezes real movement and mission clock")
	await click(hud._mode_buttons[0])
	check(game.active and player.controls_enabled and hud._hud.visible and not hud._menu.visible, "Actual mouse click on Explore enters playable world")
	if not game.active:
		return
	check(not player.rotating_camera, "Entry button click does not leak into camera dragging")
	await frames(12)
	origin = player.global_position
	key(KEY_W, true)
	await frames(28)
	key(KEY_W, false)
	check(player.global_position.z < origin.z - .65, "W moves the character immediately after entering")
	await frames(18)
	await click(hud._menu_button)
	check(not game.active and not player.controls_enabled and hud._resume.visible, "Actual HUD menu click pauses and offers Continue")
	origin = player.global_position
	elapsed_before = game.elapsed
	var enemy: CharacterBody3D = game.mutants[0]
	var enemy_origin := enemy.global_position
	key(KEY_W, true)
	await frames(30)
	key(KEY_W, false)
	check(player.global_position.distance_to(origin) < .001 and is_equal_approx(game.elapsed, elapsed_before) and enemy.global_position.distance_to(enemy_origin) < .001, "Pause freezes player, mission time, and mutant simulation")
	await click(hud._resume)
	check(game.active and player.controls_enabled and not hud._menu.visible, "Actual Continue click resumes gameplay")
	origin = player.global_position
	key(KEY_S, true)
	await frames(25)
	key(KEY_S, false)
	check(player.global_position.z > origin.z + .5 and game.elapsed > elapsed_before, "Movement and timer recover after Continue")
	await tap(KEY_M)
	await click(hud._mode_buttons[1])
	check(game.mode == 1 and game.active and game.scrap == 0 and game.mutants.size() == 4, "Actual Extraction card click switches mode with a fresh round")
	await tap(KEY_M)
	await click(hud._mode_buttons[2])
	check(game.mode == 2 and game.active and game.mutants.size() == 5, "Actual Survival card click switches mode and enemy population")
	await tap(KEY_M)
	await click(hud._mode_buttons[0])
	check(game.mode == 0 and game.active and game.mutants.size() == 3, "Returning to Explore by mouse remains playable")

func test_resources_and_exploration() -> void:
	await begin(0)
	var first: Area3D = game.pickups[0]
	game._collect(first)
	game._collect(first)
	check(game.scrap == 1 and game.collected == 1 and not game.pickups.has(first), "A pickup grants its resource once even if collected twice in one frame")
	await frames(2)
	var second: Area3D = game.pickups[0]
	await teleport(second.global_position, 5)
	check(game.scrap == 2 and game.collected == 2, "Walking into salvage automatically collects it")
	await teleport(game.base.global_position)
	await tap(KEY_Q)
	check(game.health == 100.0 and game.medkits == 2, "Q preserves the medical kit at full health")
	game.health = 89.0
	await tap(KEY_Q)
	check(game.health == 100.0 and game.medkits == 1, "Q consumes exactly one kit and caps healing at 100")
	game.health = 40.0
	await tap(KEY_Q)
	check(game.health == 75.0 and game.medkits == 0, "Medical kits restore exactly 35 health")
	await tap(KEY_Q)
	check(game.health == 75.0 and game.medkits == 0, "Empty medical inventory cannot heal for free")
	await interact_at(game.base)
	check(not game.round_over, "Returning to camp before repairing relays does not win Explore")
	game.scrap = 1
	await interact_at(game.relays[0])
	check(game.repaired == 0 and game.scrap == 1, "Relay repair requires the complete two-scrap cost")
	game.scrap = 6
	await tap(KEY_E)
	check(game.repaired == 1 and game.scrap == 4 and game.relays[0].get_meta("active"), "E repairs a nearby relay and deducts exactly two scrap")
	await tap(KEY_E)
	check(game.repaired == 1 and game.scrap == 4, "A repaired relay cannot be charged or counted twice")
	await interact_at(game.relays[1])
	await interact_at(game.relays[2])
	check(game.repaired == 3 and game.scrap == 0 and not game.round_over, "All three relays are required and do not auto-complete in the field")
	await interact_at(game.base)
	check(game.round_over and game.won and not game.active and hud._result.visible, "Explore succeeds only after returning to camp with three repaired relays")

func test_extraction_and_restart() -> void:
	await begin(1)
	game.scrap = 5
	await interact_at(game.extraction)
	check(not game.round_over and game.scrap == 5, "Extraction rejects five scrap without consuming inventory")
	game.scrap = 6
	await tap(KEY_E)
	check(game.round_over and game.won, "Extraction succeeds with six scrap at the exit")
	await begin(1)
	game.elapsed = 179.98
	await frames(1)
	check(not game.round_over, "Extraction remains open immediately before its 180-second limit")
	await frames(3)
	check(game.round_over and not game.won and not player.controls_enabled, "The real physics clock fails extraction at the 180-second boundary")
	await click(hud._result_restart)
	check(game.mode == 1 and game.active and game.elapsed < .5, "Result Replay button starts the same mode from zero time")
	game.health = 34.0
	game.scrap = 12
	game.medkits = 0
	game.flares = 0
	game.repaired = 2
	game.elapsed = 70.0
	game.repel_mutants()
	var old_round_id: int = game.round_root.get_instance_id()
	var initial_pickup_count: int = game.LOOT_POSITIONS.size() + game.MEDKIT_POSITIONS.size() + game.expedition.valuable_count
	await tap(KEY_M)
	await click(hud._restart)
	check(game.health == 100.0 and game.scrap == 0 and game.medkits == 2 and game.flares == 1 and game.repaired == 0 and game.elapsed < .5, "Restart resets health, resources, objectives, and mission clock")
	check(not is_instance_id_valid(old_round_id) and game.pickups.size() == initial_pickup_count and game.shelters.size() == 1 and game.relays.size() == 3 and game.mutants.size() == 4 and game.flare_nodes.is_empty(), "Restart deletes the previous expedition and recreates exactly one set of actors")

func test_survival() -> void:
	await begin(2)
	park_mutants()
	await teleport(game._ground(Vector3(0, 0, 60)), 15)
	game.elapsed = 30.0
	game.health = 100.0
	game.damage_grace = 0.0
	await frames(30)
	check(game.storm_active and game.health < 99.0 and game.health > 97.0, "Survival storm applies continuous outdoor damage")
	await teleport(game.base.global_position, 4)
	var health_before: float = game.health
	await frames(30)
	check(game.is_sheltered(player.global_position) and is_equal_approx(game.health, health_before), "Camp shelter blocks storm damage")
	await teleport(game._ground(Vector3(0, 0, 60)), 4)
	await tap(KEY_M)
	health_before = game.health
	var elapsed_before: float = game.elapsed
	await frames(45)
	check(is_equal_approx(game.health, health_before) and is_equal_approx(game.elapsed, elapsed_before), "Opening the menu during a storm freezes damage and storm time")
	await click(hud._resume)
	await frames(10)
	check(game.active and game.health < health_before and game.elapsed > elapsed_before, "Resuming restores the active storm and its damage")
	game.damage_grace = 999.0
	game.elapsed = 121.0
	await interact_at(game.base)
	check(not game.round_over, "Surviving 120 seconds alone is insufficient without relays")
	game.scrap = 4
	await interact_at(game.relays[0])
	await interact_at(game.base)
	check(not game.round_over and game.repaired == 1, "Survival requires two relays, not one")
	await interact_at(game.relays[1])
	game.elapsed = 119.0
	await interact_at(game.base)
	check(not game.round_over and game.repaired == 2, "Two repaired relays cannot complete Survival before 120 seconds")
	game.elapsed = 120.0
	await frames(1)
	await tap(KEY_E)
	check(game.round_over and game.won, "Survival completes at camp after both time and relay requirements")

func test_building() -> void:
	await begin(0)
	park_mutants()
	game.scrap = 6
	await teleport(Vector3(0, 10, 60), 2)
	check(not game.build_shelter() and game.scrap == 6, "Airborne construction is rejected without charging scrap")
	await teleport(game._ground(Vector3(0, 0, Layout.EXTENT - 1.0)), 30)
	player.get_node("Body").rotation.y = PI
	check(not game.build_shelter() and game.scrap == 6, "Construction beyond the map boundary is rejected without charging")
	await teleport(game.base.global_position, 15)
	player.get_node("Body").rotation.y = 0.0
	check(not game.build_shelter() and game.scrap == 6, "Construction overlapping an existing facility is rejected")
	await teleport(game._ground(Vector3(0, 0, 60)), 30)
	player.get_node("Body").rotation.y = 0.0
	await tap(KEY_B)
	check(game.shelters.size() == 2 and game.scrap == 3, "B builds one shelter on clear level ground for exactly three scrap")
	check(not game.build_shelter() and game.scrap == 3 and game.shelters.size() == 2, "Repeated construction cannot overlap the newly built shelter")
	if game.shelters.size() > 1:
		await teleport(game.shelters[1].global_position)
		check(game.is_sheltered(player.global_position), "A constructed shelter provides actual protection")

func test_flares_and_monsters() -> void:
	await begin(0)
	park_mutants()
	game.scrap = 4
	await tap(KEY_F)
	check(game.flares == 0 and game.scrap == 4 and game.flare_nodes.size() == 1, "F uses the initial free flare without charging scrap")
	await tap(KEY_F)
	check(game.scrap == 4 and game.flare_nodes.size() == 1, "Flare cooldown prevents double activation and double spending")
	await frames(62)
	await tap(KEY_F)
	check(game.scrap == 2 and game.flare_nodes.size() == 2, "After free charges run out F spends exactly two scrap")
	game.scrap = 0
	await frames(62)
	await tap(KEY_F)
	check(game.scrap == 0 and game.flare_nodes.size() == 2, "F cannot create a flare without a charge or sufficient scrap")
	var mutant: CharacterBody3D = game.mutants[0]
	mutant.global_position = player.global_position + Vector3(0, 0, -6)
	mutant.velocity = Vector3.ZERO
	mutant._set_state("chase")
	await frames(4)
	var distance_before := mutant.global_position.distance_to(player.global_position)
	await frames(20)
	check(mutant.state == "flee" and mutant.global_position.distance_to(player.global_position) > distance_before + .4, "Nearby mutants visibly retreat from an active flare")
	for flare in game.flare_nodes:
		flare.set_meta("remaining", .04)
	await frames(5)
	check(game.flare_nodes.is_empty(), "Expired flares are removed instead of repelling forever")

	# A real collider verifies visibility; terrain props remain in the scene.
	game.set_physics_process(false)
	await teleport(game._ground(Vector3(0, 0, 60)), 15)
	mutant.global_position = game._ground(Vector3(0, 0, 53))
	mutant.velocity = Vector3.ZERO
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 4, .5)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(0, 2, 56)
	game.add_child(wall)
	await frames(2)
	check(not mutant._can_see(player), "Mutant line of sight is blocked by a real wall")
	wall.queue_free()
	await frames(2)
	check(mutant._can_see(player), "Removing the wall restores mutant line of sight")
	game.set_physics_process(true)
