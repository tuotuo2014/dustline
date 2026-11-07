extends SceneTree
## Cross-transport integration: a separate playable peer joins a real browser host.
var game: Node3D
var net: Node
var failed := false
var state_path := "/tmp/mobile-browser-guest.json"
func _initialize() -> void: run.call_deferred()
func save_state(phase: String) -> void:
	var f := FileAccess.open(state_path,FileAccess.WRITE)
	f.store_string(JSON.stringify({"phase":phase,"members":net.members.size(),"in_round":net.in_round,"active":game.active,"message":net.message,"position":str(game.player.global_position)}))
func wait_until(predicate: Callable, timeout := 150.0) -> bool:
	var end := Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		await create_timer(.2).timeout
	save_state("timeout")
	failed=true
	return false
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH","/tmp/mobile-browser-guest-save.json")
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	net=game.coop
	game._on_character_selected(1)
	var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/mobile-browser-room.json"))
	net.relay_url=info.url
	if net.join_room("远方的队友",info.code)!=OK:
		quit(1)
		return
	if not await wait_until(func(): return net.members.size()==2):
		quit(1)
		return
	net.toggle_ready()
	save_state("ready")
	if not await wait_until(func(): return game.active and net.in_round):
		quit(1)
		return
	print("BROWSER COOP: joined actual browser host; same round active; avatar count=",net.avatars.size())
	save_state("playing")
	await create_timer(2).timeout
	Input.action_press("move_forward")
	await create_timer(1.2).timeout
	Input.action_release("move_forward")
	await create_timer(.5).timeout
	net.request_action("character_skill")
	save_state("moved_and_skill")
	await create_timer(2).timeout
	var initial: Vector3=net.avatars[1].target_position
	save_state("watching_host")
	if await wait_until(func(): return net.avatars.has(1) and net.avatars[1].target_position.distance_to(initial)>1.0,90):
		print("BROWSER COOP: browser touch movement received by independent guest")
		save_state("host_moved")
	await wait_until(func(): return FileAccess.file_exists("/tmp/mobile-browser-guest-stop"),90)
	net.leave_room("测试结束")
	print("BROWSER COOP RESULT ","PASS" if not failed else "FAIL")
	quit(1 if failed else 0)
