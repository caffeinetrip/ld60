extends Node2D
## Dialogue sandbox: LMB plays intro, then win. `-- capture` saves shots and quits.

@onready var _dialogue: Node = $Dialogue
@onready var _info: Label = $UI/Info

var _busy := false


func _ready() -> void:
	_dialogue.skip_all = false
	if OS.get_cmdline_user_args().has("capture"):
		_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _busy:
		_go()


func _go() -> void:
	_busy = true
	_info.hide()
	await _dialogue.play(&"intro")
	await _dialogue.play(&"win")
	_info.show()
	_busy = false


func _capture() -> void:
	await _shot("idle")
	_go()
	await get_tree().create_timer(0.4).timeout
	await _shot("typing")
	_dialogue.advance()
	await get_tree().create_timer(0.1).timeout
	await _shot("sister")
	_dialogue.advance()
	await get_tree().create_timer(2.0).timeout
	await _shot("hero")
	for i in 7:
		_dialogue.advance()
	await get_tree().create_timer(0.1).timeout
	await _shot("two_rows")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/dialogue_%s.png" % label)
