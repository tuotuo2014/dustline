extends MultiplayerPeerExtension
## Browser-compatible transport. The relay routes bytes; player 1 still owns the game.
## WebSockets are ordered/reliable, including movement packets. Under congestion we
## drop outgoing unreliable updates before enqueueing them, never reliable actions.
signal room_ready(code: String)
signal failed(reason: String)

const WIRE_PROTOCOL := 1
const HEADER_SIZE := 6
const MAX_PACKET_BYTES := 262144
const MAX_QUEUED_BYTES := 2097152
const MAX_QUEUED_PACKETS := 512
const MAX_OUTBOUND_BYTES := 1048576
const UNRELIABLE_BACKLOG_BYTES := 262144
const CONNECT_TIMEOUT_MS := 45000

var room_code := ""
var last_error := ""
var _socket: WebSocketPeer
var _status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_DISCONNECTED
var _hosting := false
var _unique_id := 0
var _target := 0
var _mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel := 0
var _refuse := false
var _hello_sent := false
var _opened_at := 0
var _peers: Dictionary = {}
var _packets: Array[Dictionary] = []
var _queued_bytes := 0
var _waiting_url := ""

func open(url: String, hosting: bool, room: String = "") -> Error:
	if _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
		return ERR_ALREADY_IN_USE
	if not (url.begins_with("wss://") or url.begins_with("ws://")):
		return ERR_INVALID_PARAMETER
	var normalized := room.strip_edges().to_upper()
	if not hosting and not _valid_room(normalized):
		return ERR_INVALID_PARAMETER
	_hosting = hosting
	room_code = normalized if not hosting else ""
	last_error = ""
	_unique_id = 0
	_hello_sent = false
	_refuse = false
	_target = 0
	_channel = 0
	_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peers.clear()
	_packets.clear()
	_queued_bytes = 0
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = MAX_QUEUED_BYTES
	_socket.outbound_buffer_size = MAX_OUTBOUND_BYTES
	_socket.max_queued_packets = MAX_QUEUED_PACKETS
	if not OS.has_feature("web"):
		_socket.heartbeat_interval = 15.0
	_waiting_url=""
	var connection_url := _bridge_url(url)
	var error: Error=OK
	if OS.get_name()=="macOS" and url.begins_with("wss://") and connection_url==url and FileAccess.file_exists("res://tools/desktop_proxy.py"):
		_waiting_url=url
		OS.create_process("/usr/bin/python3",[ProjectSettings.globalize_path("res://tools/desktop_proxy.py")])
	else:
		error=_socket.connect_to_url(connection_url)
	if error != OK:
		_socket = null
		return error
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	_opened_at = Time.get_ticks_msec()
	return OK

func _bridge_url(url: String) -> String:
	if OS.get_name()!="macOS" or not url.begins_with("wss://") or not FileAccess.file_exists("res://.runtime/desktop-proxy.json"): return url
	var bridge: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://.runtime/desktop-proxy.json"))
	if bridge is Dictionary and absf(Time.get_unix_time_from_system()-float(bridge.get("checked_at",0)))<8 and str(bridge.get("prefix","")).begins_with("ws://127.0.0.1:8076/bridge/"):
		return str(bridge.prefix)+url.to_utf8_buffer().hex_encode()
	return url

func set_room_locked(locked: bool) -> void:
	_refuse = locked
	if _hosting and _status == MultiplayerPeer.CONNECTION_CONNECTED:
		_send_control({"op": "lock", "locked": locked})

func _valid_room(value: String) -> bool:
	if value.length() != 6:
		return false
	for character in value:
		if not character in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789":
			return false
	return true

