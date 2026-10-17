extends Node

var _first_web_input: bool = OS.has_feature("web")


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if key and key.pressed and not key.echo and key.keycode == KEY_F11:
		_first_web_input = false
		var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		var fullscreen: bool = mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		_set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()
	elif _first_web_input:
		var key_pressed: bool = key != null and key.pressed and not key.echo
		var clicked: bool = mouse != null and mouse.pressed and mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
		if key_pressed or clicked:
			_first_web_input = false
			_set_fullscreen(true)


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	get_node(^"/root/Feel").call(&"play", &"ui/click")
