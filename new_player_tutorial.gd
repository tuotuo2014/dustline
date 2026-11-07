extends Node
## Guided practice uses real input and gameplay events. It never grants resources.
const Effects = preload("res://model_effects.gd")
const STEPS := ["welcome","move","look","run_jump","jump","loot","skill","survival","repel","shelter","mission","extraction"]
const VERSION := 1
var game: Node3D
var running := false
var seen := false
var queued := false
var step := 0
var step_id := ""
var preference_path := ""
var walked := 0.0
var sprinted := 0.0
var looked := 0.0
var jumped := false
var landed := false
var pickups_seen := 0
var skill_used := false
var target: Area3D
var marker: Node3D
var _last_position := Vector3.ZERO
var _last_view := Vector2.ZERO
var _ready_time := 0.0
var _display_clock := 0.0

func _ready() -> void:
	preference_path = str(game.profile.save_path) + ".tutorial.cfg"
	var config := ConfigFile.new()
	if config.load(preference_path)==OK:
		seen=int(config.get_value("tutorial","version",0))>=VERSION and bool(config.get_value("tutorial","dismissed",false))

func begin_round() -> void:
	end_round()
	if queued or (not seen and OS.get_environment("DUSTLINE_TUTORIAL_DISABLED")!="1"):
		start()

func start() -> void:
	if not game.active or game.round_over: return
	_clear_marker()
	running=true
	queued=false
	step=0
	step_id=STEPS[step]
	walked=0
	sprinted=0
	looked=0
	jumped=false
	landed=false
	pickups_seen=0
	skill_used=false
	_ready_time=0
	_last_position=game.player.global_position
	_last_view=Vector2(game.player.camera_yaw,game.player.camera_pitch)
	game._set_weather(false)
	_refresh()

func end_round() -> void:
	running=false
	_clear_marker()
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_tutorial({"visible":false})

func tick(delta: float) -> void:
	if not running or not game.active: return
	var player: CharacterBody3D=game.player
	var position_now := player.global_position
	var distance := Vector2(position_now.x-_last_position.x,position_now.z-_last_position.z).length()
	var view_now := Vector2(player.camera_yaw,player.camera_pitch)
	var camera_motion := absf(angle_difference(_last_view.x,view_now.x))+absf(view_now.y-_last_view.y)
	_last_position=position_now
	_last_view=view_now
	# Ignore teleports and round resets: a real step is bounded by movement speed.
	var moved := distance>.0001 and distance<maxf(.35,delta*25.0)
	if step_id=="move" and moved: walked+=distance
	if step_id=="look" and player.rotating_camera: looked+=camera_motion
	if step_id=="run_jump":
		if moved and Input.is_action_pressed("sprint") and Vector2(player.velocity.x,player.velocity.z).length()>player.speed+.5:
			sprinted+=distance
	if step_id=="jump":
		if not player.is_on_floor() and player.velocity.y>1.0: jumped=true
		if jumped and player.is_on_floor(): landed=true
	if step_id=="loot": _update_target()
	if _action_done():
		_ready_time+=delta
		if _ready_time>=.65:
			_next_step()
	else:
		_ready_time=0
	_display_clock+=delta
	if _display_clock>=.1:
		_display_clock=0
		_refresh()

func record_pickup() -> void:
	if running and game.active: pickups_seen+=1

func record_skill() -> void:
	if running and game.active: skill_used=true

func _action_done() -> bool:
	match step_id:
		"move": return walked>=4.0
		"look": return looked>=.24
		"run_jump": return sprinted>=2.0
		"jump": return landed
		"loot": return pickups_seen>0
		"skill": return skill_used
	return false

func advance() -> void:
	if not running or not game.active: return
	if step_id in ["welcome","survival","repel","shelter","mission","extraction"] or _action_done() or (step_id=="loot" and not _has_supplies()): _next_step()

func _has_supplies() -> bool:
	for item in game.pickups:
		if is_instance_valid(item) and not item.is_queued_for_deletion() and not item.get_meta("taken",false): return true
	return false

