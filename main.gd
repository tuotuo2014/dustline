extends Node3D

const Effects = preload("res://model_effects.gd")
const Tutorial = preload("res://new_player_tutorial.gd")
const Profile = preload("res://economy_profile.gd")
const ExpeditionEconomy = preload("res://expedition_economy.gd")
const Firearm = preload("res://salvage_firearm.gd")
const Skills = preload("res://survivor_skills.gd")
const Props = preload("res://wasteland_interactables.gd")
const Mutant = preload("res://mutant_controller.gd")
const Layout = preload("res://world_layout.gd")
enum Mode { EXPLORE, EXTRACTION, SURVIVAL }
const MODE_NAMES := ["探索收集", "限时撤离", "废土生存"]
const EXTRACTION_LIMIT := 180.0
const SURVIVAL_TIME := 120.0
const BASE_POSITION := Layout.BASE
const EXIT_POSITION := Layout.EXIT
const RELAY_POSITIONS := Layout.RELAYS
const LOOT_POSITIONS := [Vector3(-5,0,18),Vector3(-8,0,23),Vector3(-14,0,17),
	Vector3(-18,0,4),Vector3(-21,0,-6),Vector3(-27,0,-15),Vector3(-32,0,-25),
	Vector3(-19,0,-30),Vector3(-13,0,-40),Vector3(0,0,-43),Vector3(7,0,-51),
	Vector3(13,0,-40),Vector3(23,0,-36),Vector3(30,0,-28),Vector3(38,0,-22),
	Vector3(37,0,-9),Vector3(33,0,5),Vector3(29,0,19),Vector3(22,0,30),
	Vector3(12,0,37),Vector3(-6,0,40),Vector3(-18,0,36),Vector3(-29,0,32),
	Vector3(-36,0,22),Vector3(-38,0,6),Vector3(5,0,29),Vector3(1,0,-12),
	# Supply trails link the old camp to the district outskirts.
	Vector3(-46,0,-30),Vector3(-59,0,-45),Vector3(-68,0,-58),
	Vector3(-77,0,-74),Vector3(-73,0,-72),Vector3(-79,0,-68),
	Vector3(49,0,-39),Vector3(64,0,-49),Vector3(81,0,-61),
	Vector3(102,0,-88),Vector3(108,0,-87),Vector3(109,0,-82),
	Vector3(-44,0,48),Vector3(-59,0,68),Vector3(-60,0,90),
	Vector3(-86,0,109),Vector3(-81,0,110),Vector3(-78,0,104),
	Vector3(-4,0,-66),Vector3(4,0,-87),Vector3(-3,0,-108),
	Vector3(4,0,-129),Vector3(2,0,-175),Vector3(10,0,-178),
	Vector3(40,0,45),Vector3(63,0,65),Vector3(82,0,82),
	Vector3(102,0,100),Vector3(119,0,143),Vector3(125,0,142),
	Vector3(-147,0,-33),Vector3(-128,0,124),Vector3(160,0,84),Vector3(142,0,-125)]
const MEDKIT_POSITIONS := [Vector3(-14,0,-12),Vector3(28,0,-18),Vector3(-22,0,28),Vector3(1,0,-36),
	Vector3(-74,0,-67),Vector3(107,0,-80),Vector3(-85,0,103),Vector3(9,0,-172),Vector3(115,0,142)]
const MONSTER_POSITIONS := [Vector3(-53,0,-48),Vector3(78,0,-58),Vector3(-62,0,82),Vector3(25,0,-124),Vector3(97,0,97)]
var coop: Node
var profile = Profile.new()
var expedition = ExpeditionEconomy.new()
var arsenal: Node3D
var tutorial: Node
var round_ammo := 0
var max_health := 100.0
var _pending_settlement: Dictionary = {}
var _last_result: Dictionary = {}
var world: Node3D
var skills: Node3D
var round_root: Node3D
var region_id := 0
var region: Dictionary = Layout.expedition(0)
var _selected_region := 0
var _resource_slots: Array[Vector3]=[]
var mode := Mode.EXPLORE
var active := false
var round_started := false
var round_over := false
var won := false
var health := 100.0
var scrap := 0
var collected := 0
var total := 0
var medkits := 2
var flares := 1
var elapsed := 0.0
var storm_active := false
var repaired := 0
var shelters: Array[Node3D] = []
var relays: Array[Node3D] = []
var pickups: Array[Area3D] = []
var mutants: Array[CharacterBody3D] = []
var flare_nodes: Array[Node3D] = []
var base: Node3D
var extraction: Node3D
var extraction_points: Array[Node3D]=[]
var _nav: Control
var toast := ""
var toast_remaining := 0.0
var damage_grace := 0.0
var _hud_clock := 0.0
var _repel_cooldown := 0.0
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $UI

