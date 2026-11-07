extends Control
var game: Node3D
var nickname: LineEdit
var address: LineEdit
var port: SpinBox
var roster: Label
var notice: Label
var host_button: Button
var join_button: Button
var ready_button: Button
var start_button: Button
var leave_button: Button
var region_picker: OptionButton
var mode_picker: OptionButton
var nearby_section: VBoxContainer
var nearby_picker: OptionButton
var nearby_join: Button
var nearby_status: Label
var invite_section: VBoxContainer
var invite_picker: OptionButton
var invite_status: Label
var slots_title: Label
var transport_hint: Label
var internet_toggle: CheckButton
var endpoint: LineEdit
var endpoint_row: HBoxContainer
var invite_title: Label
var invite_copy: Button
var code_copy: Button
var input_buttons: Array[Button]=[]
var _nearby_signature := ""
var _clock := 0.0
var _clipboard_pending := false
var _clipboard_serial := 0
var _clipboard_value := ""
var _clipboard_success := ""
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(.015,.025,.03,.96)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left=36
	scroll.offset_right=-36
	scroll.offset_top=24
	scroll.offset_bottom=-24
	var center := CenterContainer.new()
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x=660
	column.add_theme_constant_override("separation",12)
	center.add_child(column)
	add_label(column,"真人联机  /  荒原小队",30)
	add_label(column,"2–4 位真人协作 · 共同拾荒、抵御狼群、救援与撤离",17)
	add_label(column,"① 创建或加入房间    →    ② 队员点击准备    →    ③ 房主开始行动",16)
	transport_hint=add_label(column,"",14)
	internet_toggle=CheckButton.new()
	internet_toggle.text="互联网组队 · 使用手机游戏网址"
	internet_toggle.visible=not OS.has_feature("web")
	column.add_child(internet_toggle)
	endpoint_row=HBoxContainer.new()
	column.add_child(endpoint_row)
	endpoint=LineEdit.new()
	endpoint.placeholder_text="粘贴朋友打开的 HTTPS 游戏网址"
	endpoint.max_length=300
	endpoint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	endpoint_row.add_child(endpoint)
	internet_toggle.toggled.connect(func(_value):
		if not internet_toggle.button_pressed: game.coop.relay_url=""
		_refresh_transport()
	)
	var row := HBoxContainer.new()
	column.add_child(row)
	nickname=LineEdit.new()
	nickname.placeholder_text="你的昵称"
	nickname.text="幸存者"
	nickname.max_length=16
	nickname.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(nickname)
	if OS.has_feature("web"):
		input_buttons.append(button(row,"输入昵称",func(): _browser_input(nickname,"输入你的昵称")))
	address=LineEdit.new()
	address.placeholder_text="房主 IP / 粘贴邀请地址"
	address.max_length=300
	address.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(address)
	if OS.has_feature("web"):
		input_buttons.append(button(row,"输入房间码",func(): _browser_input(address,"输入朋友发来的 6 位房间码或完整邀请链接")))
	port=SpinBox.new()
	port.min_value=1024
	port.max_value=65535
	port.value=24567
	row.add_child(port)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	host_button=button(buttons,"创建房间",_create_room)
	join_button=button(buttons,"加入房间",_join_room)
	leave_button=button(buttons,"离开房间",func(): game.coop.leave_room("已离开房间"))
	nearby_section=VBoxContainer.new()
	column.add_child(nearby_section)
	add_label(nearby_section,"附近的真人房间 · 同一 Wi-Fi / 局域网",17)
	var nearby_row := HBoxContainer.new()
	nearby_section.add_child(nearby_row)
	nearby_picker=OptionButton.new()
	nearby_picker.custom_minimum_size.x=370
	nearby_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	nearby_row.add_child(nearby_picker)
	nearby_join=button(nearby_row,"加入所选房间",join_nearby)
	nearby_picker.item_selected.connect(func(index): nearby_join.disabled=nearby_picker.is_item_disabled(index))
	button(nearby_row,"刷新",func(): game.coop.discovery.probe())
	nearby_status=add_label(nearby_section,"正在搜索…",14)
	invite_section=VBoxContainer.new()
	column.add_child(invite_section)
	invite_title=add_label(invite_section,"邀请朋友 · 复制地址发给朋友，在加入栏粘贴",17)
	var invite_row := HBoxContainer.new()
	invite_section.add_child(invite_row)
	invite_picker=OptionButton.new()
	invite_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	invite_row.add_child(invite_picker)
	invite_copy=button(invite_row,"复制邀请地址",copy_invite)
	code_copy=button(invite_row,"复制房间码",func():
		_copy_text(game.coop.room_code,"房间码已复制。请让朋友打开同一个游戏网址，在真人联机中输入房间码。")
		refresh()
	)
	invite_status=add_label(invite_section,"",14)
	slots_title=add_label(column,"小队席位 · 尚未加入房间",17)
	roster=add_label(column,"尚未连接房间",19)
	roster.custom_minimum_size.y=100
	var settings := HBoxContainer.new()
	column.add_child(settings)
	region_picker=OptionButton.new()
	region_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for item in game.Layout.REGIONS: region_picker.add_item(item.name)
	settings.add_child(region_picker)
	mode_picker=OptionButton.new()
	mode_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for item in game.MODE_NAMES: mode_picker.add_item(item)
	settings.add_child(mode_picker)
	region_picker.item_selected.connect(func(_id): game.coop.change_settings(region_picker.selected,mode_picker.selected))
	mode_picker.item_selected.connect(func(_id): game.coop.change_settings(region_picker.selected,mode_picker.selected))
	var actions := HBoxContainer.new()
	column.add_child(actions)
	ready_button=button(actions,"准备 / 取消准备",func(): game.coop.toggle_ready())
	start_button=button(actions,"房主开始行动",func(): game.coop.start_expedition(region_picker.selected,mode_picker.selected))
	button(actions,"返回游戏 / 菜单",func(): hide())
	notice=add_label(column,"",16)
	notice.modulate=Color("eec384")
	notice.custom_minimum_size.y=54
	add_label(column,"队伍共享零件、医疗包和战利品；生命与技能独立。倒下后可由队友靠近点“互动”救起。\n全部倒下则行动失败；一人满足条件即可触发全队撤离。联机时请保持游戏在前台，菜单不会暂停世界。\n房间仅由实际连接的玩家组成，不会补入机器人。联机战利品仅计入本次小队战绩。",15)
	visibility_changed.connect(func():
		if is_instance_valid(game.coop): game.coop.discovery.browse(visible and not _internet_selected() and not game.coop.enabled and not game.coop.connecting)
	)
	_refresh_transport()
	if OS.has_feature("web"):
		var invited: Variant=JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room') || ''")
		if invited is String and not invited.is_empty(): address.text=invited.strip_edges().to_upper().left(6)
	hide()

