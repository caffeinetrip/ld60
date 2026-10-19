extends Node
## A short reveal for UI roots without their own opacity animation.

const DURATION := 0.25
var _item: CanvasItem
var _opacity := 1.0
var _fade: Tween


static func attach(item: CanvasItem) -> void:
	if item.has_node("UIAppear"):
		return
	var effect := new()
	effect.name = "UIAppear"
	item.add_child(effect)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_item = get_parent() as CanvasItem
	_opacity = _item.modulate.a
	_item.visibility_changed.connect(_reveal)
	_reveal()


func _reveal() -> void:
	if _fade:
		_fade.kill()
	if not _item.is_visible_in_tree():
		_item.modulate.a = _opacity
		return
	_item.modulate.a = 0.0
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_item, "modulate:a", _opacity, DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