func _ready() -> void:
	var render_budget := preload("res://render_budget.gd").new()
	render_budget.name="RenderBudget"
	add_child(render_budget)
	skills = Skills.new()
	skills.name = "SurvivorSkills"
	skills.game = self
	add_child(skills)
	arsenal = Firearm.new()
	arsenal.name = "SalvageFirearm"
	arsenal.game = self
	add_child(arsenal)
	tutorial=Tutorial.new()
	tutorial.name="NewPlayerTutorial"
	tutorial.game=self
	add_child(tutorial)
	hud.tutorial_next_requested.connect(tutorial.advance)
	hud.tutorial_skip_requested.connect(tutorial.skip)
	hud.tutorial_replay_requested.connect(_replay_tutorial)
	hud.abandon_requested.connect(abandon_expedition)
	hud.upgrade_requested.connect(_upgrade_character)
	hud.purchase_requested.connect(_purchase_equipment)
	hud.equip_requested.connect(_equip_equipment)
	hud.skill_requested.connect(use_character_skill)
	hud.region_selected.connect(_on_region_selected)
	hud.mode_selected.connect(start_mode)
	hud.character_selected.connect(_on_character_selected)
	hud.resume_requested.connect(resume_game)
	hud.restart_requested.connect(restart_game)
	hud.menu_requested.connect(open_menu)
	coop=preload("res://coop_session.gd").new()
	coop.name="CoopSession"
	coop.game=self
	add_child(coop)
	_prepare_round(Mode.EXPLORE)
	player.set_controls_enabled(false)
	hud.show_menu(false)
	player.select_character(hud.selected_character_id)
	arsenal.refresh_loadout()
	_refresh_economy()
	_update_hud()

func _on_character_selected(id: int) -> void:
	if is_instance_valid(coop) and coop.enabled:
		coop.message="组队期间角色已锁定，请离开房间后更换。"
		if coop.members.has(coop.local_id()): hud.set_character_selected(coop.members[coop.local_id()].character)
		return
	if id != player.character_id:
		skills.cancel_active()
	player.select_character(id)
	hud.set_character_selected(id)
	max_health = profile.max_health(id)
	health = minf(health,max_health) if round_started and not round_over else max_health
	arsenal.refresh_loadout()
	_refresh_economy()
	_update_hud()

func _ground(pos: Vector3) -> Vector3:
	return Vector3(pos.x, world.ground_height(pos.x, pos.z) + .035, pos.z)

func _prepare_round(id: int) -> void:
	active = false
	player.set_controls_enabled(false)
	if is_instance_valid(tutorial): tutorial.end_round()
	skills.reset_round()
	if is_instance_valid(round_root):
		remove_child(round_root)
		round_root.free()
	pickups.clear()
	relays.clear()
	shelters.clear()
	mutants.clear()
	flare_nodes.clear()
	extraction_points.clear()
	_load_selected_world()
	round_root = Node3D.new()
	round_root.name = "Expedition"
	add_child(round_root)
	mode = clampi(id, 0, 2)
	_resource_slots.clear()
	max_health = profile.max_health(player.character_id)
	health = max_health
	scrap = 0
	collected = 0
	total = 0
	medkits = 3 if "field_kit" in profile.owned else 2
	flares = 1
	elapsed = 0.0
	repaired = 0
	round_over = false
	won = false
	storm_active = false
	damage_grace = 3.0
	_repel_cooldown = 0.0
	toast_remaining = 0.0
	base = Props.shelter(true)
	base.name = "Camp"
	base.position = _ground(region.base)
	round_root.add_child(base)
	shelters.append(base)
	for destination_id in [region_id]:
		var pad := Props.extraction()
		pad.name="Extraction_"+str(destination_id)
		pad.position=_ground(Layout.expedition(destination_id).exit)
		pad.set_meta("destination_id",destination_id)
		pad.set_meta("display_name",str(Layout.REGIONS[destination_id].name)+"撤离点")
		round_root.add_child(pad)
		extraction_points.append(pad)
		if destination_id==region_id: extraction=pad
		_add_extraction_beacon(pad)
	for i in region.relays.size():
		var relay: Node3D = Props.relay(i + 1)
		relay.position = _ground(region.relays[i])
		round_root.add_child(relay)
		relays.append(relay)
	if region_id==0:
		for p in LOOT_POSITIONS: _add_pickup("scrap",p)
		for p in MEDKIT_POSITIONS: _add_pickup("medkit",p)
	else:
		var center: Vector3=region.position
		for p in Layout.REGION_LOOT: _add_pickup("scrap",center+p)
		for p in [Vector3(4,0,35),Vector3(-4,0,-24),Vector3(3,0,-65),Vector3(-38,0,34),Vector3(44,0,-31)]:
			_add_pickup("medkit",center+p)
	expedition.spawn(self)
	for i in (3 if mode == Mode.EXPLORE else (4 if mode == Mode.EXTRACTION else 5)):
		var mutant: CharacterBody3D = Mutant.new()
		mutant.name = "WastelandMutant%d" % (i+1)
		mutant.position = _ground(MONSTER_POSITIONS[i]) if region_id==0 else _safe_resource_position(Vector3(region.position)+[Vector3(-4,0,-18),Vector3(4,0,-48),Vector3(-34,0,2),Vector3(31,0,-55),Vector3(44,0,18)][i])
		mutant.patrol_seed = 130 + i * 19
		mutant.playable_extent = region.extent
		round_root.add_child(mutant)
		mutant.attack_landed.connect(_on_mutant_attack)
		mutants.append(mutant)
	player.reset_for_round(_ground(Vector3(region.base) + Vector3(0,0,1)))
	_set_weather(false)
	arsenal.reset_round()

