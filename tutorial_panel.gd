extends Control
## A compact, non-modal field guide. Gameplay decides when each step is complete.

signal next_requested
signal skip_requested

const PAPER := Color("eee7d6")
const MUTED := Color("b7b8a9")
const AMBER := Color("efb365")
const GREEN := Color("8ab79a")

var _card: PanelContainer
var _body: VBoxContainer
var _counter: Label
var _title: Label
var _instruction: Label
var _keys: Label
var _progress: Label
var _protection: Label
var _steps: ProgressBar
var _scroll: ScrollContainer
var _copy: VBoxContainer
var _next: Button
var _skip: Button
var _illustration: TextureRect
var _checklist: Label
var _pointer: Control
var camera: Camera3D
var focus_control: Control
var _image_path := ""
var _data: Dictionary = {}
var _layout_pending := false
var _compact_mode := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_queue_layout)
	_card.minimum_size_changed.connect(_queue_layout)
	_copy.minimum_size_changed.connect(_queue_layout)
	_apply()

func present(data: Dictionary) -> void:
	if data == _data:
		return
	_data = data.duplicate()
	if is_node_ready():
		_apply()

func _build() -> void:
	var guide_theme := Theme.new()
	guide_theme.default_font_size = 17
	if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf"):
		var font := FontVariation.new()
		font.base_font = load("res://assets/fonts/NotoSansSC.ttf") as Font
		font.variation_opentype = {2003265652: 450.0}
		guide_theme.default_font = font
	guide_theme.set_color("font_color", "Label", PAPER)
	guide_theme.set_color("font_color", "Button", PAPER)
	guide_theme.set_color("font_hover_color", "Button", Color.WHITE)
	guide_theme.set_color("font_disabled_color", "Button", MUTED)
	guide_theme.set_stylebox("normal", "Button", _style(Color("28352f"), Color("566555"), 1, 10))
	guide_theme.set_stylebox("hover", "Button", _style(Color("394a3d"), AMBER, 1, 10))
	guide_theme.set_stylebox("pressed", "Button", _style(Color("1b2822"), GREEN, 1, 10))
	guide_theme.set_stylebox("disabled", "Button", _style(Color("222925"), Color("454e43"), 1, 10))
	theme = guide_theme
	_pointer=preload("res://tutorial_pointer.gd").new()
	_pointer.name="TutorialPointer"
	add_child(_pointer)
	_card = PanelContainer.new()
	_card.name = "GuideCard"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", _style(Color(0.055, 0.075, 0.065, 0.96), Color("687760"), 1, 18))
	add_child(_card)
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_constant_override("separation", 8)
	_card.add_child(_body)
	_counter = _label("", 14, AMBER)
	_body.add_child(_counter)
	_steps = ProgressBar.new()
	_steps.custom_minimum_size.y = 3
	_steps.show_percentage = false
	_steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steps.add_theme_stylebox_override("background", _style(Color("303a32"), Color.TRANSPARENT, 0, 0))
	_steps.add_theme_stylebox_override("fill", _style(AMBER, Color.TRANSPARENT, 0, 0))
	_body.add_child(_steps)
	_title = _label("", 22, PAPER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_title)
	_illustration=TextureRect.new()
	_illustration.name="InstructionIllustration"
	_illustration.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_illustration.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_illustration.custom_minimum_size.y=128
	_body.add_child(_illustration)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(_scroll)
	_copy = VBoxContainer.new()
	_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy.add_theme_constant_override("separation", 5)
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_copy)
	_instruction = _label("", 17, PAPER)
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy.add_child(_instruction)
	_checklist=_label("",16,PAPER)
	_checklist.name="ActionChecklist"
	_checklist.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_copy.add_child(_checklist)
	_keys = _label("", 16, GREEN)
	_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_keys)
	_body.move_child(_keys,_illustration.get_index()+1)
	_progress = _label("", 15, AMBER)
	_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_progress)
	_protection = _label("练习保护 · 任务计时暂停", 14, GREEN)
	_body.add_child(_protection)
	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 10)
	_body.add_child(actions)
	_next = Button.new()
	_next.name = "NextStep"
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size.y = 42
	_next.pressed.connect(func(): next_requested.emit())
	actions.add_child(_next)
	_skip = Button.new()
	_skip.name = "SkipTutorial"
	_skip.text = "跳过教程"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.custom_minimum_size.y = 42
	_skip.tooltip_text = "结束引导，继续当前行动。之后可在主菜单重新练习。"
	_skip.pressed.connect(func(): skip_requested.emit())
	actions.add_child(_skip)

