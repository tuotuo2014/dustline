extends CanvasLayer
## Menus and field HUD. Gameplay stays in the world controller.

const RegionLayout = preload("res://world_layout.gd")
const CharacterCatalog = preload("res://character_catalog.gd")
const RosterSurvivor = preload("res://wasteland_roster_survivor.gd")
const TutorialPanel = preload("res://tutorial_panel.gd")

signal region_selected(id: int)
signal mode_selected(id: int)
signal character_selected(id: int)
signal skill_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal abandon_requested
signal upgrade_requested
signal purchase_requested(item_id: String)
signal equip_requested(item_id: String)
signal tutorial_next_requested
signal tutorial_skip_requested
signal tutorial_replay_requested

const INK := Color("121716")
const PAPER := Color("eee7d6")
const MUTED := Color("b7b8a9")
const AMBER := Color("efb365")
const GREEN := Color("8ab79a")
const RED := Color("ee8a76")

var _built := false
var _theme: Theme
var _hud: Control
var _menu: Control
var _result: Control
var _menu_panel: PanelContainer
var _result_panel: PanelContainer
var _menu_center: CenterContainer
var _result_center: CenterContainer
var _cards: GridContainer
var _resume: Button
var _restart: Button
var _mode_buttons: Array[Button] = []
var _character_buttons: Array[Button] = []
var selected_character_id := 0
var _character_name: Label
var _character_subtitle: Label
var _character_detail: Label
var _character_view: SubViewport
var _character_container: SubViewportContainer
var _preview_model: Node3D
var _preview_time := 0.0
var _preview_yaw := PI
var _preview_dragging := false
var _preview_model_id := -1
var _menu_body: GridContainer
var _character_grid: GridContainer
var _menu_heading: Label
var _menu_edition: Label
var _entry_question: Label
var _entry_mission_column: VBoxContainer
var _entry_goals: Array[Label] = []
var _menu_actions: BoxContainer
var _skill_button: Button
var _skill_progress: ProgressBar
var _preview_panel: PanelContainer
var _preview_camera: Camera3D
var _preview_distance := 1.85
var _mission: PanelContainer
var _mission_box: VBoxContainer
var _vitals: PanelContainer
var _mode: Label
var _objective: Label
var _target: Label
var _extraction_guide: Label
var _stats: Label
var _health: ProgressBar
var _time: Label
var _weather: Label
var _prompt_box: PanelContainer
var _prompt: Label
var _toast: Label
var _hint: Label
var _menu_button: Button
var _result_kicker: Label
var _result_title: Label
var _result_summary: Label
var _result_restart: Button
var _result_camp: Button
var _result_details: VBoxContainer
var _result_context: Label
var _result_stats: GridContainer
var _result_cash: Label
var _result_equipment: Label
var _result_notice: Label
var _damage_overlay: ColorRect
var _damage_tween: Tween
var _economy: Dictionary = {}
var _abandon: Button
var _aim_marker: Label
var _weapon_aim: Control
var _bank: Label
var _backpack: Label
var _weapon: Label
var _menu_bank: Label
var _camp: Control
var _camp_panel: PanelContainer
var _camp_center: CenterContainer
var _camp_balance: Label
var _camp_notice: Label
var _camp_feedback: Label
var _camp_character: Label
var _camp_bonuses: Label
var _camp_upgrade: Button
var _camp_characters: GridContainer
var _camp_character_buttons: Array[Button] = []
var _camp_growth: GridContainer
var _camp_items: GridContainer
var _camp_back: Button
var _camp_entry: Button
var _region_picker: OptionButton
var _region_description: Label
var selected_region_id := 0
var _result_actions: BoxContainer
var _team_status: Label
var _coop_panel: Control
var _squad_overlay: Control
var _minimap: Control
var _tutorial_panel: Control

func set_tutorial(data: Dictionary) -> void:
	_build()
	var was_visible := _tutorial_panel.visible
	_tutorial_panel.camera=get_parent().get_node_or_null("Player/Camera3D")
	_tutorial_panel.focus_control={"skill":_skill_button,"health":_health,"stats":_stats,"backpack":_backpack}.get(data.get("focus",""),null)
	_tutorial_panel._pointer.exclusion_control=_minimap
	_tutorial_panel.present(data)
	if _tutorial_panel.visible:
		_prompt_box.hide()
		_toast.hide()
	if _tutorial_panel.visible != was_visible:
		_layout()

func flash_damage() -> void:
	if is_instance_valid(_damage_tween):
		_damage_tween.kill()
	_damage_overlay.color.a = .24
	_damage_tween = create_tween()
	_damage_tween.tween_property(_damage_overlay, "color:a", 0.0, .45)

func _ready() -> void:
	_build()
	show_menu(false)
	get_viewport().size_changed.connect(_layout)

func show_menu(can_resume: bool) -> void:
	_build()
	_character_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hud.visible = false
	_menu.visible = true
	_result.visible = false
	_hide_camp()
	if is_instance_valid(_character_container):
		_character_container.visible = true
	_resume.visible = can_resume
	_restart.visible = can_resume
	_layout()
	if can_resume:
		_resume.call_deferred("grab_focus")
	else:
		_mode_buttons[0].call_deferred("grab_focus")

func show_game() -> void:
	_build()
	_character_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hud.visible = true
	_menu.visible = false
	_result.visible = false
	_camp.visible = false
	if is_instance_valid(_character_container):
		_character_container.visible = false
	get_viewport().gui_release_focus()

