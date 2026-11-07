extends SceneTree
const Invite = preload("res://coop_invite.gd")
const Discovery = preload("res://coop_discovery.gd")
var failed := 0
var checks := 0
class Session extends Node:
	const PROTOCOL := 1
	var host_port := 24567
	var members := {1:{"name":"真人房主"}}
	var room_region := 2
	var in_round := false
	var _loading := false
	func is_host() -> bool: return true
	func clean_name(value: String) -> String: return value.strip_edges().left(16)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		print("FAIL ",label)
func run() -> void:
	for host in ["192.168.1.22","127.0.0.1","play.example.com","::1","2001:db8::5"]:
		check(Invite.parse(Invite.format_address(host,32123))=={"address":host,"port":32123},"invitation roundtrip "+host)
	check(Invite.parse(" 192.168.1.22 ",25001).port==25001,"plain address preserves chosen port")
	check(Invite.parse("192.168.1.22:25002").port==25002,"endpoint port wins")
	for invalid in ["","dustline://","abc:0","abc:65536","abc:hi","abc:","[::1]:","[::1]garbage","http://example.com","abc/path","a b","a\nb","host..name"]:
		check(Invite.parse(invalid).is_empty(),"reject malformed invitation: "+invalid)
	var session := Session.new()
	root.add_child(session)
	var host := Discovery.new()
	host.session=session
	host.listen_port=39000+OS.get_process_id()%5000
	root.add_child(host)
	host.advertise()
	check(host._server!=null,"advertising socket opens")
	var browser := Discovery.new()
	browser.session=session
	browser.listen_port=host.listen_port
	root.add_child(browser)
	browser.browse(true)
	var deadline := Time.get_ticks_msec()+4000
	while browser.rooms.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(browser.rooms.size()==1,"real UDP request yields one deduplicated room")
	if not browser.rooms.is_empty():
		var room: Dictionary=browser.rooms.values()[0]
		check(room.name=="真人房主" and room.port==24567 and room.count==1,"real advertised room metadata")
		check(room.address.is_valid_ip_address(),"address comes from UDP source")
	var original := browser.rooms.duplicate(true)
	for bad in [null,[],{"magic":"wrong"},{"magic":Discovery.MAGIC,"query":browser._nonce,"version":1,"id":5}]:
		browser.accept_reply(bad,"127.0.0.1")
	check(browser.rooms==original,"malformed packets cannot create players or rooms")
	var packet := {"magic":Discovery.MAGIC,"query":browser._nonce,"version":1,"id":"bad","name":"test","port":24567,"count":1,"region":0,"playing":false}
	for field in ["port","count","region"]:
		var bad := packet.duplicate()
		bad[field]=-1
		browser.accept_reply(bad,"127.0.0.1")
	check(not browser.rooms.has("bad"),"out-of-range room data rejected")
	session.in_round=true
	browser.probe()
	await create_timer(.5).timeout
	check(not browser.rooms.is_empty() and browser.rooms.values()[0].playing,"rooms report ongoing expedition")
	host.stop_advertising()
	await create_timer(.3).timeout
	for id in browser.rooms: browser.rooms[id].seen=Time.get_ticks_msec()-Discovery.TTL_MS-1
	await create_timer(.2).timeout
	check(browser.rooms.is_empty(),"closed rooms expire")
	browser.browse(false)
	check(browser._browser==null and browser.rooms.is_empty(),"hidden lobby stops browsing and releases socket")
	print("COOP INVITES ",checks," checks; ",failed," failures")
	quit(1 if failed else 0)