func _apply() -> void:
	visible = bool(_data.get("visible", false))
	var total := maxi(1, int(_data.get("total", 1)))
	var step := clampi(int(_data.get("step", 1)), 1, total)
	_counter.text = "新手引导   %02d / %02d" % [step, total]
	_steps.max_value = total
	_steps.value = step - 1 + clampf(float(_data.get("progress", 0.0)), 0.0, 1.0)
	_title.text = str(_data.get("title", "欢迎来到废土"))
	_instruction.text = str(_data.get("body", _data.get("instruction", "")))
	_checklist.text="\n".join(_data.get("checklist",[]))
	var image_path: String=_data.get("image","")
	if image_path!=_image_path:
		_image_path=image_path
		_illustration.texture=load(image_path) if not image_path.is_empty() and ResourceLoader.exists(image_path) else null
		_scroll.scroll_vertical=0
	_illustration.visible=_illustration.texture!=null
	_pointer.camera=camera
	_pointer.focus_control=focus_control
	_pointer.card=_card
	_pointer.data=_data
	_keys.text = str(_data.get("keys", ""))
	_keys.visible = not _keys.text.is_empty()
	_progress.text = str(_data.get("hint", ""))
	_progress.visible = not _progress.text.is_empty()
	_protection.visible = bool(_data.get("protected", true)) and _compact_mode != 1
	if _compact_mode == 1:
		_counter.text = "%02d / %02d   练习保护 · 任务计时暂停" % [step, total]
	_next.disabled = not bool(_data.get("can_advance", false))
	_next.text = str(_data.get("next_text", _data.get("action_label", "继续"))) if not _next.disabled else "完成操作后继续"
	_queue_layout()

func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_layout.call_deferred()

func _layout() -> void:
	_layout_pending = false
	if not is_instance_valid(_card):
		return
	var extent := size
	if extent.x <= 1.0 or extent.y <= 1.0:
		extent = get_viewport_rect().size
	var compact := extent.y < 800.0
	var left := (264.0 if extent.y<850.0 or extent.x<1200.0 else 310.0)+42.0
	var width := minf(430.0 if compact else 480.0, maxf(280.0, extent.x - left * 2.0))
	if _compact_mode != int(compact):
		_compact_mode = int(compact)
		var padding := 14 if compact else 18
		_card.add_theme_stylebox_override("panel", _style(Color(0.055, 0.075, 0.065, 0.96), Color("687760"), 1, padding))
		_body.add_theme_constant_override("separation", 5 if compact else 8)
		_title.add_theme_font_size_override("font_size", 20 if compact else 22)
		_illustration.custom_minimum_size.y=112 if compact else 140
		_instruction.add_theme_font_size_override("font_size", 16 if compact else 17)
		_next.add_theme_font_size_override("font_size", 15 if compact else 16)
		_skip.add_theme_font_size_override("font_size", 15 if compact else 16)
		_next.custom_minimum_size.y = 36.0 if compact else 42.0
		_skip.custom_minimum_size.y = _next.custom_minimum_size.y
		_protection.visible = bool(_data.get("protected", true)) and not compact
		_counter.text = ("%02d / %02d   练习保护 · 任务计时暂停" if compact else "新手引导   %02d / %02d") % [maxi(1,int(_data.get("step",1))),maxi(1,int(_data.get("total",1)))]
	_card.size.x = width
	var overhead := _card.get_combined_minimum_size().y-_scroll.get_combined_minimum_size().y
	var available := maxf(45.0,extent.y-208.0-76.0-overhead)
	_scroll.custom_minimum_size.y = clampf(_copy.get_combined_minimum_size().y,45.0,minf(available,210.0 if compact else 270.0))
	_card.size.y = _card.get_combined_minimum_size().y
	_card.position = Vector2(left,76)

func _label(value: String, font_size: int, tint: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tint)
	return result

func _style(fill: Color, edge: Color, border: int, padding: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = edge
	result.set_border_width_all(border)
	result.set_corner_radius_all(5)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result