func _poll() -> void:
	if _socket == null or _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	if not _waiting_url.is_empty():
		var url := _bridge_url(_waiting_url)
		if url==_waiting_url and Time.get_ticks_msec()-_opened_at<2500: return
		_waiting_url=""
		if _socket.connect_to_url(url)!=OK:
			_fail("无法连接联机服务，请检查网络后重试。")
			return
	_socket.poll()
	var state := _socket.get_ready_state()
	if _status == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() - _opened_at > CONNECT_TIMEOUT_MS:
		_fail("联机连接超时，请检查网络后重试。")
		return
	if state == WebSocketPeer.STATE_OPEN and not _hello_sent:
		_hello_sent = true
		var hello := {"op": "host" if _hosting else "join", "protocol": WIRE_PROTOCOL}
		if not _hosting:
			hello["code"] = room_code
		_send_control(hello)
	var count := 0
	while _socket != null and _status != MultiplayerPeer.CONNECTION_DISCONNECTED and _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		if _socket.was_string_packet():
			_handle_control(packet)
		else:
			_handle_packet(packet)
		count += 1
		if count >= MAX_QUEUED_PACKETS:
			break
	# A close frame can arrive in the same poll as the service's final JSON reason.
	# Drain those queued messages before falling back to a generic socket error.
	if _socket != null and state == WebSocketPeer.STATE_CLOSED:
		var reason := _socket.get_close_reason()
		if reason.is_empty():
			reason = "联机连接已断开，请重新进入房间。" if _hello_sent else "无法连接联机服务，请检查网络后重试。"
		_fail(reason)