func _load_selected_world() -> void:
	if is_instance_valid(world) and world.region_id==region_id:
		return
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = (load(region.scene) as PackedScene).instantiate()
	add_child(world)
	player.playable_extent = region.extent

func start_mode(id: int) -> void:
	if is_instance_valid(coop) and coop.enabled:
		hud._coop_panel.open()
		coop.message="请由房主在组队大厅开始行动。"
		return
	if not _retry_settlement(): return
	if not expedition.id.is_empty() and round_started and not round_over:
		var ended: Dictionary = profile.finish_expedition(expedition.id,false,0,round_ammo)
		if not ended.ok:
			_refresh_economy(ended.message)
			return
		round_over = true
		active = false
		player.set_controls_enabled(false)
	var departure: Dictionary = profile.begin_expedition()
	if not departure.ok:
		hud.show_menu(false)
		_refresh_economy(departure.message)
		return
	expedition.reset(departure.id)
	_last_result={}
	round_ammo = int(departure.ammo)
	region_id = _selected_region
	region = Layout.expedition(region_id)
	_prepare_round(id)
	round_started = true
	active = true
	player.set_controls_enabled(true)
	hud.show_game()
	tutorial.begin_round()
	_show_toast(["收集零件修复 3 座信标，再返回营地。狼兽会在荒野游荡。", "180 秒内带着 6 个零件，到北侧撤离点按 E。", "坚持 120 秒，修复任意 2 座信标，再回营地。沙暴每 30 秒来袭。"][mode], 8.0)
	_refresh_economy()
	_update_hud()

func open_menu() -> void:
	if is_instance_valid(coop) and coop.enabled:
		player.set_controls_enabled(false)
		hud.show_menu(round_started and not round_over)
		return
	active = false
	player.set_controls_enabled(false)
	_set_weather(false)
	var saved := _retry_settlement()
	hud.show_menu(round_started and not round_over)
	_refresh_economy("" if saved else "结算保存失败，请检查存储空间后返回营地重试。")

func resume_game() -> void:
	if is_instance_valid(coop) and coop.enabled and coop.in_round:
		hud.show_game()
		coop._sync_local()
		return
	if not round_started or round_over:
		return
	active = true
	player.set_controls_enabled(true)
	_set_weather(storm_active and not tutorial.running)
	hud.show_game()
	_update_hud()

func restart_game() -> void:
	# Replay stays on the current map even if another destination was browsed while paused.
	_selected_region=region_id
	hud.set_region_selected(region_id)
	start_mode(mode)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_M, KEY_ESCAPE]:
			if active and hud._hud.visible:
				open_menu()
			elif round_started and not round_over:
				resume_game()
			get_viewport().set_input_as_handled()
			return
	if not active:
		return
	if is_instance_valid(coop) and coop.in_round and hud._hud.visible and event is InputEventKey and event.pressed and not event.echo:
		var ping_kind: String={KEY_G:"supply",KEY_H:"danger",KEY_T:"rally"}.get(event.keycode,"")
		if not ping_kind.is_empty():
			coop.team.request_ping(ping_kind)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("aim_scope") and not event.is_echo():
		if hud._hud.visible and player.controls_enabled: hud._weapon_aim.toggle_scope()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(coop) and coop.in_round:
		if not hud._hud.visible: return
		for action in ["interact","heal","build_shelter","repel","fire_weapon","character_skill"]:
			if event.is_action_pressed(action):
				coop.request_action(action)
				get_viewport().set_input_as_handled()
				return
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("heal"):
		use_medkit()
	elif event.is_action_pressed("build_shelter"):
		build_shelter()
	elif event.is_action_pressed("repel"):
		repel_mutants()
	elif event.is_action_pressed("fire_weapon"):
		arsenal.fire()
	elif event.is_action_pressed("character_skill"):
		use_character_skill()
	else:
		return
	get_viewport().set_input_as_handled()

func weapon_target() -> Vector3:
	return hud._weapon_aim.target_point()

