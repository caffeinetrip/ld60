class_name Cat extends Node2D

signal arrived

enum Mood { HAPPY, SAD, ANGRY }

const COLORS := [Color("e4cda4"), Color("aaa5b1"), Color("ce9669"), Color("534957"), Color("eee5d8")]

var kind: StringName = &"normal"
var walking := false
var held := false
var facing := 1.0
var hop := 0.0
var _target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _color := Color.WHITE
var _step := 0.0
var _steps := 0
var _age := 0.0
var _bubble: PanelContainer
var _fade: Tween


func _ready() -> void:
	_color = COLORS[_rng.randi_range(0, COLORS.size() - 1)]


func walk_to(p: Vector2) -> void:
	_target = p
	walking = true


func _process(delta: float) -> void:
	_age += delta
	if walking and not held:
		var dx := _target.x - global_position.x
		if absf(dx) > 0.1:
			facing = signf(dx)
		global_position = global_position.move_toward(_target, Tune.CAT_SPEED * delta)
		_step += delta
		while _step >= 0.15:
			_step -= 0.15
			_steps += 1
			if _steps % 2 == 0:
				Feel.play(&"cat/step", global_position)
		if global_position.is_equal_approx(_target):
			walking = false
			arrived.emit()
	if is_instance_valid(_bubble):
		_place_bubble()
	queue_redraw()


func say(text: String, seconds := 1.6) -> void:
	if _fade:
		_fade.kill()
	if is_instance_valid(_bubble):
		_bubble.free()
	_bubble = PanelContainer.new()
	_bubble.z_index = 80
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2b1d2e")
	style.border_color = Color("c9a24a")
	style.set_border_width_all(1)
	style.content_margin_left = 3
	style.content_margin_right = 3
	_bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font: Font = ThemeDB.get_project_theme().default_font
	label.custom_minimum_size.x = minf(300.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	_bubble.add_child(label)
	add_child(_bubble)
	_bubble.reset_size()
	_place_bubble()
	_fade = create_tween()
	_fade.tween_interval(maxf(0.0, seconds - 0.3))
	_fade.tween_property(_bubble, "modulate:a", 0.0, minf(seconds, 0.3))
	_fade.tween_callback(_bubble.queue_free)


func _place_bubble() -> void:
	var at := get_global_transform_with_canvas().origin
	var desired := at + Vector2(-_bubble.size.x / 2.0, -32.0 if kind != &"boss" else -44.0)
	desired.x = clampf(desired.x, 0.0, maxf(0.0, 320.0 - _bubble.size.x))
	desired.y = clampf(desired.y, 0.0, maxf(0.0, 180.0 - _bubble.size.y))
	_bubble.position = (desired - at).round()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 5.0 if kind != &"boss" else 10.0, Color(0, 0, 0, 0.3))
	var bob := float(_steps % 2) if walking and not held else 0.0
	var scale_size := 2.0 if kind == &"boss" else 1.0
	draw_set_transform(Vector2(0, -bob - hop), 0.0, Vector2(facing * scale_size, scale_size))
	var ink := Color("2b1d2e")
	var color := Color("49334f") if kind == &"boss" else (Color("7a6a5a") if kind == &"homeless" else _color)
	var outline := Color("ffd34d") if kind == &"special" else ink
	draw_rect(Rect2(-5, -11, 11, 12), outline)
	draw_rect(Rect2(-4, -10, 9, 10), color)
	var ears := [PackedVector2Array([Vector2(-5, -10), Vector2(-5, -15), Vector2(0, -10)]), PackedVector2Array([Vector2(1, -10), Vector2(5, -13 if kind == &"homeless" else -15), Vector2(6, -10)])]
	for ear: PackedVector2Array in ears:
		draw_colored_polygon(ear, color)
		draw_polyline(PackedVector2Array([ear[0], ear[1], ear[2], ear[0]]), outline, 1.0)
	draw_rect(Rect2(2, -8, 1, 1), ink)
	if kind == &"homeless":
		draw_rect(Rect2(-3, -8, 3, 3), Color("51483f"))
		draw_rect(Rect2(1, -4, 3, 2), Color("51483f"))
		for i in 3:
			var line := PackedVector2Array()
			for j in 5:
				line.append(Vector2(-4 + i * 4 + roundf(sin(_age * 4.0 + j + i)), -18 - j))
			draw_polyline(line, Color("9c8a99"), 1.0)
	if kind == &"special":
		draw_string(ThemeDB.get_project_theme().default_font, Vector2(-2, -17), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, outline)