func _send_control(data: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if _socket.get_current_outbound_buffered_amount() > MAX_OUTBOUND_BYTES - 4096:
		_fail("网络拥堵，房间已断开。请稍后重新连接。")
		return
	if _socket.send_text(JSON.stringify(data)) != OK:
		_fail("无法发送联机消息，请重新连接房间。")

func _handle_control(packet: PackedByteArray) -> void:
	if packet.size() > 4096:
		_fail("联机服务返回了无效消息。")
		return
	var decoded: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if not decoded is Dictionary:
		_fail("联机服务返回了无效消息。")
		return
	var data: Dictionary = decoded
	match str(data.get("op", "")):
		"welcome":
			if _status != MultiplayerPeer.CONNECTION_CONNECTING:
				_fail("联机服务重复分配了房间。")
				return
			var id := int(data.get("id", 0))
			var code := str(data.get("code", ""))
			var peers: Variant = data.get("peers", [])
			if id < 1 or id > 2147483647 or (id == 1) != _hosting or not _valid_room(code) or not peers is Array or peers.size() > 3:
				_fail("联机服务返回了无效房间。")
				return
			# JSON numbers are floats; typed integers are needed for membership checks.
			var peer_ids: Array[int] = []
			for remote in peers:
				peer_ids.append(int(remote))
			if not _hosting and not peer_ids.has(1):
				_fail("房主已离线，请重新加入房间。")
				return
			_unique_id = id
			room_code = code
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			# The host initializes its roster before any peer-connected callbacks.
			room_ready.emit(room_code)
			if _status != MultiplayerPeer.CONNECTION_CONNECTED:
				return
			for remote in peer_ids:
				_add_peer(remote)
			if _hosting and _refuse:
				set_room_locked(true)
		"peer_joined":
			if _status == MultiplayerPeer.CONNECTION_CONNECTED:
				_add_peer(int(data.get("id", 0)))
		"peer_left":
			var id := int(data.get("id", 0))
			if _peers.has(id):
				_peers.erase(id)
				_discard_packets_from(id)
				peer_disconnected.emit(id)
		"error", "closed":
			var reason := str(data.get("message", "无法进入房间，请重试。")).left(160)
			_fail(reason)
		_:
			_fail("联机服务版本不兼容，请刷新游戏页面。")

func _add_peer(id: int) -> void:
	if id < 1 or id > 2147483647 or id == _unique_id or _peers.has(id):
		return
	if _peers.size() >= 3:
		_fail("房间成员数量无效，请重新连接。")
		return
	_peers[id] = true
	peer_connected.emit(id)

func _handle_packet(packet: PackedByteArray) -> void:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED or packet.size() <= HEADER_SIZE or packet.size() > MAX_PACKET_BYTES + HEADER_SIZE:
		_fail("收到了无效联机数据。")
		return
	var source := packet.decode_s32(0)
	var mode := int(packet[4])
	var channel := int(packet[5])
	if not _peers.has(source) or mode > MultiplayerPeer.TRANSFER_MODE_RELIABLE or channel > 2 or (not _hosting and source != 1):
		_fail("收到了无效玩家数据。")
		return
	if _packets.size() >= MAX_QUEUED_PACKETS or _queued_bytes + packet.size() > MAX_QUEUED_BYTES:
		_fail("联机数据积压，请重新连接房间。")
		return
	var payload := packet.slice(HEADER_SIZE)
	_packets.append({"source": source, "mode": mode, "channel": channel, "data": payload})
	_queued_bytes += payload.size()

func _discard_packets_from(id: int) -> void:
	for index in range(_packets.size() - 1, -1, -1):
		if _packets[index].source == id:
			_queued_bytes -= _packets[index].data.size()
			_packets.remove_at(index)

func _fail(reason: String) -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	last_error = reason
	_close()
	failed.emit(reason)

func _get_packet_script() -> PackedByteArray:
	if _packets.is_empty():
		return PackedByteArray()
	var packet: Dictionary = _packets.pop_front()
	var payload: PackedByteArray = packet.data
	_queued_bytes -= payload.size()
	return payload

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED or _socket == null:
		return ERR_UNCONFIGURED
	if buffer.is_empty() or buffer.size() > MAX_PACKET_BYTES:
		return ERR_INVALID_PARAMETER
	if not _hosting and _target != 1:
		return ERR_UNAUTHORIZED
	if _target > 0 and not _peers.has(_target):
		return ERR_INVALID_PARAMETER
	if _channel < 0 or _channel > 2:
		return ERR_INVALID_PARAMETER
	var backlog := _socket.get_current_outbound_buffered_amount()
	if _mode != MultiplayerPeer.TRANSFER_MODE_RELIABLE and backlog >= UNRELIABLE_BACKLOG_BYTES:
		return OK
	if backlog + buffer.size() + HEADER_SIZE > MAX_OUTBOUND_BYTES:
		_fail("网络拥堵，房间已断开。请稍后重新连接。")
		return ERR_OUT_OF_MEMORY
	var packet := PackedByteArray()
	packet.resize(HEADER_SIZE)
	packet.encode_s32(0, _target)
	packet[4] = _mode
	packet[5] = _channel
	packet.append_array(buffer)
	var error := _socket.put_packet(packet)
	if error != OK:
		_fail("无法发送联机数据，请重新连接房间。")
	return error

func _close() -> void:
	_waiting_url=""
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	if _socket != null:
		_socket.close(1000, "left room")
		_socket = null
	_peers.clear()
	_packets.clear()
	_queued_bytes = 0
	_unique_id = 0
	_hello_sent = false

func _disconnect_peer(peer: int, _force: bool) -> void:
	if _hosting and _peers.has(peer):
		_send_control({"op": "kick", "id": peer})
	elif not _hosting and peer == 1:
		_close()

func _get_available_packet_count() -> int: return _packets.size()
func _get_max_packet_size() -> int: return MAX_PACKET_BYTES
func _get_packet_peer() -> int: return int(_packets[0].source) if not _packets.is_empty() else 0
func _get_packet_channel() -> int: return int(_packets[0].channel) if not _packets.is_empty() else 0
func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _packets[0].mode as MultiplayerPeer.TransferMode if not _packets.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _set_transfer_channel(channel: int) -> void: _channel = channel
func _get_transfer_channel() -> int: return _channel
func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void: _mode = mode
func _get_transfer_mode() -> MultiplayerPeer.TransferMode: return _mode
func _set_target_peer(peer: int) -> void: _target = peer
func _get_unique_id() -> int: return _unique_id
func _is_server() -> bool: return _hosting
func _get_connection_status() -> MultiplayerPeer.ConnectionStatus: return _status
func _is_server_relay_supported() -> bool: return false
func _set_refuse_new_connections(enable: bool) -> void: set_room_locked(enable)
func _is_refusing_new_connections() -> bool: return _refuse