func _physics_process(delta: float) -> void:
	if not active:
		return
	if is_instance_valid(coop) and coop.client_round():
		coop.tick_client(delta)
		toast_remaining=maxf(0,toast_remaining-delta)
		skills.tick(delta)
		arsenal.tick(delta)
		return
	var practicing: bool = tutorial.running
	if not practicing: elapsed += delta
	if is_instance_valid(coop) and coop.in_round:
		coop.tick(delta)
	else:
		skills.tick(delta)
		arsenal.tick(delta)
	damage_grace = maxf(0.0, damage_grace - delta)
	_repel_cooldown = maxf(0.0, _repel_cooldown - delta)
	toast_remaining = maxf(0.0, toast_remaining - delta)
	for pickup in pickups.duplicate():
		if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
			continue
		var distance: Vector3 = player.global_position - pickup.global_position
		if Vector2(distance.x,distance.z).length() < 1.25 and absf(distance.y) < 1.7:
			_collect(pickup)
	if practicing:
		tutorial.tick(delta)
		_hud_clock += delta
		if _hud_clock >= .10:
			_hud_clock = 0.0
			_update_hud()
		return
	for pad in extraction_points: Effects.tick(pad,elapsed)
	var new_storm := mode == Mode.SURVIVAL and fmod(elapsed, 45.0) >= 30.0
	if storm_active != new_storm:
		storm_active = new_storm
		_set_weather(storm_active)
		_show_toast("沙暴来袭：进入营地或避难棚，避免持续失血。" if storm_active else "风暴暂歇，继续寻找物资。", 5.0)
	var safe := is_sheltered(player.global_position)
	if storm_active and not safe:
		take_damage(2.8 * delta, false)
	for flare in flare_nodes.duplicate():
		var remaining: float = flare.get_meta("remaining") - delta
		flare.set_meta("remaining", remaining)
		Effects.tick(flare,8.0-remaining,minf(1.0,remaining*2.0))
		if remaining <= 0.0:
			flare_nodes.erase(flare)
			flare.queue_free()
	for mutant in mutants:
		if not active:
			break
		var scared := false
		for flare in flare_nodes:
			if mutant.global_position.distance_to(flare.global_position) < 15.0:
				mutant.fear_source = flare.global_position
				scared = true
		if is_instance_valid(coop) and coop.in_round:
			var target: CharacterBody3D=coop.target_for(mutant)
			mutant.tick(delta,target,is_sheltered(target.global_position),scared)
		else:
			mutant.tick(delta, player, safe, scared)
	if active and mode == Mode.EXTRACTION and elapsed >= EXTRACTION_LIMIT:
		_finish(false, "撤离窗口已关闭", "时间耗尽。先规划补给路线，再向北侧撤离点进发。")
	_hud_clock += delta
	if _hud_clock >= .10:
		_hud_clock = 0.0
		_update_hud()

func _add_pickup(kind: String, pos: Vector3) -> void:
	var pickup: Area3D = Props.pickup(kind)
	pickup.position = _safe_resource_position(pos)
	pickup.set_meta("kind", kind)
	pickup.set_meta("taken", false)
	round_root.add_child(pickup)
	pickups.append(pickup)
	if kind == "scrap":
		total += 1

func _collect(pickup: Area3D) -> void:
	if is_instance_valid(coop) and coop.in_round and coop.context_peer<=1 and coop.members.get(1,{}).get("hp",0)<=0: return
	if not active or pickup.get_meta("taken", false):
		return
	pickup.set_meta("taken", true)
	if pickup.get_meta("kind") == "scrap":
		scrap += 1
		collected += 1
		_show_toast("回收零件 +1  ·  可用于修复、建造和驱兽", 2.0)
	elif pickup.get_meta("kind") == "medkit":
		medkits += 1
		_show_toast("医疗包 +1  ·  按 Q 恢复 35 生命", 2.0)
	elif pickup.has_meta("value"):
		_show_toast(expedition.collect(pickup),3.0)
	tutorial.record_pickup()
	pickups.erase(pickup)
	pickup.queue_free()

func interact() -> void:
	if not active:
		return
	var nearby := _nearby_interactable()
	if nearby == null:
		_show_toast("靠近无线电信标、营地或撤离点，再按 E。")
		return
	if is_instance_valid(coop) and coop.in_round and _can_extract() and (nearby in extraction_points or nearby==base and mode!=Mode.EXTRACTION):
		coop.team.begin_extraction(coop.context_peer if coop.context_peer>0 else coop.local_id(),nearby)
		return
	if nearby == base:
		if mode == Mode.EXPLORE and repaired >= 3:
			_finish(true, "荒野通讯已恢复", "3 座信标重新上线，你已安全返回营地。")
		elif mode == Mode.SURVIVAL and repaired >= 2 and elapsed >= SURVIVAL_TIME:
			_finish(true, "挺过废土风暴", "修复信标、穿越兽群，你带着物资回到了营地。")
		else:
			_show_toast("营地提供沙暴和狼兽庇护。" + ("完成目标后在这里交付任务。" if mode != Mode.EXTRACTION else "撤离点位于地图北侧。"))
	elif nearby in extraction_points:
		if mode==Mode.EXPLORE and repaired>=3:
			_finish(true,"成功撤离","通讯信标已修复，你带着战利品从撤离点安全离开。")
		elif mode==Mode.SURVIVAL and repaired>=2 and elapsed>=SURVIVAL_TIME:
			_finish(true,"成功撤离","你挺过了废土风暴，并从撤离点带回物资。")
		elif mode!=Mode.EXTRACTION:
			_show_toast("撤离尚未开放："+_extraction_requirement(),5.0)
		elif scrap >= 6:
			_finish(true, "成功撤离", "你带着 %d 个零件离开了危险区域，剩余 %d 秒。" % [scrap, ceili(EXTRACTION_LIMIT-elapsed)])
		else:
			_show_toast("撤离需要携带 6 个零件，还缺 %d 个。" % (6-scrap))
	elif nearby.get_meta("active", false):
		_show_toast("这座无线电信标已经恢复工作。")
	elif scrap < 2:
		_show_toast("修复需要 2 个零件，当前拥有 %d 个。" % scrap)
	else:
		scrap -= 2
		repaired += 1
		Props.set_relay_active(nearby, true)
		_show_toast("信标修复成功  %d / %d  ·  消耗 2 零件" % [repaired, 2 if mode == Mode.SURVIVAL else 3], 4.0)
	_update_hud()