func _internet_selected() -> bool:
	return OS.has_feature("web") or internet_toggle.button_pressed

func _refresh_transport() -> void:
	var online := _internet_selected()
	endpoint_row.visible=online and not OS.has_feature("web")
	port.visible=not online
	address.placeholder_text="6 位房间码 / 完整邀请链接" if online else "房主 IP / 粘贴邀请地址"
	address.max_length=300
	transport_hint.text="朋友打开同一个游戏网址，输入房间码即可加入 · 2–4 位真人一起行动" if online else "同一 Wi-Fi 自动找房；与外地朋友组队时，开启上方“互联网组队”"

func _normalized_endpoint(value: String) -> String:
	var site := value.strip_edges().trim_suffix("/")
	if site.begins_with("https://"): site="wss://"+site.trim_prefix("https://")
	if not site.begins_with("wss://"): return ""
	var authority := site.trim_prefix("wss://").get_slice("/",0).get_slice("?",0).get_slice("#",0)
	if authority.is_empty() or "@" in authority or " " in authority: return ""
	return "wss://"+authority+"/multiplayer"

func _prepare_transport() -> bool:
	if OS.has_feature("web"): return true
	if not internet_toggle.button_pressed:
		game.coop.relay_url=""
		return true
	var url := _normalized_endpoint(endpoint.text)
	if url.is_empty():
		game.coop.message="请先粘贴完整的 HTTPS 游戏网址，让队友连接同一个站点。"
		refresh()
		return false
	game.coop.relay_url=url
	return true

func _create_room() -> void:
	if _prepare_transport(): game.coop.host_room(nickname.text,int(port.value))
	refresh()

func _join_room() -> void:
	# Preserve the URL's lowercase query name; the session validates and extracts its code.
	address.text=address.text.strip_edges()
	if not OS.has_feature("web") and _internet_selected() and endpoint.text.strip_edges().is_empty() and address.text.begins_with("https://"):
		endpoint.text=address.text
	if not _prepare_transport(): return
	game.coop.join_room(nickname.text,address.text,int(port.value))
	refresh()

func _browser_input(field: LineEdit, caption: String) -> void:
	if not OS.has_feature("web") or not field.editable: return
	var value: Variant=JavaScriptBridge.eval("window.prompt(%s,%s)"%[JSON.stringify(caption),JSON.stringify(field.text)])
	if value is String:
		field.text=value.left(field.max_length)
		if field==address: field.text=field.text.strip_edges()

