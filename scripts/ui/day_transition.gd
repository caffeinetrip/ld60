extends CanvasLayer
## A quiet warm veil, paired with gradual lighting and UI fades.

var _rect := ColorRect.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	layer = 90 # Below the shared CRT pass, above game UI.
	_material.shader = preload("res://shaders/day_transition.gdshader")
	_material.set_shader_parameter("base_color", HudStyle.INK)
	_material.set_shader_parameter("factor", 0.0)
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.hide()


func cover(duration_scale := 1.0) -> void:
	_rect.show()
	await _animate(1.0, 0.35 * duration_scale)


func reveal(duration_scale := 1.0) -> void:
	await _animate(0.0, 0.55 * duration_scale)
	_rect.hide()


func _animate(target: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_material, "shader_parameter/factor", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _input(event: InputEvent) -> void:
	if _rect.visible and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
