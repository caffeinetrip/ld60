extends Node
## F11 = fullscreen (on the web the first click too), F4 = hide all UI for clean shots.

const KEEP_LAYERS := [&"ScreenFX", &"Letterbox", &"RoomView", &"CornerLeaves", &"RetroPost"]	# canvas layers that are part of the picture, not UI

var ui_hidden := false

var _first_web_input: bool = OS.has_feature("web")
var _hidden: Array[Node] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if key and key.pressed and not key.echo and key.keycode == KEY_F11:
		_first_web_input = false
		var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		var fullscreen: bool = mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		_set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()
	elif key and key.pressed and not key.echo and key.keycode == KEY_F4:
		set_ui_hidden(not ui_hidden)
		get_viewport().set_input_as_handled()
	elif _first_web_input:
		var key_pressed: bool = key != null and key.pressed and not key.echo
		var clicked: bool = mouse != null and mouse.pressed and mouse.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
		if key_pressed or clicked:
			_first_web_input = false
			_set_fullscreen(true)


## Hides every UI layer and the UI that lives in the world (speech bubbles, floating text,
## nodes in the "ui" group), also the ones that appear while hidden. Showing it again
## brings back only what was hidden here.
func set_ui_hidden(hide_ui: bool) -> void:
	if hide_ui == ui_hidden:
		return
	ui_hidden = hide_ui
	if hide_ui:
		_hide_in(get_tree().root)
		return
	for node in _hidden:
		if is_instance_valid(node):
			node.set(&"visible", true)
	_hidden.clear()


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	get_node(^"/root/Feel").call(&"play", &"ui/click")


func _hide_in(node: Node) -> void:
	if node is CanvasLayer and not _is_ui(node):
		return
	if _is_ui(node):
		_hide(node)
		return
	for child in node.get_children():
		_hide_in(child)


## A UI root: a canvas layer that isn't the picture, a "ui" group member, or text / a panel
## that sits in the world rather than inside another Control.
func _is_ui(node: Node) -> bool:
	if node is CanvasLayer:
		return not KEEP_LAYERS.has(node.name) and node.get_parent() != get_node_or_null(^"/root/Feel")
	# world rects (the cafe's black Void) are the picture; text and panels are UI
	var world_ui := (node is Label or node is Container) and not node.get_parent() is Control
	return node.is_in_group(&"ui") or world_ui


func _hide(node: Node) -> void:
	if node.get(&"visible"):
		node.set(&"visible", false)
		_hidden.append(node)


func _on_node_added(node: Node) -> void:
	if ui_hidden:
		_hide_new.call_deferred(node)


func _hide_new(node: Node) -> void:
	if not ui_hidden or not is_instance_valid(node) or not node.is_inside_tree() or not _is_ui(node):
		return
	var up := node.get_parent()
	while up:
		if up is CanvasLayer or _hidden.has(up):
			return
		up = up.get_parent()
	_hide(node)
