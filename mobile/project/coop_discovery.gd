extends Node
## Nearby-room discovery only. Game traffic continues over the existing ENet connection.
const DISCOVERY_PORT := 24568
const MAGIC := "dustline-nearby-v1"
const TTL_MS := 6500
var session: Node
var rooms: Dictionary = {}
var browsing := false
var status := ""
var listen_port := DISCOVERY_PORT
var _server: PacketPeerUDP
var _browser: PacketPeerUDP
var _nonce := ""
var _room_id := ""
var _clock := 0.0
var _probe_clock := 0.0

func advertise() -> void:
	stop_advertising()
	_server=PacketPeerUDP.new()
	if _server.bind(listen_port,"0.0.0.0")!=OK:
		_server.close()
		_server=null
		status="附近房间广播不可用，仍可复制邀请地址让朋友加入。"
		return
	_room_id=str(Time.get_ticks_usec())+"-"+str(randi())
	status="房间已在同一局域网内显示。"

func stop_advertising() -> void:
	if _server!=null: _server.close()
	_server=null

func browse(value: bool) -> void:
	if browsing==value: return
	browsing=value
	rooms.clear()
	if _browser!=null: _browser.close()
	_browser=null
	if not value: return
	_browser=PacketPeerUDP.new()
	if _browser.bind(0,"0.0.0.0")!=OK:
		_browser.close()
		_browser=null
		browsing=false
		status="无法搜索附近房间，请使用邀请地址。"
		return
	_browser.set_broadcast_enabled(true)
	_nonce=str(randi())+str(Time.get_ticks_usec())
	status="正在搜索同一 Wi-Fi / 局域网中的房间…"
	probe()

func probe() -> void:
	if _browser==null: return
	_probe_clock=0
	var packet := JSON.stringify({"magic":MAGIC,"query":_nonce}).to_utf8_buffer()
	for ip in ["255.255.255.255","127.0.0.1"]:
		_browser.set_dest_address(ip,listen_port)
		_browser.put_packet(packet)

func _process(delta: float) -> void:
	_clock+=delta
	_probe_clock+=delta
	if _clock<.1: return
	_clock=0
	if _server!=null and is_instance_valid(session) and session.is_host():
		for i in mini(_server.get_available_packet_count(),16):
			var bytes := _server.get_packet()
			var ip := _server.get_packet_ip()
			var reply_port := _server.get_packet_port()
			if bytes.size()>1024: continue
			var query: Variant=JSON.parse_string(bytes.get_string_from_utf8())
			if not query is Dictionary or query.get("magic")!=MAGIC: continue
			if not query.get("query") is String or query.query.length()>64: continue
			if not session.members.has(1): continue
			var response := {"magic":MAGIC,"query":query.query,"id":_room_id,"version":session.PROTOCOL,
				"name":session.members[1].name,"port":session.host_port,"count":session.members.size(),
				"region":session.room_region,"playing":session.in_round or session._loading}
			_server.set_dest_address(ip,reply_port)
			_server.put_packet(JSON.stringify(response).to_utf8_buffer())
	if _browser==null: return
	if _probe_clock>=2.0: probe()
	for i in mini(_browser.get_available_packet_count(),32):
		var bytes := _browser.get_packet()
		var ip := _browser.get_packet_ip()
		if bytes.size()>1024: continue
		accept_reply(JSON.parse_string(bytes.get_string_from_utf8()),ip)
	var now := Time.get_ticks_msec()
	for id in rooms.keys():
		if now-int(rooms[id].seen)>TTL_MS: rooms.erase(id)

func accept_reply(data: Variant, ip: String) -> void:
	if not data is Dictionary or data.get("magic")!=MAGIC or data.get("query")!=_nonce: return
	if data.get("version")!=session.PROTOCOL: return
	if not data.get("id") is String or data.id.is_empty() or data.id.length()>80: return
	if not data.get("name") is String or not data.get("playing") is bool: return
	for key in ["port","count","region"]:
		if not (data.get(key) is float or data.get(key) is int): return
		if float(data[key])!=floor(float(data[key])): return
	if data.port<1024 or data.port>65535 or data.count<1 or data.count>4 or data.region<0 or data.region>3: return
	# On one computer both probes may reach the host; prefer its LAN address.
	if ip.begins_with("127.") and rooms.has(data.id) and not str(rooms[data.id].address).begins_with("127."):
		rooms[data.id].seen=Time.get_ticks_msec()
		return
	rooms[data.id]={"id":data.id,"name":session.clean_name(data.name),"address":ip,"port":int(data.port),
		"count":int(data.count),"region":int(data.region),"playing":data.playing,"seen":Time.get_ticks_msec()}

func _exit_tree() -> void:
	stop_advertising()
	if _browser!=null: _browser.close()