func show_result(won: bool, title: String, summary: String, details: Dictionary = {}) -> void:
	_build()
	_character_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hud.visible = false
	_menu.visible = false
	_camp.visible = false
	if is_instance_valid(_coop_panel): _coop_panel.hide()
	_result.visible = true
	_result_kicker.text = "撤离结算  /  EXTRACTION REPORT" if won else ("死亡结算  /  LOST IN THE WASTELAND" if details.get("death",false) else "行动结算  /  EXPEDITION REPORT")
	_result_kicker.add_theme_color_override("font_color", GREEN if won else RED)
	_result_title.text = title
	_result_summary.text = summary
	_result_details.visible=not details.is_empty()
	_result_context.text=str(details.get("context",""))
	for child in _result_stats.get_children():
		_result_stats.remove_child(child)
		child.queue_free()
	for entry in details.get("stats",[]):
		var card := _panel(Color("17221e"),Color("3c5548"),12)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		_result_stats.add_child(card)
		var column := _vbox(6)
		card.add_child(column)
		column.add_child(_label(str(entry).get_slice("|",0),15,MUTED))
		column.add_child(_label(str(entry).get_slice("|",1),27,PAPER))
	_result_cash.text=str(details.get("cash",""))
	_result_cash.add_theme_color_override("font_color",GREEN if won else AMBER)
	_result_equipment.text=str(details.get("equipment",""))
	_result_equipment.add_theme_color_override("font_color",RED if details.get("death",false) else MUTED)
	_result_notice.text=str(details.get("notice",""))
	_result_notice.add_theme_color_override("font_color",MUTED if details.get("saved",true) else AMBER)
	_result_restart.text="空装再出发" if details.get("death",false) else "再来一次"
	_result_restart.disabled=not details.get("saved",true)
	_result_camp.text="返回商店 · 重新购买" if details.get("death",false) else "返回营地商店"
	_layout()
	(_result_camp if details.get("death",false) or not details.get("saved",true) else _result_restart).call_deferred("grab_focus")

func set_status(data: Dictionary) -> void:
	_build()
	_mode.text = str(data.get("mode_name", "废土行动"))
	_objective.text = str(data.get("objective", "探索断裂公路，寻找生存物资。"))
	_target.text = str(data.get("target", ""))
	_target.visible = not _target.text.is_empty()
	_extraction_guide.text = str(data.get("extraction_hint",""))
	_extraction_guide.add_theme_color_override("font_color",GREEN if data.get("extraction_ready",false) else AMBER)
	var maximum_hp := maxf(1.0, float(data.get("max_health", 100.0)))
	var hp := clampf(float(data.get("health", 100.0)), 0.0, maximum_hp)
	_stats.text = "生命 %03d   零件 %02d   医疗包 %02d   驱兽弹 %02d" % [int(ceil(hp)), int(data.get("scrap", 0)), int(data.get("medkits", 0)), int(data.get("flares", 0))]
	_health.max_value = maximum_hp
	_health.value = hp
	_health.modulate = RED if hp <= 30.0 else Color.WHITE
	_bank.text = "营地资产  %d G" % int(data.get("bank_assets", 0))
	_backpack.text = "随身战利品  %d G  ·  %d 件待带回" % [int(data.get("bag_value", 0)), int(data.get("bag_items", 0))]
	var weapon_name := str(data.get("weapon_name", ""))
	_aim_marker.visible = false
	_aim_marker.position = Vector2(data.get("aim_position",Vector2.ZERO)) - Vector2(12,20)
	_weapon.visible = not weapon_name.is_empty()
	_weapon.text = "%s\n右键开火 · K 倍镜 · 弹药 %d" % [weapon_name, int(data.get("ammo", 0))]
	_time.text = str(data.get("time_text", "自由探索"))
	_weather.text = str(data.get("weather", ""))
	_weather.add_theme_color_override("font_color", RED if "追击" in _weather.text or "暴露失血" in _weather.text else MUTED)
	_prompt.text = str(data.get("prompt", ""))
	_prompt_box.visible = not _prompt.text.is_empty() and not _tutorial_panel.visible
	_toast.text = str(data.get("toast", ""))
	_toast.visible = not _toast.text.is_empty() and not _tutorial_panel.visible
	_fit_prompt.call_deferred()
	_fit_vitals.call_deferred()
	var skill: Dictionary = data.get("skill",{})
	if not skill.is_empty():
		_skill_button.text="C  %s  ·  %s"%[skill.name,skill.state]
		_skill_button.disabled=not skill.ready
		_skill_button.tooltip_text=skill.description
		_skill_progress.max_value=skill.maximum
		_skill_progress.value=skill.maximum-skill.cooldown
		_skill_progress.modulate=skill.accent


func set_character_selected(id: int) -> void:
	selected_character_id = clampi(id, 0, CharacterCatalog.CHARACTERS.size() - 1)
	var info := CharacterCatalog.get_info(selected_character_id)
	if is_instance_valid(_character_name):
		_character_name.text = str(info.name)
		_character_name.add_theme_color_override("font_color", Color("f6d693"))
	if is_instance_valid(_character_subtitle):
		_character_subtitle.text = str(info.subtitle)
	if is_instance_valid(_character_detail):
		var skill := CharacterCatalog.skill(selected_character_id)
		_character_detail.text = "C / "+str(skill.name)+" · "+str(skill.description)
		_character_detail.tooltip_text = str(info.detail)+" 冷却 %d 秒。"%int(skill.cooldown)
	for i in _character_buttons.size():
		var selected := i == selected_character_id
		var button := _character_buttons[i]
		_entry_button_style(button,selected)
	_refresh_preview()
	_refresh_camp_growth()

func _select_character(id: int) -> void:
	set_character_selected(id)
	character_selected.emit(selected_character_id)

func _process(delta: float) -> void:
	if not is_instance_valid(_preview_model) or not is_instance_valid(_menu) or not _menu.visible or (is_instance_valid(_camp) and _camp.visible):
		return
	_preview_time += delta
	_preview_model.rotation.y = _preview_yaw + sin(_preview_time * 0.45) * 0.025
	if _preview_model.has_method("animate"):
		_preview_model.animate(delta, 0.0, true, 0.0)

func _build() -> void:
	if _built:
		return
	_built = true
	layer = 10
	_theme = Theme.new()
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var font := FontVariation.new()
		font.base_font = load("res://assets/fonts/NotoSansSC.ttf") as Font
		font.variation_opentype = {2003265652: 450.0} # OpenType wght axis.
		_theme.default_font = font
	_theme.default_font_size = 22
	_theme.set_color("font_color", "Label", PAPER)
	_theme.set_constant("outline_size", "Label", 0)
	_theme.set_constant("line_spacing", "Label", 6)
	_make_hud()
	_squad_overlay=preload("res://coop_overlay.gd").new()
	_squad_overlay.game=get_parent()
	_squad_overlay.theme=_theme
	_hud.add_child(_squad_overlay)
	_make_menu()
	_make_result()
	_make_camp()
	_coop_panel=preload("res://coop_lobby.gd").new()
	_coop_panel.game=get_parent()
	_coop_panel.theme=_theme
	add_child(_coop_panel)
	_layout()

