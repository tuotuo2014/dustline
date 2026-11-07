extends Node
## Mobile lifecycle: never leave a single-player expedition running in background.
var game: Node3D

func _ready() -> void:
	name="MobileRuntime"
	process_mode=Node.PROCESS_MODE_ALWAYS
	Engine.max_fps=60
	get_tree().quit_on_go_back=false

func _notification(what: int) -> void:
	if not is_instance_valid(game) or not game.is_node_ready(): return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_pause_action()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		_pause_action()

func _pause_action() -> void:
	if is_instance_valid(game.player.mobile_controls):
		game.player.mobile_controls.release_all()
	if game.active and not game.round_over:
		game.open_menu()