func _copy_text(value: String, success_message: String) -> void:
	if OS.has_feature("web"):
		_clipboard_serial+=1
		_clipboard_pending=true
		_clipboard_value=value
		_clipboard_success=success_message
		game.coop.message="正在复制邀请信息…"
		JavaScriptBridge.eval("""(() => {
			const serial = %d;
			const value = %s;
			window.__dustlineClipboardResult = { serial, status: 'pending' };
			const finish = status => {
				if (window.__dustlineClipboardResult.serial === serial) window.__dustlineClipboardResult.status = status;
			};
			if (!navigator.clipboard || !navigator.clipboard.writeText) { finish('denied'); return; }
			navigator.clipboard.writeText(value).then(() => finish('ok'), () => finish('denied'));
		})();"""%[_clipboard_serial,JSON.stringify(value)])
		return
	DisplayServer.clipboard_set(value)
	game.coop.message=success_message if DisplayServer.clipboard_get()==value else "未能自动复制。请手动记录房间码："+game.coop.room_code

func _poll_clipboard() -> void:
	if not _clipboard_pending: return
	var result: Variant=JavaScriptBridge.eval("window.__dustlineClipboardResult && window.__dustlineClipboardResult.serial === %d ? window.__dustlineClipboardResult.status : 'pending'"%_clipboard_serial)
	if result=="ok":
		_clipboard_pending=false
		game.coop.message=_clipboard_success
	elif result=="denied":
		_clipboard_pending=false
		game.coop.message="浏览器未允许自动复制。请在弹窗中长按文字手动复制；房间码："+game.coop.room_code
		JavaScriptBridge.eval("window.prompt('请长按下方邀请文字复制',%s)"%JSON.stringify(_clipboard_value))

func _share_url() -> String:
	var base := ""
	if OS.has_feature("web"):
		var origin: Variant=JavaScriptBridge.eval("window.location.origin + window.location.pathname")
		if origin is String: base=origin
	else:
		base=game.coop.relay_url.replace("wss://","https://").trim_suffix("/multiplayer")+"/"
	return base+"?room="+game.coop.room_code.uri_encode()
func add_label(parent: Node, value: String, font_size: int) -> Label:
	var node := Label.new()
	node.text=value
	node.add_theme_font_size_override("font_size",font_size)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node