func _make_hud() -> void:
	_hud = Control.new()
	_hud.name = "Panel"
	_hud.theme = _theme
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_overlay = ColorRect.new()
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.color = Color(.48,.025,.015,0.0)
	_aim_marker = _label("＋",25,AMBER)
	_aim_marker.name = "FirearmAim"
	_aim_marker.hide()
	_hud.add_child(_aim_marker)
	_weapon_aim=preload("res://weapon_aim.gd").new()
	_weapon_aim.game=get_parent()
	_hud.add_child(_weapon_aim)
	_hud.add_child(_damage_overlay)
	_damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_mission_box = _vbox(0)
	_hud.add_child(_mission_box)
	_mission_box.position = Vector2(32, 30)
	_mission_box.size.x = 570
	_mission = _panel(Color(0.045, 0.060, 0.057, 0.87), Color(0.51, 0.40, 0.26, 0.65), 24)
	_mission_box.add_child(_mission)
	var mission_stack := _vbox(10)
	_mission.add_child(mission_stack)
	mission_stack.add_child(_label("D U S T L I N E  /  荒野行动", 16, AMBER))
	_mode = _label("探索收集", 30, PAPER)
	mission_stack.add_child(_mode)
	_objective = _label("收集零件，修复沿途的信标。", 21, PAPER)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_stack.add_child(_objective)
	_target = _label("", 19, AMBER)
	_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_stack.add_child(_target)
	mission_stack.add_child(_rule())
	_extraction_guide=_label("",18,GREEN)
	_extraction_guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	mission_stack.add_child(_extraction_guide)

	_vitals = _panel(Color(.035,.06,.064,.94), Color(.3,.55,.55,.6), 16)
	_hud.add_child(_vitals)
	_vitals.minimum_size_changed.connect(_fit_vitals.call_deferred)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation",24)
	_vitals.add_child(bottom_row)
	var vitals_stack := _vbox(8)
	vitals_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	vitals_stack.size_flags_stretch_ratio=1.2
	bottom_row.add_child(vitals_stack)
	_stats = _label("生命 100",20,PAPER)
	_stats.name="Stats"
	_stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	vitals_stack.add_child(_stats)
	_health = ProgressBar.new()
	_health.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_health.custom_minimum_size.y=7
	_health.show_percentage=false
	_health.add_theme_stylebox_override("background",_style(Color("283c3b"),Color.TRANSPARENT,0))
	_health.add_theme_stylebox_override("fill",_style(GREEN,Color.TRANSPARENT,0))
	vitals_stack.add_child(_health)
	_backpack=_label("",16,AMBER)
	_backpack.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	vitals_stack.add_child(_backpack)
	_bank=_label("",14,MUTED)
	vitals_stack.add_child(_bank)
	var skill_stack := _vbox(7)
	skill_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom_row.add_child(skill_stack)
	_skill_button=_button("C  角色技能",false)
	_skill_button.name="CharacterSkill"
	_skill_button.custom_minimum_size.y=40
	_skill_button.add_theme_font_size_override("font_size",16)
	_skill_button.pressed.connect(func() -> void: skill_requested.emit())
	skill_stack.add_child(_skill_button)
	_skill_progress=ProgressBar.new()
	_skill_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_skill_progress.show_percentage=false
	_skill_progress.custom_minimum_size.y=3
	_skill_progress.add_theme_stylebox_override("background",_style(Color("29352e"),Color.TRANSPARENT,0))
	_skill_progress.add_theme_stylebox_override("fill",_style(Color.WHITE,Color.TRANSPARENT,0))
	skill_stack.add_child(_skill_progress)
	_weapon=_label("",14,GREEN)
	_weapon.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	skill_stack.add_child(_weapon)
	var status_row := _vbox(5)
	status_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom_row.add_child(status_row)
	_time=_label("",18,AMBER)
	status_row.add_child(_time)
	_weather=_label("",14,MUTED)
	_weather.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_row.add_child(_weather)
	_team_status=_label("单人行动",14,Color("77e4dd"))
	_team_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_row.add_child(_team_status)

	_menu_button = _button("菜单  M", false)
	_menu_button.custom_minimum_size = Vector2(150, 46)
	_hud.add_child(_menu_button)
	_menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_menu_button.offset_left = -182
	_menu_button.offset_top = 30
	_menu_button.offset_right = -32
	_menu_button.offset_bottom = 76
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())

	_prompt_box = _panel(Color(0.04, 0.055, 0.05, 0.94), Color(0.81, 0.62, 0.34, 0.7), 18)
	_hud.add_child(_prompt_box)
	_prompt_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.offset_left = -440
	_prompt_box.offset_top = -160
	_prompt_box.offset_right = 440
	_prompt_box.offset_bottom = -92
	_prompt = _label("", 24, PAPER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_box.add_child(_prompt)
	_prompt_box.hide()
	_prompt_box.minimum_size_changed.connect(_fit_prompt.call_deferred)
	_toast = _label("", 25, AMBER)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_toast.add_theme_constant_override("shadow_offset_x", 1)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_hud.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -640
	_toast.offset_top = -256
	_toast.offset_right = 640
	_toast.offset_bottom = -182
	_toast.hide()
	_hint = _label("WASD 移动   Shift 奔跑   空格 跳跃   左键拖动 视角   滚轮 缩放   E 交互   Q 治疗   B 搭建   F 驱兽   C 角色技能", 17, Color("ded7c5"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hud.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 32
	_hint.offset_top = -57
	_hint.offset_right = -32
	_hint.offset_bottom = -20
	_minimap = preload("res://tactical_minimap.gd").new()
	_minimap.name = "TacticalMinimap"
	_minimap.game = get_parent()
	_minimap.vitals_panel = _vitals
	_hud.add_child(_minimap)
	_tutorial_panel = TutorialPanel.new()
	_tutorial_panel.name = "TutorialGuide"
	_hud.add_child(_tutorial_panel)
	_tutorial_panel.next_requested.connect(func() -> void: tutorial_next_requested.emit())
	_tutorial_panel.skip_requested.connect(func() -> void: tutorial_skip_requested.emit())

func _make_menu() -> void:
	_menu = _modal("ModeMenu", Color("b28a3a"))
	var backdrop := preload("res://wasteland_menu_backdrop.gd").new()
	backdrop.name="WastelandArtwork"
	_menu.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_center = _scroll_center(_menu)
	_menu_panel = _panel(Color.TRANSPARENT, Color.TRANSPARENT, 12)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_center.add_child(_menu_panel)
	var stack := _vbox(16)
	_menu_panel.add_child(stack)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	stack.add_child(heading)
	var titles := _vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	var serial := _label("D U S T L I N E   /   W A S T E L A N D   E C H O E S", 16, Color("ffe4a2"))
	serial.add_theme_color_override("font_shadow_color",Color("382715"))
	serial.add_theme_constant_override("shadow_offset_y",2)
	titles.add_child(serial)
	_menu_heading = _label("废土回响", 66, Color("ffe1a0"))
	var title_font := _theme.default_font.duplicate() as FontVariation
	title_font.variation_opentype={2003265652:850.0}
	_menu_heading.add_theme_font_override("font",title_font)
	_menu_heading.add_theme_color_override("font_shadow_color",Color("342518"))
	_menu_heading.add_theme_constant_override("shadow_offset_x",3)
	_menu_heading.add_theme_constant_override("shadow_offset_y",4)
	titles.add_child(_menu_heading)
	var subtitle := _label("黄沙吞没旧世界。带着战利品，活着回来。", 18, Color("fff0c7"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(subtitle)
	_menu_edition = _label("荒原通行档案  /  NO. 004\n四名幸存者 · 四张独立地图\n探索 · 搜集 · 撤离", 16, Color("ffdf98"))
	_menu_edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_menu_edition.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_menu_edition)
	_menu_body = GridContainer.new()
	_menu_body.columns = 2
	_menu_body.add_theme_constant_override("h_separation", 22)
	_menu_body.add_theme_constant_override("v_separation", 18)
	stack.add_child(_menu_body)
	var character_card := _entry_panel(Color(.12,.095,.065,.91),Color("b99a5b"),20)
	character_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	character_card.size_flags_stretch_ratio=.96
	_menu_body.add_child(character_card)
	var character_column := _vbox(8)
	character_card.add_child(character_column)
	_add_character_picker(character_column)
	var mission_card := _entry_panel(Color(.83,.65,.31,.97),Color("342a18"),24)
	mission_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mission_card.size_flags_stretch_ratio=1.05
	_menu_body.add_child(mission_card)
	var mission_column := _vbox(12)
	_entry_mission_column=mission_column
	mission_card.add_child(mission_column)
	mission_column.add_child(_label("02  /  荒原行动许可", 17, Color("48351a")))
	_entry_question=_label("准备好出发了吗？",30,Color("251f15"))
	mission_column.add_child(_entry_question)
	_region_picker=OptionButton.new()
	_region_picker.name="DestinationPicker"
	_region_picker.custom_minimum_size.y=48
	_region_picker.add_theme_font_size_override("font_size",20)
	_entry_button_style(_region_picker,false)
	for entry in RegionLayout.REGIONS: _region_picker.add_item(entry.name)
	_region_picker.item_selected.connect(func(id: int) -> void: region_selected.emit(id))
	var popup := _region_picker.get_popup()
	popup.add_theme_stylebox_override("panel",_style(Color("30291c"),Color("e1b85b"),1))
	popup.add_theme_color_override("font_color",Color("f7dfaa"))
	popup.add_theme_color_override("font_hover_color",Color("fff0c9"))
	popup.add_theme_stylebox_override("hover",_style(Color("65502b"),Color("e1b85b"),1))
	mission_column.add_child(_region_picker)
	_region_description=_label(RegionLayout.REGIONS[0].description,16,Color("4e391e"))
	_region_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(_region_description)
	_menu_actions = BoxContainer.new()
	_menu_actions.add_theme_constant_override("separation", 10)
	mission_column.add_child(_menu_actions)
	_resume = _entry_button("继续当前行动", true)
	_resume.custom_minimum_size.y=44
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	_menu_actions.add_child(_resume)
	_restart = _entry_button("重开当前模式", false)
	_restart.custom_minimum_size.y=44
	_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_menu_actions.add_child(_restart)
	_cards = GridContainer.new()
	_cards.columns = 1
	_cards.add_theme_constant_override("v_separation", 10)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission_column.add_child(_cards)
	_mode_card(0, "01 / EXPLORE", "探索收集", "", "自由探索", "搜集零件，修复 3 座信标，再返回营地。", "")
	_mode_card(1, "02 / EXTRACT", "限时撤离", "", "180 秒", "携带至少 6 个零件，赶往撤离点。", "")
	_mode_card(2, "03 / SURVIVE", "废土生存", "", "至少 120 秒", "修复 2 座信标，躲避沙暴和狼兽后回营地。", "")
	_menu_bank = _label("营地资产  0 G  ·  成功撤离后存入", 17, Color("3d301d"))
	_menu_bank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_column.add_child(_menu_bank)
	var camp_row := HBoxContainer.new()
	camp_row.add_theme_constant_override("separation",12)
	mission_column.add_child(camp_row)
	_camp_entry = _entry_button("营地商店 / 成长", false)
	_camp_entry.name = "CampEntry"
	_camp_entry.custom_minimum_size.y=44
	_camp_entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_camp_entry.pressed.connect(show_camp)
	camp_row.add_child(_camp_entry)
	var team_entry := _entry_button("真人联机",false)
	team_entry.custom_minimum_size.y=44
	team_entry.pressed.connect(func(): _coop_panel.open())
	camp_row.add_child(team_entry)
	var tutorial_entry := _entry_button("新手教程 / 重新学习", false)
	tutorial_entry.name = "TutorialEntry"
	tutorial_entry.custom_minimum_size.y=44
	tutorial_entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tutorial_entry.tooltip_text = "进入游戏后练习移动、视角、奔跑、跳跃、拾取与技能。"
	tutorial_entry.pressed.connect(func() -> void: tutorial_replay_requested.emit())
	camp_row.add_child(tutorial_entry)
	var controls := _label("WASD 移动   /   Shift 奔跑   /   空格跳跃   /   左键拖动视角   /   C 角色技能   /   M 菜单", 15, Color("ffe7b3"))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_color_override("font_shadow_color",Color("382715"))
	controls.add_theme_constant_override("shadow_offset_y",2)
	stack.add_child(controls)

func _make_result() -> void:
	_result = _modal("Result", Color(0.02, 0.031, 0.028, 0.89))
	_result_center = _scroll_center(_result)
	_result_panel = _panel(Color(0.065, 0.083, 0.073, 0.99), Color(0.60, 0.46, 0.27, 0.8), 32)
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_center.add_child(_result_panel)
	var stack := _vbox(18)
	_result_panel.add_child(stack)
	_result_kicker = _label("行动完成  /  MISSION COMPLETE", 19, GREEN)
	stack.add_child(_result_kicker)
	_result_title = _label("平安归来", 40, PAPER)
	_result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_result_title)
	stack.add_child(_rule())
	_result_summary = _label("", 20, MUTED)
	_result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_result_summary)
	_result_details=_vbox(14)
	stack.add_child(_result_details)
	_result_context=_label("",16,MUTED)
	_result_details.add_child(_result_context)
	_result_stats=GridContainer.new()
	_result_stats.columns=3
	_result_stats.add_theme_constant_override("h_separation",12)
	_result_details.add_child(_result_stats)
	_result_cash=_label("",22,GREEN)
	_result_equipment=_label("",19,MUTED)
	_result_notice=_label("",15,MUTED)
	for label in [_result_cash,_result_equipment,_result_notice]:
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_result_details.add_child(label)
	var actions := BoxContainer.new()
	_result_actions = actions
	actions.add_theme_constant_override("separation", 16)
	stack.add_child(actions)
	_result_restart = _button("再来一次", true)
	_result_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_restart.pressed.connect(func() -> void: restart_requested.emit())
	actions.add_child(_result_restart)
	var choose := _button("选择其他模式", false)
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose.pressed.connect(func() -> void: menu_requested.emit())
	actions.add_child(choose)
	var camp := _button("返回营地商店", false)
	_result_camp=camp
	camp.name = "ResultCamp"
	camp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camp.pressed.connect(func() -> void:
		menu_requested.emit()
		show_camp()
	)
	actions.add_child(camp)

func _mode_card(id: int, kicker: String, title: String, _tagline: String, duration: String, goals: String, _tip: String) -> void:
	var card := _entry_panel(Color("30291d"),Color("786035"),12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.add_child(card)
	var content := _vbox(7)
	card.add_child(content)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation",10)
	content.add_child(title_row)
	var mode_title := _label("0%d  /  %s"%[id+1,title],21,Color("f4d99e"))
	mode_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(mode_title)
	var duration_label := _label(duration,14,Color("c5aa76"))
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(duration_label)
	var start := _entry_button("进入荒原  →" if id==0 else "出发  →",true)
	start.custom_minimum_size.y=40
	start.add_theme_font_size_override("font_size",17)
	start.tooltip_text = kicker
	start.pressed.connect(func() -> void: mode_selected.emit(id))
	title_row.add_child(start)
	var goal_label := _label(goals,16,Color("d1ba8a"))
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_goals.append(goal_label)
	start.tooltip_text=kicker+" · "+goals
	content.add_child(goal_label)
	_mode_buttons.append(start)

func set_economy(data: Dictionary) -> void:
	_build()
	_economy = data.duplicate(true)
	var assets := int(_economy.get("assets", 0))
	_menu_bank.text = "营地资产  %d G  ·  成功撤离后存入" % assets
	_camp_balance.text = "%d G" % assets
	var available := bool(_economy.get("camp_available", false))
	_camp_notice.text = "死亡会清空已购装备及弹药，需重新购买；营地资产和角色等级保留。成功完成后保留装备。" if available else "行动中暂不可交易，完成或结束本次行动后返回营地。"
	_camp_notice.add_theme_color_override("font_color", MUTED if available else AMBER)
	var message := str(_economy.get("message", ""))
	_camp_feedback.text = message
	_camp_feedback.visible = not message.is_empty()
	_abandon.visible = not available and bool(_economy.get("can_abandon",false))
	_camp_feedback.add_theme_color_override("font_color", RED if "不足" in message or "无法" in message or "失败" in message else GREEN)
	_refresh_camp_growth()
	_refresh_camp_items()

func show_camp() -> void:
	_build()
	_menu.visible = true
	_result.visible = false
	_hud.visible = false
	_menu_center.hide()
	_camp.show()
	_character_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_layout()
	_camp_back.call_deferred("grab_focus")

func _hide_camp() -> void:
	if not is_instance_valid(_camp):
		return
	_camp.hide()
	_menu_center.show()
	if _menu.visible:
		_character_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _make_camp() -> void:
	_camp = Control.new()
	_camp.name = "CampShop"
	_camp.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_child(_camp)
	_camp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camp_center = _scroll_center(_camp)
	_camp_panel = _panel(Color(0.047, 0.063, 0.058, 0.99), Color(0.55, 0.44, 0.28, 0.9), 28)
	_camp_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_camp_center.add_child(_camp_panel)
	var stack := _vbox(20)
	_camp_panel.add_child(stack)
	var heading := _vbox(8)
	stack.add_child(heading)
	heading.add_child(_label("CAMP  /  断桥营地", 17, AMBER))
	heading.add_child(_label("商店与角色成长", 32, PAPER))
	_camp_back = _button("← 返回角色与行动选择", false)
	_camp_back.name = "CampBack"
	_camp_back.custom_minimum_size.y = 46
	_camp_back.add_theme_font_size_override("font_size", 18)
	_camp_back.pressed.connect(func() -> void:
		_hide_camp()
		_camp_entry.call_deferred("grab_focus")
	)
	heading.add_child(_camp_back)
	var balance_panel := _panel(Color("1d291f"), Color("76623c"), 20)
	stack.add_child(balance_panel)
	var balance_stack := _vbox(5)
	balance_panel.add_child(balance_stack)
	balance_stack.add_child(_label("营地资产  /  已安全存入", 16, GREEN))
	_camp_balance = _label("0 G", 36, AMBER)
	_camp_balance.name = "BankBalance"
	balance_stack.add_child(_camp_balance)
	_camp_notice = _label("", 17, MUTED)
	_camp_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balance_stack.add_child(_camp_notice)
	_camp_feedback = _label("", 19, GREEN)
	_camp_feedback.name = "TransactionMessage"
	_camp_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camp_feedback.hide()
	stack.add_child(_camp_feedback)
	stack.add_child(_label("01  /  角色成长", 18, AMBER))
	var growth_note := _label("每位幸存者独立升级；选择想要培养的角色。", 17, MUTED)
	growth_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(growth_note)
	_camp_characters = GridContainer.new()
	_camp_characters.columns = 4
	_camp_characters.add_theme_constant_override("h_separation", 10)
	_camp_characters.add_theme_constant_override("v_separation", 10)
	stack.add_child(_camp_characters)
	for info in CharacterCatalog.CHARACTERS:
		var id: int = info.id
		var button := _entry_button(str(info.name), false)
		button.name = "CampCharacter%d" % id
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: _select_character(id))
		_camp_characters.add_child(button)
		_camp_character_buttons.append(button)
	var growth_panel := _panel(Color("18231e"), Color("4d5844"), 20)
	stack.add_child(growth_panel)
	_camp_growth = GridContainer.new()
	_camp_growth.columns = 2
	_camp_growth.add_theme_constant_override("h_separation", 28)
	_camp_growth.add_theme_constant_override("v_separation", 16)
	growth_panel.add_child(_camp_growth)
	var character_text := _vbox(10)
	character_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_growth.add_child(character_text)
	_camp_character = _label("", 25, PAPER)
	_camp_character.name = "CharacterLevel"
	_camp_character.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_text.add_child(_camp_character)
	_camp_bonuses = _label("", 17, MUTED)
	_camp_bonuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_text.add_child(_camp_bonuses)
	_camp_upgrade = _button("提升等级", true)
	_camp_upgrade.name = "UpgradeCharacter"
	_camp_upgrade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_camp_upgrade.add_theme_font_size_override("font_size", 18)
	_camp_upgrade.pressed.connect(func() -> void:
		if bool(_economy.get("camp_available", false)):
			upgrade_requested.emit()
	)
	_camp_growth.add_child(_camp_upgrade)
	stack.add_child(_rule())
	stack.add_child(_label("02  /  营地装备商店", 18, AMBER))
	var shop_note := _label("购买并装备后，右键朝准星开火，K 切换 4 倍瞄准镜。", 17, MUTED)
	shop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(shop_note)
	_camp_items = GridContainer.new()
	_camp_items.columns = 2
	_camp_items.add_theme_constant_override("h_separation", 16)
	_camp_items.add_theme_constant_override("v_separation", 16)
	stack.add_child(_camp_items)
	_abandon = _button("放弃本轮战利品 · 返回营地",false)
	_abandon.pressed.connect(func() -> void: abandon_requested.emit())
	stack.add_child(_abandon)
	set_economy(_economy)
	_camp.hide()

func _refresh_camp_growth() -> void:
	if not is_instance_valid(_camp_character):
		return
	var info := CharacterCatalog.get_info(selected_character_id)
	var level := int(_economy.get("level", 1))
	var maximum := int(_economy.get("max_level", 5))
	var cost := int(_economy.get("upgrade_cost", 0))
	var assets := int(_economy.get("assets", 0))
	var available := bool(_economy.get("camp_available", false))
	_camp_character.text = "%s  ·  等级 %d / %d" % [info.name, level, maximum]
	_camp_character.add_theme_color_override("font_color", info.accent)
	var cooldown := float(_economy.get("cooldown_multiplier", 1.0))
	var skill := CharacterCatalog.skill(selected_character_id)
	_camp_bonuses.text = "生命上限  %d\n%s冷却  %.1f 秒  ·  缩短 %d%%" % [int(_economy.get("max_health", 100)), skill.name, float(skill.cooldown) * cooldown, int(round((1.0 - cooldown) * 100.0))]
	_camp_upgrade.disabled = not available or level >= maximum or assets < cost
	if level >= maximum:
		_camp_upgrade.text = "已达到最高等级"
	elif not available:
		_camp_upgrade.text = "行动结束后可升级"
	elif assets < cost:
		_camp_upgrade.text = "升级需 %d G · 资产不足" % cost
	else:
		_camp_upgrade.text = "提升至 %d 级 · %d G" % [level + 1, cost]
	_camp_upgrade.tooltip_text = "角色成长永久保留，生命上限与专属技能冷却随等级提升。"
	for i in _camp_character_buttons.size():
		var selected := i == selected_character_id
		var button := _camp_character_buttons[i]
		button.add_theme_stylebox_override("normal", _style(Color("354631") if selected else Color("1c241f"), info.accent if selected else Color("59664f"), 2 if selected else 1))

func _refresh_camp_items() -> void:
	for child in _camp_items.get_children():
		_camp_items.remove_child(child)
		child.queue_free()
	var assets := int(_economy.get("assets", 0))
	var available := bool(_economy.get("camp_available", false))
	for value in _economy.get("items", []):
		var item: Dictionary = value
		var id := str(item.get("id", ""))
		var price := int(item.get("price", 0))
		var owned := bool(item.get("owned", false))
		var equipped := bool(item.get("equipped", false))
		var consumable := bool(item.get("consumable", false))
		var panel := _panel(Color("1b261f"), Color("526049") if equipped else Color("3e4b3c"), 20)
		panel.name = "Item_" + id
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_camp_items.add_child(panel)
		var content := _vbox(12)
		panel.add_child(content)
		var title := _label(str(item.get("name", id)), 23, PAPER)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)
		var state := "补给消耗品 · 死亡清空" if consumable else ("已装备 · 死亡丢失" if equipped else ("已购买 · 死亡丢失" if owned else "死亡后需重新购买"))
		content.add_child(_label(state, 15, GREEN if equipped else AMBER))
		var description := _label(str(item.get("description", "")), 17, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(description)
		var action := _button("", not owned or consumable)
		action.name = "ItemAction_" + id
		action.custom_minimum_size.y = 48
		action.add_theme_font_size_override("font_size", 17)
		action.disabled = not available or (equipped and not consumable and id!="repulsor") or ((not owned or consumable) and assets < price)
		if not available:
			action.text = "行动结束后可交易"
		elif equipped and not consumable:
			action.text = "收起武器" if id=="repulsor" else "已装备"
		elif owned and not consumable:
			action.text = "装备"
		elif assets < price:
			action.text = "%d G · 资产不足" % price
		else:
			action.text = "%s · %d G" % ["购买补给" if consumable else "购买装备", price]
		action.pressed.connect(func() -> void:
			if not bool(_economy.get("camp_available", false)):
				return
			if owned and not consumable:
				equip_requested.emit("" if equipped and id=="repulsor" else id)
			else:
				purchase_requested.emit(id)
		)
		content.add_child(action)

func _add_character_picker(stack: VBoxContainer) -> void:
	stack.add_child(_label("01  /  幸存者档案", 17, Color("ddbc78")))
	_preview_panel = _entry_panel(Color("4a3b23"), Color("8a7041"), 0)
	_preview_panel.custom_minimum_size = Vector2(0, 260)
	stack.add_child(_preview_panel)
	_character_container = SubViewportContainer.new()
	_character_container.stretch = true
	_character_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_character_container.gui_input.connect(_preview_input)
	_character_container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_preview_panel.add_child(_character_container)
	_character_view = SubViewport.new()
	_character_view.size = Vector2i(530, 354)
	_character_view.gui_disable_input = true
	_character_view.msaa_3d = Viewport.MSAA_4X
	_character_view.transparent_bg = false
	_character_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_character_view.own_world_3d = true
	_character_container.add_child(_character_view)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("4a3b23")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3c9ca")
	env.ambient_light_energy = 0.50
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	_character_view.add_child(environment)
	var portrait_back := MeshInstance3D.new()
	var portrait_plane := QuadMesh.new()
	portrait_plane.size=Vector2(8,4.5)
	portrait_back.mesh=portrait_plane
	portrait_back.position=Vector3(0,1.4,-1.8)
	portrait_back.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var portrait_material := ShaderMaterial.new()
	portrait_material.shader=preload("res://wasteland_portrait.gdshader")
	portrait_material.set_shader_parameter("scene",load("res://assets/menu/wasteland-entry.png"))
	portrait_back.material_override=portrait_material
	_character_view.add_child(portrait_back)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe6cc")
	key.light_energy = 1.45
	key.rotation_degrees = Vector3(-28, -35, 0)
	_character_view.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color("dcc48b")
	fill.light_energy = 1.1
	fill.omni_range = 5.0
	fill.position = Vector3(-2.0, 2.0, 2.2)
	_character_view.add_child(fill)
	var camera := Camera3D.new()
	_preview_camera = camera
	camera.position = Vector3(0, 1.47, _preview_distance)
	camera.fov = 34.0
	camera.current = true
	_character_view.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.40, 0), Vector3.UP)
	_character_name = _label("", 28, PAPER)
	stack.add_child(_character_name)
	_character_subtitle = _label("", 16, MUTED)
	_character_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_character_subtitle)
	_character_detail = _label("", 16, MUTED)
	_character_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_character_detail)
	_character_grid = GridContainer.new()
	_character_grid.columns = 2
	_character_grid.add_theme_constant_override("h_separation", 10)
	_character_grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(_character_grid)
	for info in CharacterCatalog.CHARACTERS:
		var id: int = info.id
		var button := _entry_button(str(info.name), false)
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func() -> void: _select_character(id))
		_character_grid.add_child(button)
		_character_buttons.append(button)
	var hint := _label("拖动旋转 · 滚轮查看脸部 / 全身 · 暂停换人保留进度", 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)
	set_character_selected(selected_character_id)

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_preview_distance=clampf(_preview_distance+(-.16 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .16),.72,3.8)
		var focus := lerpf(1.68,.91,clampf((_preview_distance-.72)/3.08,0,1))
		_preview_camera.position=Vector3(0,focus+.035,_preview_distance)
		_preview_camera.look_at(Vector3(0,focus,0))
		_character_container.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_preview_dragging = event.pressed
		_character_container.accept_event()
	elif event is InputEventMouseMotion and _preview_dragging:
		_preview_yaw += event.relative.x * 0.011
		_character_container.accept_event()

