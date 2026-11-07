extends SceneTree
var failures: Array[String] = []
var checks := 0
var game: Node3D
var player: CharacterBody3D
var beast: CharacterBody3D
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
	else:
		print("PASS: " + message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func reset_encounter() -> void:
	game.start_mode(0)
	game.damage_grace=0.0
	player=game.player
	player.position=Vector3(0,0,60)
	player.velocity=Vector3.ZERO
	player.set_physics_process(false)
	for i in range(1,game.mutants.size()):
		game.mutants[i].position=Vector3(55,1,-55)
	beast=game.mutants[0]
	beast.position=Vector3(0,0,51)
	beast.rotation.y=PI
	beast.velocity=Vector3.ZERO
	beast.home=beast.position
	beast.patrol_goal=Vector3(1,0,52)
	await frames(3)
func wait_for_state(wanted: String, limit: int=240) -> bool:
	for i in limit:
		if beast.state==wanted:
			return true
		await frames(1)
	return false
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await reset_encounter()
	check(beast.state=="chase", "A wolf autonomously detects and chases an exposed player")
	check(game.health==100.0,"Detection itself does not inflict damage")
	check(await wait_for_state("windup"),"Approaching wolf telegraphs a bite")
	check(beast.threat_marker.visible and beast.threat_marker.text=="!!","Windup has a visible danger cue")
	await frames(20)
	check(game.health==100.0,"Attack windup leaves time to react")
	var hp_before: float=game.health
	for i in 120:
		await frames(1)
		if game.health<hp_before: break
	check(game.health==82.0,"The real autonomous lunge takes exactly 18 health")
	check(game.toast.contains("扑咬"),"A landed bite gives damage feedback")
	check(beast.global_position.distance_to(player.global_position)>2.2,"Attacking creature retains body clearance")
	await frames(60)
	check(game.health==82.0,"Bite cooldown prevents repeated per-frame damage")
	for i in 240:
		await frames(1)
		if game.health<82.0: break
	check(game.health==64.0,"A creature can attack again after the cooldown")
	await reset_encounter()
	check(await wait_for_state("windup"),"Second encounter reaches a windup")
	player.position=Vector3(8,0,62)
	await frames(70)
	check(game.health==100.0,"Moving out of the bite's reach makes the lunge miss")
	await reset_encounter()
	await wait_for_state("windup")
	game.repel_mutants()
	await frames(5)
	check(beast.state=="flee","A flare interrupts the attack and starts retreat")
	await frames(70)
	check(game.health==100.0,"A retreating creature cannot land its cancelled bite")
	await reset_encounter()
	await wait_for_state("windup")
	var old_clock: float=beast.state_time
	game.open_menu()
	await frames(100)
	check(beast.state=="windup" and is_equal_approx(beast.state_time,old_clock) and game.health==100.0,"Menu pause freezes an in-progress attack")
	game.resume_game()
	for i in 120:
		await frames(1)
		if game.health<100.0: break
	check(game.health==82.0,"A resumed encounter continues its attack normally")
	await reset_encounter()
	await wait_for_state("windup")
	player.position=game.base.global_position
	await frames(80)
	check(game.health==100.0 and beast.state=="patrol","Entering the camp cancels pursuit and protects the player")
	game.health=8.0
	game.damage_grace=0.0
	game.take_damage(18.0,true)
	check(game.round_over and not game.active and not game.won,"A lethal hit ends the round with a failure result")
	game.restart_game()
	check(game.health==100.0 and game.active and not game.round_over,"Restart restores health and clears the failed encounter")
	print("MUTANT ATTACK REGRESSION: %s; %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