func _nearby_interactable() -> Node3D:
	var nearest: Node3D
	var best := 4.6 if _nearest_extraction().global_position.distance_to(player.global_position)<4.6 else 3.2
	for candidate in [base] + extraction_points + relays:
		var d: float = player.global_position.distance_to(candidate.global_position)
		if d < best:
			best = d
			nearest = candidate
	return nearest

func use_medkit() -> void:
	if not active:
		return
	if health >= max_health:
		_show_toast("生命值已满，医疗包已保留。")
	elif medkits <= 0:
		_show_toast("没有医疗包了，寻找白色急救箱。")
	else:
		medkits -= 1
		health = minf(max_health, health + 35.0)
		_show_toast("使用医疗包  ·  恢复 35 生命")
	_update_hud()

func build_shelter() -> bool:
	if not active:
		return false
	if scrap < 3:
		_show_toast("搭建避难棚需要 3 个零件。")
		return false
	if not actor_grounded(player):
		_show_toast("落地后才能搭建避难棚。")
		return false
	var forward: Vector3 = -player.get_node("Body").global_basis.z
	forward.y = 0.0
	var pos := _ground(player.global_position + forward.normalized() * 4.0)
	if not Layout.inside_playable(pos,5.0,region_id):
		_show_toast("这里靠近地图边缘，请换一块空地。")
		return false
	for existing in shelters + relays + extraction_points:
		if existing.global_position.distance_to(pos) < 6.0:
			_show_toast("离已有设施太近，请换一块空地。")
			return false
	for offset in [Vector3(-2.3,0,-2.3),Vector3(2.3,0,-2.3),Vector3(-2.3,0,2.3),Vector3(2.3,0,2.3)]:
		if absf(_ground(pos+offset).y - pos.y) > .28:
			_show_toast("地面起伏太大，请寻找平整空地。")
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 2.6, 5.0)
	query.shape = shape
	query.transform.origin = pos + Vector3(0,1.6,0)
	query.collision_mask = 1 | 4
	query.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		_show_toast("前方空间不足，请避开残骸和怪物。")
		return false
	var shelter: Node3D = Props.shelter(false)
	shelter.position = pos
	round_root.add_child(shelter)
	shelters.append(shelter)
	scrap -= 3
	_show_toast("避难棚已搭建  ·  走进棚内可以避险", 4.0)
	_update_hud()
	return true

func is_sheltered(pos: Vector3) -> bool:
	for shelter in shelters:
		var local := pos - shelter.global_position
		if Vector2(local.x,local.z).length() < 2.3 and absf(local.y) < 2.5:
			return true
	return false