func _next_step() -> void:
	_clear_marker()
	if step>=STEPS.size()-1:
		_dismiss(false)
		return
	step+=1
	step_id=STEPS[step]
	_ready_time=0
	_last_position=game.player.global_position
	_last_view=Vector2(game.player.camera_yaw,game.player.camera_pitch)
	_refresh()

func skip() -> void:
	if running and game.active: _dismiss(true)

func _dismiss(skipped: bool) -> void:
	seen=true
	queued=false
	var config := ConfigFile.new()
	config.set_value("tutorial","version",VERSION)
	config.set_value("tutorial","dismissed",true)
	config.set_value("tutorial","completed",not skipped)
	var saved := config.save(preference_path+".tmp")==OK
	if saved: saved=DirAccess.rename_absolute(preference_path+".tmp",preference_path)==OK
	end_round()
	game.damage_grace=maxf(game.damage_grace,2.0)
	game._set_weather(game.storm_active)
	game._show_toast(("已跳过教程" if skipped else "新手教程完成")+" · 任务计时与狼群已恢复。菜单中可重新学习。"+(" 教程偏好未能保存，下次启动可能再次显示。" if not saved else ""),6.0)
	game._update_hud()

func _refresh() -> void:
	if not running: return
	var data := {"visible":true,"step":step+1,"total":STEPS.size(),"step_id":step_id,
		"title":"","body":"","keys":"","progress":0.0,"hint":"",
		"can_advance":false,"next_text":"我明白了，下一步","focus":"","pointer_label":"",
		"checklist":[],"image":"res://assets/tutorial/"+step_id+".svg"}
	match step_id:
		"welcome":
			data.title="从营地开始，一步一步学"
			data.body="先学移动与视角，再练习拾取和技能，最后认识生存与撤离。黄色箭头会指出需要看的地方。"
			data.keys="操作图 → 跟着做 → 完成后自动继续"
			data.hint="练习时狼群、任务计时和伤害暂停。你仍可自由移动、转动镜头。"
			data.checklist=["① 看清每步的操作图和按键", "② 按提示实际操作；说明页点击下一步", "③ 随时可跳过，菜单中可重新学习"]
			data.can_advance=true
			data.next_text="开始练习"
		"move":
			data.title="先试着向前走"
			data.body="在游戏画面中按住 W，沿空地走 4 米。松开按键就会停下，移动方向以镜头朝向为准。"
			data.keys="W 前进  /  S 后退  /  A 左移  /  D 右移"
			data.progress=minf(1.0,walked/4.0)
			data.checklist=["① 按住 W，也可以使用方向键", "② 在空地走动；碰到墙就换个方向", "③ 已走 %.1f / 4 米"%minf(walked,4.0)]
			data.hint="短按只走一小步；请按住移动键，直到进度完成。"
		"look":
			data.title="按住鼠标，环顾四周"
			data.body="把鼠标移到右侧空白游戏画面，按住左键并向左右拖动。右键用于开枪。松开后鼠标会恢复自由。"
			data.keys="按住左键 + 拖动  /  滚轮拉近、拉远"
			data.progress=minf(1.0,looked/.24)
			data.checklist=["① 鼠标移出教程卡片和界面按钮", "② 按住左键拖动，观察镜头转向", "③ 松开鼠标；Esc 也能释放鼠标"]
			data.hint="只移动鼠标不会转向，必须同时按住左键。"
			data.focus="look"
			data.pointer_label="在这片空白画面按住左键拖动"
		"run_jump":
			data.title="加快脚步，练习奔跑"
			data.body="先按住 W 移动，再保持按住 Shift。奔跑 2 米后，松开 Shift 就会恢复行走。"
			data.keys="Shift + W A S D  奔跑"
			data.progress=minf(sprinted/2.0,1.0)
			data.checklist=["① 先按住移动键", "② 同时按住 Shift，角色会加速", "③ 已奔跑 %.1f / 2 米"%minf(sprinted,2.0)]
			data.hint="只按 Shift 不会前进；两个按键要一起按。"
		"jump":
			data.title="起跳，再稳稳落地"
			data.body="站稳后轻按一次空格，然后松开。看角色起跳并落地；移动中也能跳过低矮障碍。"
			data.keys="空格  跳跃"
			data.progress=1.0 if landed else (.5 if jumped else 0.0)
			data.checklist=["✓ 已起跳" if jumped else "① 站在地面，轻按空格", "✓ 已安全落地" if landed else "② 松开空格，等待落地", "③ 以后可配合移动键跳跃"]
			data.hint="空中不能再次起跳；按住空格也不会连续跳跃。"
		"loot":
			_update_target()
			data.title="跟着金色箭头找物资"
			data.body="先转动镜头找到金色箭头，再走到指示环里的物资旁。距离足够近时会自动拾取，不用按 E。"
			data.keys="走近目标  自动拾取"
			data.progress=1.0 if pickups_seen>0 else 0.0
			data.checklist=["① 箭头在边缘时，先朝它转动镜头", "② 沿空地走近物资，绕开墙和障碍", "③ 零件用于修复；贵重物品进入背包"]
			data.hint=_target_hint()
			if is_instance_valid(target) and pickups_seen==0:
				data.world_target=target.global_position+Vector3(0,.6,0)
				data.pointer_label="走近拾取 · %d 米"%ceili(game.player.global_position.distance_to(target.global_position))
			if pickups_seen==0 and not _has_supplies():
				data.hint="本轮物资已经拾完，可以继续学习；新一轮行动会重新生成物资。"
				data.can_advance=true
				data.next_text="继续学习"
		"skill":
			var info: Dictionary=game.skills.status(game.player.character_id)
			data.title="使用你的专属技能"
			data.body="%s：%s" % [info.name,info.description]
			data.keys="C  施放技能 · 也可点击高亮按钮"
			data.progress=1.0 if skill_used else 0.0
			data.checklist=["① 观察右侧技能按钮是否就绪", "② 落地后按 C，或点击技能按钮", "③ 成功施放后会自动进入下一步"]
			data.hint="还需 %d 秒冷却，等待结束再试。"%ceili(info.cooldown) if not info.ready else "技能已就绪，现在可以试一次。"
			data.focus="skill"
			data.pointer_label="这里显示技能和冷却"
		"survival":
			data.title="看懂生命值与治疗"
			data.body="右上方绿色条是生命值。受伤后按 Q，消耗 1 个医疗包恢复 35 点生命；恢复不会超过生命上限。"
			data.keys="Q  治疗 · 说明页，无需消耗医疗包"
			data.checklist=["① 先看生命条是否减少", "② 确认医疗包数量大于 0", "③ 满血时按 Q 不会浪费医疗包"]
			data.hint="现在有练习保护，不需要故意受伤。记住操作后点击下一步。"
			data.can_advance=true
			data.focus="health"
			data.pointer_label="绿色生命条 · 受伤后用 Q 治疗"
		"repel":
			data.title="狼兽靠近，先拉开距离"
			data.body="看到狼兽头顶的感叹号时准备撤退。按 F 点亮信号，让附近狼兽退避，再沿空地奔跑离开。"
			data.keys="F  驱兽 · Shift + 移动  脱身"
			data.checklist=["① 先确认右上角的驱兽弹数量", "② 15 米内的狼兽会退避约 8 秒", "③ 免费驱兽弹用完后，每次需要 2 个零件"]
			data.hint="驱狼枪需先在营地购买并装备，带上弹药后按右键开火，K 切换倍镜。本步不要求消耗物资。"
			data.can_advance=true
			data.focus="stats"
			data.pointer_label="查看驱兽弹与零件数量"
		"shelter":
			data.title="用避难棚抵挡危险"
			data.body="按 B 会在角色前方搭建避难棚，需要 3 个零件。先站在平地，留出空位，再进入棚下避开沙暴和狼兽。"
			data.keys="B  建棚 · M / Esc  暂停"
			data.checklist=["① 收集至少 3 个零件", "② 落地，前方远离建筑和地图边缘", "③ 建好后走进棚内，已有营地也能庇护"]
			data.hint="建造失败不会扣零件。当前只需认识规则，不必实际搭建。"
			data.can_advance=true
			data.world_target=game.base.global_position+Vector3(0,2.0,0)
			data.pointer_label="营地也能提供庇护"
		"mission":
			data.title="弄清本轮任务"
			data.body=_mission_text()
			data.keys="E  修复信标 / 交付 · 说明页"
			data.checklist=["① 零件和贵重物品用途不同", "② 每座信标需要 2 个零件，靠近按 E", "③ 满足本轮条件后才可以成功撤离"]
			data.hint="绿色光柱是出口；无线电设备是信标。箭头只指方向，遇到障碍需要绕行。"
			data.can_advance=true
			if game.mode==1:
				data.focus="stats"
				data.pointer_label="限时撤离需要 6 个零件"
			else:
				var closest: Node3D=null
				var distance := INF
				for relay in game.relays:
					if relay.get_meta("active",false): continue
					var d: float=relay.global_position.distance_squared_to(game.player.global_position)
					if d<distance: distance=d; closest=relay
				if is_instance_valid(closest):
					data.world_target=closest.global_position+Vector3(0,2.0,0)
					data.pointer_label="无线电信标 · 靠近按 E 修复"
		"extraction":
			data.title="找到出口，把战利品带回家"
			data.body=_mission_text()+" 认准绿色光柱，满足条件后靠近按 E。"
			data.keys="E  交付 / 撤离"
			data.checklist=["① 沿箭头方向寻找绿色光柱", "② 确认条件已满足，走到撤离点旁", "③ 按 E 成功撤离后，背包资产才会存入营地"]
			data.hint="背包物品未存入资产前，失败会丢失。点击下方按钮后，狼群和任务计时恢复。"
			data.can_advance=true
			data.next_text="我准备好了，开始行动"
			data.world_target=game.extraction.global_position+Vector3(0,5,0)
			data.pointer_label="绿色光柱 · %d 米"%ceili(game.player.global_position.distance_to(game.extraction.global_position))
	if _action_done():
		data.hint="✓ 完成！正在进入下一项…"
		data.progress=1.0
	game.hud.set_tutorial(data)