func _refresh_preview() -> void:
	if not is_instance_valid(_character_view):
		return
	if _preview_model_id == selected_character_id and is_instance_valid(_preview_model):
		return
	if is_instance_valid(_preview_model):
		_character_view.remove_child(_preview_model)
		_preview_model.queue_free()
		_preview_model = null
	var script_resource: Script
	if selected_character_id == 0:
		script_resource = load("res://reference_survivor.gd")
	else:
		script_resource = RosterSurvivor

	_preview_model = script_resource.new()
	if selected_character_id > 0:
		_preview_model.set("archetype", selected_character_id)
	_preview_model.name = "CharacterPreview"
	_preview_model.rotation.y = PI
	_preview_yaw = PI
	_preview_model_id = selected_character_id
	_character_view.add_child(_preview_model)

func _modal(node_name: String, tint: Color) -> Control:
	var root := Control.new()
	root.name = node_name
	root.theme = _theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = tint
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root

func _scroll_center(parent: Control) -> CenterContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.offset_top = 24
	scroll.offset_bottom = -24
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	return center

func _layout() -> void:
	if not _built or not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var menu_width := minf(1460.0, maxf(280.0, viewport_size.x - 64.0))
	_menu_panel.custom_minimum_size.x = menu_width
	_result_panel.custom_minimum_size.x = minf(940.0, maxf(300.0, viewport_size.x - 80.0))
	_menu_center.custom_minimum_size.y = maxf(0, viewport_size.y - 48)
	_result_center.custom_minimum_size.y = maxf(0, viewport_size.y - 48)
	var camp_width := minf(1100.0, maxf(300.0, viewport_size.x - 80.0))
	_camp_panel.custom_minimum_size.x = camp_width
	_camp_center.custom_minimum_size.y = maxf(0, viewport_size.y - 48)
	_camp_characters.columns = 4 if camp_width >= 850 else (2 if camp_width >= 430 else 1)
	_camp_growth.columns = 2 if camp_width >= 850 else 1
	_camp_items.columns = 2 if camp_width >= 850 else 1
	_result_actions.vertical = viewport_size.x < 820
	_result_stats.columns=3 if viewport_size.x>=640 else 1
	_menu_body.columns = 2 if menu_width >= 1080 else 1
	_character_grid.columns = 2 if menu_width >= 450 else 1
	_menu_actions.vertical = menu_width < 480
	_menu_edition.visible = menu_width >= 700
	var compact_entry := viewport_size.y<850 and menu_width>=1080
	_entry_question.visible=not compact_entry
	_entry_mission_column.add_theme_constant_override("separation",8 if compact_entry else 12)
	for goal in _entry_goals: goal.visible=not compact_entry
	_menu_heading.add_theme_font_size_override("font_size", (64 if viewport_size.y>=850 else 48) if menu_width>=700 else 38)
	_preview_panel.custom_minimum_size.y = clampf(viewport_size.y-600.0,140.0,300.0) if menu_width>=1030 else 230.0
	var compact := viewport_size.y<850 or viewport_size.x<1200
	var bottom_height := 176.0 if compact else 178.0
	_vitals.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_vitals.position=Vector2(24,viewport_size.y-bottom_height-20)
	_vitals.size=Vector2(viewport_size.x-48,bottom_height)
	_stats.add_theme_font_size_override("font_size",16 if compact else 20)
	_mission_box.position=Vector2(viewport_size.x-minf(460,viewport_size.x*.38)-24,76)
	_mission_box.size.x=minf(460,viewport_size.x*.38)
	_mode.add_theme_font_size_override("font_size",23 if compact else 28)
	_objective.add_theme_font_size_override("font_size",17 if compact else 20)
	_target.add_theme_font_size_override("font_size",16)
	_extraction_guide.add_theme_font_size_override("font_size",15)
	_mission_box.visible=not (is_instance_valid(_tutorial_panel) and _tutorial_panel.visible)
	_menu_button.offset_left=-134
	_menu_button.offset_right=-24
	_menu_button.offset_top=16
	_menu_button.offset_bottom=56
	_menu_button.custom_minimum_size=Vector2(110,40)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_left=24
	_hint.offset_right=-152
	_hint.offset_top=18
	_hint.offset_bottom=60
	_hint.add_theme_font_size_override("font_size",13 if compact else 16)
	_hint.text="WASD 移动  Shift 奔跑  空格 跳跃  左键拖动 视角  E 交互  Q 治疗  B 搭建  F 驱兽  C 技能  右键开火 · K 倍镜 · G/H/T 小队标记"
	_prompt_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_prompt_box.position=Vector2(24,viewport_size.y-bottom_height-86)
	_prompt_box.size=Vector2(viewport_size.x-48,48)
	_prompt.add_theme_font_size_override("font_size",18)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_toast.position=Vector2(viewport_size.x*.25,viewport_size.y-bottom_height-152)
	_toast.size=Vector2(viewport_size.x*.5,52)
	_toast.add_theme_font_size_override("font_size",18)
	if is_instance_valid(_minimap):
		_minimap.place()
		var prompt_left := _minimap.position.x+_minimap.size.x+18
		var prompt_width := maxf(240,_mission_box.position.x-prompt_left-18)
		_prompt_box.position=Vector2(prompt_left,76)
		_prompt_box.size=Vector2(prompt_width,62)
		_toast.position=Vector2(prompt_left,154)
		_toast.size=Vector2(prompt_width,80)
	if is_instance_valid(_tutorial_panel): _tutorial_panel._queue_layout()
	_fit_vitals.call_deferred()

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _vbox(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box

func _panel(fill: Color, border: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(fill, border, 1)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style

func _rule() -> HSeparator:
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxLine.new()
	line.color = Color(0.63, 0.61, 0.46, 0.27)
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator

func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 58
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	button.add_theme_color_override("font_pressed_color", INK if primary else PAPER)
	button.add_theme_color_override("font_focus_color", INK if primary else PAPER)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var normal := _style(AMBER if primary else Color(0.11, 0.14, 0.12, 0.94), AMBER if primary else Color(0.41, 0.45, 0.35, 1), 1)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _style(Color("ffcd88") if primary else Color("283329"), AMBER, 1))
	button.add_theme_stylebox_override("pressed", _style(Color("ce914a") if primary else Color("35402f"), AMBER, 1))
	var disabled := _style(Color("202a23"), Color("44513f"), 1)
	disabled.content_margin_left = 16
	disabled.content_margin_right = 16
	button.add_theme_stylebox_override("disabled", disabled)
	var focus := _style(Color.TRANSPARENT, PAPER, 2)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	button.add_theme_stylebox_override("focus", focus)
	return button

func set_region_selected(id: int) -> void:
	selected_region_id=clampi(id,0,RegionLayout.REGIONS.size()-1)
	_region_picker.select(selected_region_id)
	_region_description.text=RegionLayout.REGIONS[selected_region_id].description+" · 点击下方模式出发"

func _entry_panel(fill: Color, border: Color, padding: int) -> PanelContainer:
	var panel := _panel(fill,border,padding)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_corner_radius_all(0)
	style.border_width_top=3
	style.shadow_color=Color(0,0,0,.2)
	style.shadow_size=6
	panel.add_child(preload("res://wasteland_menu_wear.gd").new())
	return panel

func _entry_button(value: String, primary: bool) -> Button:
	var button := _button(value,primary)
	button.add_theme_font_size_override("font_size",17)
	_entry_button_style(button,primary)
	return button

func _entry_button_style(button: Button, primary: bool) -> void:
	var ink := Color("292115")
	var gold := Color("e9bb50")
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,ink if primary else Color("f1dca9"))
	for state in ["normal","hover","pressed"]:
		var fill := gold if primary else Color("40341f")
		if state=="hover": fill=Color("ffdc83") if primary else Color("68502c")
		if state=="pressed": fill=Color("bd8c31") if primary else Color("2e261a")
		var style := _style(fill,Color("c99c47") if primary else Color("8f7444"),1)
		style.set_corner_radius_all(0)
		style.content_margin_left=12
		style.content_margin_right=12
		style.content_margin_top=4
		style.content_margin_bottom=4
		button.add_theme_stylebox_override(state,style)
	button.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,Color("fff0b0"),2))

func _fit_prompt() -> void:
	if is_instance_valid(_prompt_box):
		_prompt_box.size.y=_prompt_box.get_combined_minimum_size().y
		if is_instance_valid(_toast): _toast.position.y=maxf(154,_prompt_box.position.y+_prompt_box.size.y+12) if _prompt_box.visible else 154

func _fit_vitals() -> void:
	if not is_instance_valid(_vitals): return
	var viewport_size := get_viewport().get_visible_rect().size
	_vitals.size=Vector2(viewport_size.x-48,_vitals.get_combined_minimum_size().y)
	_vitals.position=Vector2(24,viewport_size.y-_vitals.size.y-20)