func repel_mutants() -> void:
	if not active or _repel_cooldown > 0.0:
		return
	if flares > 0:
		flares -= 1
	elif scrap >= 2:
		scrap -= 2
	else:
		_show_toast("驱兽弹已用完，需要 2 个零件制作一枚。")
		return
	_repel_cooldown = 1.0
	var flare := Node3D.new()
	flare.position = _ground(player.global_position) + Vector3(0,.12,0)
	flare.set_meta("remaining", 8.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff692c")
	glow.light_energy = 4.0
	glow.omni_range = 12.0
	glow.position.y = .5
	flare.add_child(glow)
	flare.add_child(Effects.flare())
	round_root.add_child(flare)
	flare_nodes.append(flare)
	_show_toast("驱兽信号已点燃  ·  15 米内的狼兽会退避 8 秒", 4.0)
	_update_hud()

func _on_mutant_attack(damage: float) -> void:
	if is_instance_valid(coop) and coop.in_round:
		coop.damage(coop._damage_target,damage,true)
		return
	take_damage(damage, true)

func take_damage(amount: float, bite: bool = false) -> void:
	if is_instance_valid(coop) and coop.in_round:
		coop.damage(coop.local_id(),amount,bite)
		return
	if is_instance_valid(tutorial) and tutorial.running: return
	if bite and player.is_dashing():
		return
	if not active or damage_grace > 0.0 or amount <= 0.0:
		return
	if bite and "armor" in profile.owned: amount *= .8
	health = maxf(0.0, health - amount)
	if bite:
		damage_grace = 1.0
		hud.flash_damage()
		_show_toast("被狼兽扑咬！Shift 奔跑逃离，F 驱兽，Q 治疗。", 4.0)
	if health <= 0.0:
		_finish(false, "倒在荒野", "利用营地和避难棚躲避危险，及时治疗；驱兽弹能争取脱身时间。")

func _finish(success: bool, title: String, summary: String) -> void:
	if is_instance_valid(coop) and coop.in_round:
		coop.finish(success,title,summary)
		return
	if round_over:
		return
	active = false
	tutorial.end_round()
	round_over = true
	won = success
	player.set_controls_enabled(false)
	_set_weather(false)
	var died := not success and health<=0.0
	var equipment_names: Array[String]=[]
	for item in Profile.ITEMS:
		if item.id in profile.owned: equipment_names.append(item.name)
	_last_result={"success":success,"death":died,"title":title,"summary":summary,"saved":false,
		"items":expedition.bag_items,"value":expedition.bag_value,"elapsed":_time(elapsed),"collected":collected,
		"repaired":repaired,"region":region.name,"mode":MODE_NAMES[mode],"equipment":equipment_names,
		"ammo":round_ammo,"lost_ammo":profile.ammo_stock+round_ammo,"assets":profile.assets}
	_pending_settlement={"id":expedition.id,"success":success,"value":expedition.bag_value,"ammo":round_ammo,"death":died}
	_retry_settlement()
	if died and is_instance_valid(arsenal.weapon): arsenal.weapon.hide()
	_show_settlement()

func _show_settlement() -> void:
	if _last_result.is_empty(): return
	var data := _last_result
	var equipment_text := "本局未购买装备。"
	if not data.equipment.is_empty():
		equipment_text=("死亡遗失：" if data.death else "保留装备：")+"、".join(data.equipment)
	if data.death:
		equipment_text+="\n弹药清空：%d 发 · 已购装备需回商店重新购买。"%data.lost_ammo
	else:
		equipment_text+="\n返还余弹：%d 发。"%data.ammo
	var details := {"stats":["行动用时|"+data.elapsed,"回收零件|%d"%data.collected,"修复信标|%d 座"%data.repaired],
		"context":data.region+"  /  "+data.mode,"cash":("带回 %d 件战利品 · 收益 +%d G"%[data.items,data.value] if data.success else "遗失 %d 件战利品 · 损失 %d G"%[data.items,data.value])+"\n营地余额 %d G · 角色等级保留"%data.assets,
		"equipment":equipment_text,"death":data.death,"saved":data.saved,
		"notice":"结算已保存" if data.saved else "结算尚未保存：以上为待结算结果。请检查存储空间，返回营地时会重试；暂不可出发或购买。"}
	hud.show_result(data.success,data.title,data.summary,details)

func _set_weather(storm: bool) -> void:
	var environment: Environment = world.get_node("DesertAtmosphere").environment
	environment.volumetric_fog_density = .013 if storm else .0010
	environment.fog_density = .005 if storm else .0005
	environment.fog_sky_affect = .42 if storm else .15
	world.set_region_atmosphere(region_id,storm)

func _show_toast(message: String, duration: float = 3.0) -> void:
	if is_instance_valid(coop) and coop.context_peer>1:
		coop.tell(coop.context_peer,message)
		return
	toast = message
	toast_remaining = duration

func _time(seconds: float) -> String:
	var whole := maxi(0, ceili(seconds))
	return "%02d:%02d" % [whole / 60, whole % 60]

func _next_target() -> Dictionary:
	var destination: Node3D
	var label := ""
	if mode == Mode.EXTRACTION and scrap >= 6:
		destination = _nearest_extraction()
		label = str(destination.get_meta("display_name","撤离点"))
	elif (mode == Mode.EXPLORE and repaired >= 3) or (mode == Mode.SURVIVAL and repaired >= 2):
		destination = base
		label = "安全营地"
	elif scrap < (6 if mode == Mode.EXTRACTION else 2):
		var best := INF
		for pickup in pickups:
			if is_instance_valid(pickup) and pickup.get_meta("kind") == "scrap":
				var d := player.global_position.distance_to(pickup.global_position)
				if d < best:
					best = d
					destination = pickup
					label = "可回收零件"
	else:
		var best := INF
		for relay in relays:
			if not relay.get_meta("active", false):
				var d := player.global_position.distance_to(relay.global_position)
				if d < best:
					best = d
					destination = relay
					label = Layout.district_name(relay.global_position,region_id) + "信标"
	if destination == null:
		return {"text":"寻找物资或前往营地", "angle":0.0}
	var offset := destination.global_position - player.global_position
	var angle := wrapf(atan2(-offset.x,-offset.z) - player.camera_yaw, -PI, PI)
	var directions := ["前方", "左前", "左侧", "左后", "后方", "右后", "右侧", "右前"]
	var direction_index := posmod(roundi(angle / (PI/4.0)), 8)
	return {"text":"%s  ·  %s  %d 米" % [label, directions[direction_index], roundi(Vector2(offset.x,offset.z).length())], "angle":angle}

func _update_hud() -> void:
	if is_instance_valid(coop) and coop.context_peer>1: return
	var objective := "修复信标  %d / 3  ·  完成后回营地按 E" % repaired
	var time_text := "探索  " + _time(elapsed)
	if mode == Mode.EXTRACTION:
		objective = "携带零件  %d / 6  ·  到北侧撤离点按 E" % scrap
		time_text = "撤离倒计时  " + _time(EXTRACTION_LIMIT - elapsed)
	elif mode == Mode.SURVIVAL:
		objective = "坚持  %d / 120 秒  ·  修复信标  %d / 2  ·  返回营地" % [mini(120,int(elapsed)),mini(2,repaired)]
		time_text = "生存  " + _time(elapsed)
	var weather := "风沙平稳  ·  留意荒野中的狼兽"
	if mode == Mode.SURVIVAL:
		weather = ("沙暴中  ·  %s  ·  %d 秒后转晴" % ["棚内安全" if is_sheltered(player.global_position) else "暴露失血，寻找庇护",ceili(45.0-fmod(elapsed,45.0))]) if storm_active else "下次沙暴  %d 秒" % ceili(30.0-fmod(elapsed,45.0))
	var danger_count := 0
	for mutant in mutants:
		if mutant.state in ["chase", "windup", "lunge"]:
			danger_count += 1
	if danger_count > 0:
		weather += "  ·  %d 只狼兽正在追击  [F 驱兽]" % danger_count
	weather = Layout.district_name(player.global_position,region_id) + "  ·  " + weather
	var nearby := _nearby_interactable()
	var prompt := ""
	if nearby == base:
		prompt = "E  营地交付 / 庇护"
	elif nearby in extraction_points:
		prompt = "E  安全撤离  ·  "+_extraction_requirement()
	elif nearby != null:
		prompt = "信标已上线" if nearby.get_meta("active", false) else "E  修复无线电信标  ·  2 零件"
	if is_instance_valid(coop) and coop.in_round:
		for id in coop.members:
			if id==coop.local_id() or coop.members[id].hp>0: continue
			var teammate: Node3D=coop.actor(id)
			if is_instance_valid(teammate) and player.global_position.distance_to(teammate.global_position)<3.2:
				prompt="E  开始 3 秒救援 · "+str(coop.members[id].name)
				break
		if coop.team.rescues.has(coop.local_id()): prompt=coop.team.status_text()
	if is_instance_valid(tutorial) and tutorial.running: time_text="新手练习 · 任务计时暂停"
	var target := _next_target()
	var camera: Camera3D = player.get_node("Camera3D")
	var aim_world: Vector3 = player.global_position + Vector3(0,1.1,0) + Vector3.FORWARD.rotated(Vector3.UP,player.camera_yaw)*12.0
	hud.set_status({"mode_name":str(region.name)+" · "+MODE_NAMES[mode],"objective":objective,"health":health,
		"scrap":scrap,"medkits":medkits,"flares":flares,"time_text":time_text,
		"weather":weather,"prompt":prompt,"toast":toast if toast_remaining > 0.0 else "",
		"target":target.text, "target_angle":target.angle, "skill":skills.status(player.character_id), "character_name":player.character_info().name,
		"extraction_hint":_extraction_hint(),"extraction_ready":_can_extract(),
		"aim_position":camera.unproject_position(aim_world),"aim_visible":not camera.is_position_behind(aim_world),
		"max_health":max_health,"bank_assets":profile.assets,"bag_value":expedition.bag_value,
		"bag_items":expedition.bag_items,"ammo":round_ammo,
		"weapon_name":"荒原驱狼枪" if profile.equipped=="repulsor" else ""})
	if is_instance_valid(coop) and coop.in_round:
		coop._sync_local()
		hud._backpack.text="小队战利品 %d G · %d 件"%[expedition.bag_value,expedition.bag_items]

func use_character_skill() -> void:
	if is_instance_valid(coop) and coop.in_round:
		coop.request_action("character_skill")
		return
	if active and skills.activate():
		tutorial.record_skill()

func _camp_available() -> bool:
	if is_instance_valid(coop) and coop.enabled: return false
	return not active and (not round_started or round_over) and _pending_settlement.is_empty()

func _refresh_economy(message: String = "") -> void:
	var data: Dictionary = profile.ui_data(player.character_id,_camp_available(),message)
	data["can_abandon"] = round_started and not round_over
	hud.set_economy(data)

func _upgrade_character() -> void:
	if not _camp_available():
		_refresh_economy("请结束本次行动后再升级。")
		return
	var result: Dictionary = profile.upgrade(player.character_id)
	max_health = profile.max_health(player.character_id)
	health = max_health
	_refresh_economy(result.message)
	_update_hud()

func _purchase_equipment(item_id: String) -> void:
	if not _camp_available():
		_refresh_economy("请结束本次行动后再购买。")
		return
	var result: Dictionary = profile.purchase(item_id)
	arsenal.refresh_loadout()
	_refresh_economy(result.message)
	_update_hud()

func _equip_equipment(item_id: String) -> void:
	if not _camp_available(): return
	var result: Dictionary = profile.equip(item_id)
	arsenal.refresh_loadout()
	_refresh_economy(result.message)

func _retry_settlement() -> bool:
	if _pending_settlement.is_empty(): return true
	var result: Dictionary=profile.finish_expedition(str(_pending_settlement.id),bool(_pending_settlement.success),int(_pending_settlement.value),int(_pending_settlement.ammo),bool(_pending_settlement.get("death",false)))
	if not result.ok:
		_refresh_economy(result.message)
		return false
	_pending_settlement={}
	round_ammo=0
	arsenal.refresh_loadout()
	if not _last_result.is_empty():
		_last_result.saved=true
		_last_result.assets=profile.assets
	_refresh_economy(result.message)
	return true

func abandon_expedition() -> void:
	if is_instance_valid(coop) and coop.enabled:
		coop.leave_room("已离开小队")
		return
	if round_started and not round_over:
		_finish(false,"返回营地","已放弃本次行动，随身战利品遗失，未使用弹药已送回营地。")

func _on_region_selected(id: int) -> void:
	_selected_region=clampi(id,0,Layout.REGIONS.size()-1)
	hud.set_region_selected(_selected_region)

func _safe_resource_position(desired: Vector3) -> Vector3:
	# All new resource placements need a supported, capsule-sized approach.
	if region_id==0: return _ground(desired)
	var shape := CapsuleShape3D.new()
	shape.radius=.52
	shape.height=1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	query.exclude=[player.get_rid()]
	for step in 65:
		var radius := 0.0 if step==0 else 1.5+floorf((step-1)/8.0)*1.5
		var angle := (step%8)*TAU/8
		var point := _ground(desired+Vector3(cos(angle)*radius,0,sin(angle)*radius))
		var separated := true
		for used in _resource_slots:
			if used.distance_to(point)<1.65: separated=false; break
		if not separated: continue
		query.transform.origin=point+Vector3(0,1.0,0)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		_resource_slots.append(point)
		return point
	# Central boulevard is kept clear by every region builder.
	var fallback := _ground(Vector3(region.position)+Vector3(0,0,-72+_resource_slots.size()*1.8))
	_resource_slots.append(fallback)
	return fallback

func _nearest_extraction() -> Node3D:
	var nearest: Node3D=extraction
	var best := INF
	for pad in extraction_points:
		var distance := player.global_position.distance_squared_to(pad.global_position)
		if distance<best:
			best=distance
			nearest=pad
	return nearest

func _can_extract() -> bool:
	return scrap>=6 if mode==Mode.EXTRACTION else (repaired>=3 if mode==Mode.EXPLORE else repaired>=2 and elapsed>=SURVIVAL_TIME)

func _extraction_requirement() -> String:
	if _can_extract(): return "条件已满足，靠近光柱按 E"
	if mode==Mode.EXTRACTION: return "需要 6 个零件（%d / 6）" % scrap
	if mode==Mode.EXPLORE: return "先修复 3 座信标（%d / 3）" % repaired
	return "坚持 120 秒（%d），修复 2 座信标（%d / 2）" % [mini(120,int(elapsed)),repaired]

func _extraction_hint() -> String:
	var nearest := _nearest_extraction()
	if not is_instance_valid(nearest): return ""
	var offset := nearest.global_position-player.global_position
	var angle := wrapf(atan2(-offset.x,-offset.z)-player.camera_yaw,-PI,PI)
	var direction: String = ["↑ 前方","↖ 左前","← 左侧","↙ 左后","↓ 后方","↘ 右后","→ 右侧","↗ 右前"][posmod(roundi(angle/(PI/4)),8)]
	return "%s · %s %d 米\n%s" % [nearest.get_meta("display_name"),direction,roundi(Vector2(offset.x,offset.z).length()),_extraction_requirement()]

func _add_extraction_beacon(pad: Node3D) -> void:
	pad.add_child(Effects.column(Color("7bffd0")))
	var label := Label3D.new()
	label.name="ExtractionWorldLabel"
	label.text=str(pad.get_meta("display_name"))+"\nE · 安全撤离"
	label.font=load("res://assets/fonts/NotoSansSC.ttf")
	label.font_size=36
	label.pixel_size=.008
	label.position.y=7
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=true
	label.modulate=Color("7bffd0")
	label.outline_size=8
	pad.add_child(label)

func _replay_tutorial() -> void:
	if is_instance_valid(coop) and coop.enabled:
		coop.message="新手教程请在离开组队房间后单独练习。"
		hud._coop_panel.open()
		return
	if round_started and not round_over:
		resume_game()
		tutorial.start()
	else:
		tutorial.queued=true
		start_mode(mode)
	_update_hud()

func actor_grounded(body: CharacterBody3D) -> bool:
	if body.get_script()==preload("res://coop_avatar.gd"): return body.grounded
	return body.is_on_floor()