func _mission_text() -> String:
	match game.mode:
		1: return "本轮是限时撤离：180 秒内收集至少 6 个零件，再前往撤离点。"
		2: return "本轮是废土生存：坚持 120 秒并修复 2 座信标，再回营地或撤离点交付。"
	return "本轮是探索收集：每座信标消耗 2 个零件，修复 3 座后回营地或撤离点交付。"

func _update_target() -> void:
	if pickups_seen>0: return
	if is_instance_valid(target) and not target.is_queued_for_deletion() and not target.get_meta("taken",false): return
	_clear_marker()
	var best := INF
	for item in game.pickups:
		if not is_instance_valid(item) or item.is_queued_for_deletion() or item.get_meta("taken",false): continue
		var distance: float=game.player.global_position.distance_squared_to(item.global_position)
		if distance<best:
			best=distance
			target=item
	if not is_instance_valid(target): return
	marker=Node3D.new()
	marker.name="TutorialSupplyMarker"
	marker.position=target.global_position
	game.add_child(marker)
	for i in 4:
		Effects.mesh_node(marker,"SupplyApproachArc%d"%i,Effects.band(.72,.07,.15,12,1.15,float(i)*TAU/4),Effects.material(Color("efb365"),2,.8))
	var label := Label3D.new()
	label.font=preload("res://assets/fonts/NotoSansSC.ttf")
	label.text="↓ 新手指引：走近拾取"
	label.font_size=36
	label.pixel_size=.0028
	label.position.y=1.3
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=true
	label.modulate=Color("ffd392")
	marker.add_child(label)

func _target_hint() -> String:
	if not is_instance_valid(target): return "附近的任意一件物资都可以；无需按键。"
	var offset: Vector3=target.global_position-game.player.global_position
	var angle := wrapf(atan2(-offset.x,-offset.z)-game.player.camera_yaw,-PI,PI)
	var direction: String=["↑ 前方","↖ 左前","← 左侧","↙ 左后","↓ 后方","↘ 右后","→ 右侧","↗ 右前"][posmod(roundi(angle/(PI/4)),8)]
	return "目标物资：%s %d 米 · 也可以拾取沿途其他物资。" % [direction,roundi(Vector2(offset.x,offset.z).length())]

func _clear_marker() -> void:
	if is_instance_valid(marker): marker.queue_free()
	marker=null
	target=null
