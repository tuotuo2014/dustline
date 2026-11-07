extends SceneTree
## Runs real WebSocket connections and Godot RPCs against a running /multiplayer.
const RelayPeer = preload("res://coop_relay_peer.gd")

class Probe extends Node:
	var owner_test: SceneTree
	var received: Array[int] = []
	var request_senders: Array[int] = []
	var world_value := 0
	@rpc("any_peer", "call_remote", "reliable")
	func request(value: int) -> void:
		request_senders.append(multiplayer.get_remote_sender_id())
		answer.rpc_id(multiplayer.get_remote_sender_id(), value + 1)
	@rpc("authority", "call_remote", "reliable")
	func answer(value: int) -> void:
		received.append(value)
	@rpc("authority", "call_remote", "unreliable_ordered", 2)
	func world(value: int) -> void:
		world_value = value

var checks := 0
var failures := 0
var endpoint := "ws://127.0.0.1:8079/multiplayer"
var branches: Array[Dictionary] = []

func _initialize() -> void:
	if not OS.get_environment("DUSTLINE_RELAY_TEST_URL").is_empty():
		endpoint = OS.get_environment("DUSTLINE_RELAY_TEST_URL")
	multiplayer_poll = false
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS ", label)

func make_peer(label: String, host: bool, code: String = "") -> Dictionary:
	var branch := Node.new()
	branch.name = label
	root.add_child(branch)
	var probe := Probe.new()
	probe.name = "Probe"
	branch.add_child(probe)
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api, branch.get_path())
	var peer := RelayPeer.new()
	peer.failed.connect(func(reason: String): print(label, " disconnect: ", reason))
	check(peer.open(endpoint, host, code) == OK, label + " socket opens")
	api.multiplayer_peer = peer
	var item := {"peer": peer, "api": api, "probe": probe}
	branches.append(item)
	return item

func wait_until(predicate: Callable, milliseconds: int = 5000) -> bool:
	var deadline := Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		for branch in branches:
			branch.api.poll()
		if predicate.call():
			return true
		await process_frame
	return false

func _run() -> void:
	var host := make_peer("Host", true)
	check(await wait_until(func(): return host.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED), "host gets relay welcome")
	check(host.peer.get_unique_id() == 1, "actual host retains authority ID 1")
	check(host.peer.room_code.length() == 6, "host receives a real six-character room code")
	if host.peer.room_code.is_empty():
		finish()
		return
	var first := make_peer("First", false, host.peer.room_code)
	var second := make_peer("Second", false, host.peer.room_code)
	check(await wait_until(func(): return host.api.get_peers().size() == 2 and first.api.get_peers().size() == 2 and second.api.get_peers().size() == 2), "three separate connections see peer membership")
	check(first.peer.get_unique_id() > 1 and second.peer.get_unique_id() > 1 and first.peer.get_unique_id() != second.peer.get_unique_id(), "relay assigns distinct client identities")
	first.probe.request.rpc_id(1, 100)
	second.probe.request.rpc_id(1, 200)
	check(await wait_until(func(): return first.probe.received.has(101) and second.probe.received.has(201)), "real Godot reliable RPC request and targeted reply")
	check(host.probe.request_senders.has(first.peer.get_unique_id()) and host.probe.request_senders.has(second.peer.get_unique_id()), "RPC sender identity survives transport")
	host.probe.world.rpc(77)
	check(await wait_until(func(): return first.probe.world_value == 77 and second.probe.world_value == 77), "channel 2 movement-style broadcast reaches both clients")
	first.peer.set_target_peer(second.peer.get_unique_id())
	check(first.peer.put_packet(PackedByteArray([1, 2, 3])) == ERR_UNAUTHORIZED, "client cannot forge a direct client-to-client packet")
	host.peer.refuse_new_connections = true
	await wait_until(func(): return false, 150)
	var rejected := make_peer("Rejected", false, host.peer.room_code)
	check(await wait_until(func(): return rejected.peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED), "locked room rejects a new connection")
	check(not rejected.peer.last_error.is_empty(), "rejected player gets an actionable error")
	host.peer.disconnect_peer(second.peer.get_unique_id())
	check(await wait_until(func(): return second.peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and host.api.get_peers().size() == 1 and first.api.get_peers().size() == 1), "kick removes only the chosen connection")
	host.peer.close()
	check(await wait_until(func(): return first.peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED), "host departure closes client room")
	check(first.peer.last_error.contains("房主"), "host departure reason is retained")
	finish()

func finish() -> void:
	for branch in branches:
		branch.peer.close()
	print("RELAY_TRANSPORT_RESULT ", checks - failures, "/", checks)
	quit(1 if failures else 0)
