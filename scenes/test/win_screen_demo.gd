extends Node2D
## WinScreen on its own. Clicks step through: the result, a dialogue over it with the game
## paused, the button. Play again starts over.

const STATS := {time = 754.0, days = 9, week = 2400, tries = 3}

@onready var _win: WinScreen = $UI/WinScreen
@onready var _info: Label = $UI/Info
@onready var _dialogue: Control = $Dialogue/Box

var _step := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_win.play_again.connect(_restart)
	_dialogue.hide()
	_refresh()
	if OS.get_cmdline_user_args().has("capture"):
		_capture.call_deferred()


# _input, because the win screen takes the clicks that land on it
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _step >= 3:
		return
	_next()
	get_viewport().set_input_as_handled()


func _next() -> void:
	match _step:
		0:
			_win.show_result(STATS)
		1:
			_dialogue.show()
			get_tree().paused = true
		2:
			_dialogue.hide()
			get_tree().paused = false
			_win.show_button()
	_step += 1
	_refresh()


func _restart() -> void:
	_win.hide()
	_step = 0
	_refresh()


func _refresh() -> void:
	_info.text = ["click: show the result", "click: dialogue (paused)", "click: show the button", ""][_step]


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	await get_tree().create_timer(0.2).timeout
	_next()
	await get_tree().create_timer(0.15).timeout
	await _shot("open")
	await get_tree().create_timer(0.5).timeout
	await _shot("rows")
	await get_tree().create_timer(1.5).timeout
	await _shot("result")
	_next()
	await get_tree().create_timer(1.0).timeout
	await _shot("dialogue")
	_next()
	await get_tree().create_timer(0.4).timeout
	await _shot("button")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/win_%s.png" % label)