func button(parent: Node, value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text=value
	node.custom_minimum_size.y=42
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size",17)
	node.pressed.connect(action)
	parent.add_child(node)
	return node
func open() -> void:
	show()
	refresh()
func _process(delta: float) -> void:
	if not visible: return
	_clock+=delta
	if _clock>.2:
		_clock=0
		_poll_clipboard()
		refresh()
func refresh() -> void:
	if not is_instance_valid(game.coop): return
	var net: Node=game.coop
	var online := _internet_selected()
	net.discovery.browse(visible and not online and not net.enabled and not net.connecting)
	nearby_section.visible=not online and not net.enabled and not net.connecting
	invite_section.visible=net.is_host()
	if nearby_section.visible: refresh_nearby()
	if invite_section.visible: refresh_invites()
	notice.text=net.message
	slots_title.text="小队席位 · %d / 4 位真人已连接"%net.members.size() if net.enabled else "小队席位 · 尚未加入房间"
	if net.enabled and online and not str(net.room_code).is_empty(): slots_title.text+="  ·  房间 "+net.room_code
	var lines: Array[String]=[]
	for id in net.members:
		var member: Dictionary=net.members[id]
		lines.append("%s  %s%s  ·  %s%s"%["★ 房主" if id==1 else "● 队员",member.name,"（你）" if id==net.local_id() else "",game.player.CharacterCatalog.get_info(member.character).name,"  · 已准备" if member.ready else "  · 未准备"])
	for i in range(net.members.size(),4): lines.append("◇  席位 %d  ·  等待真人加入"%(i+1))
	roster.text="\n".join(lines)
	if net.enabled:
		region_picker.select(net.room_region)
		mode_picker.select(net.room_mode)
	nickname.editable=not net.enabled and not net.connecting
	address.editable=not net.enabled and not net.connecting
	port.editable=not net.enabled and not net.connecting
	internet_toggle.disabled=net.enabled or net.connecting
	endpoint.editable=not net.enabled and not net.connecting
	for input_button in input_buttons: input_button.disabled=net.enabled or net.connecting
	host_button.disabled=net.enabled or net.connecting
	join_button.disabled=net.enabled or net.connecting
	leave_button.disabled=not net.enabled and not net.connecting
	ready_button.disabled=not net.enabled or net.in_round
	start_button.disabled=not net.is_host() or net.in_round or net._loading or net.members.size()<2 or not net.members.values().all(func(m): return m.ready)
	start_button.text="等待真人队友加入" if net.is_host() and net.members.size()<2 else "房主开始行动"
	ready_button.text="取消准备" if net.members.has(net.local_id()) and net.members[net.local_id()].ready else "我已准备"
	region_picker.disabled=not net.is_host() or net.in_round
	mode_picker.disabled=not net.is_host() or net.in_round

func refresh_nearby() -> void:
	var discovery: Node=game.coop.discovery
	var signature := ""
	for id in discovery.rooms:
		var room: Dictionary=discovery.rooms[id]
		signature+="%s|%s|%s|%d|%d|%s;"%[id,room.name,room.address,room.port,room.count,room.playing]
	nearby_status.text="未找到时可直接粘贴邀请地址；访客 Wi-Fi 的设备隔离可能阻止搜索。" if discovery.rooms.is_empty() else "发现 %d 个真实房间；列表自动刷新。"%discovery.rooms.size()
	if not discovery.browsing: nearby_status.text=discovery.status
	if signature==_nearby_signature and nearby_picker.item_count>0: return
	_nearby_signature=signature
	var selected := str(nearby_picker.get_selected_metadata()) if nearby_picker.selected>=0 else ""
	nearby_picker.clear()
	for id in discovery.rooms:
		var room: Dictionary=discovery.rooms[id]
		var state := "行动中" if room.playing else ("已满" if room.count>=4 else "可加入")
		nearby_picker.add_item("%s的小队 · %d/4 · %s"%[room.name,room.count,state])
		var index := nearby_picker.item_count-1
		nearby_picker.set_item_metadata(index,id)
		nearby_picker.set_item_disabled(index,room.playing or room.count>=4)
		if str(id)==selected: nearby_picker.select(index)
	if nearby_picker.item_count==0:
		nearby_picker.add_item("暂无房间 · 请让朋友先创建房间")
		nearby_picker.set_item_disabled(0,true)
	if nearby_picker.selected<0 or nearby_picker.is_item_disabled(nearby_picker.selected):
		for index in nearby_picker.item_count:
			if not nearby_picker.is_item_disabled(index):
				nearby_picker.select(index)
				break
	nearby_join.disabled=nearby_picker.selected<0 or nearby_picker.is_item_disabled(nearby_picker.selected)

func join_nearby() -> void:
	if nearby_picker.selected<0: return
	var id: Variant=nearby_picker.get_selected_metadata()
	if not game.coop.discovery.rooms.has(id): return
	var room: Dictionary=game.coop.discovery.rooms[id]
	if room.playing or room.count>=4: return
	address.text=room.address
	port.value=room.port
	game.coop.join_room(nickname.text,room.address,room.port)
	refresh()

func refresh_invites() -> void:
	var online := _internet_selected()
	code_copy.visible=online
	invite_picker.visible=not online
	invite_copy.text="复制邀请链接" if online else "复制邀请地址"
	if online:
		invite_title.text="邀请朋友 · 房间码 "+game.coop.room_code
		invite_picker.clear()
		invite_picker.add_item("房间码  "+game.coop.room_code)
		invite_picker.set_meta("port",0)
		invite_status.text="把链接或房间码发给朋友；朋友进入真人联机并点击准备后，房主即可开始。"
		return
	invite_title.text="邀请朋友 · 复制地址发给朋友，在加入栏粘贴"
	if invite_picker.item_count==0 or int(invite_picker.get_meta("port",0))!=game.coop.host_port:
		invite_picker.clear()
		for ip in game.coop.Invite.local_addresses(): invite_picker.add_item(game.coop.Invite.format_address(ip,game.coop.host_port))
		invite_picker.set_meta("port",game.coop.host_port)
	invite_status.text=game.coop.discovery.status+" 跨网络需使用可达地址；此邀请不提供公网中转。"

func copy_invite() -> void:
	if _internet_selected():
		_copy_text(_share_url(),"邀请链接已复制。朋友打开链接后，进入真人联机，房间码会自动填好。")
		refresh()
		return
	if invite_picker.selected<0: return
	_copy_text(invite_picker.get_item_text(invite_picker.selected),"邀请地址已复制。发给朋友后，让对方粘贴到加入栏；同一 Wi-Fi 也可直接搜索房间。")
	refresh()
