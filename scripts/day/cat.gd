class_name Cat extends Node2D

signal arrived

enum Mood { HAPPY, SAD, ANGRY }
# rows of a sheet (tools/cat_art.py): 4 frames each, walk rows face right
enum Row { IDLE, BLINK, HAPPY, SAD, WALK, WALK_HAPPY, WALK_SAD }

const SHEETS := {
	&"doodle": preload("res://art/cats/doodle.png"),
	&"kuro": preload("res://art/cats/kuro.png"),
	&"calico": preload("res://art/cats/calico.png"),
	&"pup": preload("res://art/cats/pup.png"),
}
const FUR := {&"doodle": Color("d4cab6"), &"kuro": Color("3e3840"), &"calico": Color("dbd4c8"), &"pup": Color("dbd4c8")}
const COLORS := [Color("d4cab6"), Color("3e3840"), Color("dbd4c8")]
const CELL := Vector2(32, 40)
const FOOT := 30.0		# the feet's row in a cell
const IDLE_FRAME := 0.3
const TOP := 24.0		# ear tips over the feet

var day: Node
var kind: StringName = &"normal"
var minigame_completed := false
var look: StringName = &"doodle"
var walking := false
var held := false
var queue_managed := false
var facing := 1.0
var hop := 0.0
var _target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _tint := Color.WHITE
var _step := 0.0
var _steps := 0
var _age := 0.0
var _blink := 2.0
var _mood := Mood.HAPPY
var _mood_time := 0.0
var _bubble: Control
var _bubble_layer: CanvasLayer		# speech sits over the grade and the black bars
var _fade: Tween


func _ready() -> void:
	# Visitors stay above furniture and payment particles, below floating text.
	z_index = 55
	material = preload("res://art/cats/fur.tres")
	_age = _rng.randf() * 4.0
	_blink = _rng.randf_range(0.5, 3.0)
	match kind:
		&"boss":
			look = &"kuro"
		&"homeless":
			look = &"doodle"
			_tint = Color(0.72, 0.65, 0.58)
		_:
			look = SHEETS.keys()[_rng.randi_range(0, SHEETS.size() - 1)]


## A face for a while: happy eyes, or droopy ones for sad and angry.
func show_mood(mood: Mood, seconds := 1.6) -> void:
	_mood = mood
	_mood_time = seconds


func walk_to(p: Vector2) -> void:
	_target = p
	walking = true


func _process(delta: float) -> void:
	_age += delta
	_mood_time -= delta
	_blink -= delta
	if _blink < -0.12:
		_blink = _rng.randf_range(1.5, 4.5)
	if walking and not held and not queue_managed:
		var dx := _target.x - global_position.x
		if absf(dx) > 0.1:
			facing = signf(dx)
		global_position = global_position.move_toward(_target, Tune.CAT_SPEED * delta)
		_walk_animation(delta)
		if global_position.is_equal_approx(_target):
			walking = false
			arrived.emit()
	if is_instance_valid(_bubble):
		_place_bubble()
	queue_redraw()


## The queue controls distance along one shared lane, including its corners.
func follow_queue(at: Vector2, delta: float) -> void:
	walking = not global_position.is_equal_approx(at)
	held = false
	if not walking:
		return
	var dx := at.x - global_position.x
	if absf(dx) > 0.01:
		facing = signf(dx)
	global_position = at
	_walk_animation(delta)


func _walk_animation(delta: float) -> void:
	_step += delta
	while _step >= 0.15:
		_step -= 0.15
		_steps += 1
		if _steps % 2 == 0:
			Feel.play(&"cat/step", global_position)


func body_color() -> Color:
	return FUR[look] * _tint


func say(text: String, seconds := 1.6) -> void:
	if _fade:
		_fade.kill()
	if is_instance_valid(_bubble):
		_bubble.free()
	# a speech bubble right over the head, its tail pointing down at the cat; pops in
	if _bubble_layer == null:
		_bubble_layer = CanvasLayer.new()
		_bubble_layer.layer = 16
		add_child(_bubble_layer)
	_bubble = Control.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.material = HudStyle.WORN
	_bubble.size = HudStyle.bubble_size(text)
	_bubble.draw.connect(func() -> void:
		HudStyle.bubble(_bubble, Rect2(Vector2.ZERO, _bubble.size), text, _tail()))
	_bubble_layer.add_child(_bubble)
	_place_bubble()
	_bubble.pivot_offset = Vector2(_tail(), _bubble.size.y + 4)
	_bubble.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade = create_tween()
	_fade.tween_interval(maxf(0.0, seconds - 0.3))
	_fade.tween_property(_bubble, "modulate:a", 0.0, minf(seconds, 0.3))
	_fade.tween_callback(_bubble.queue_free)


## Where the tail sits along the bubble: over the cat, even when the bubble is pushed in.
func _tail() -> float:
	if not is_instance_valid(_bubble):
		return 0.0
	return clampf(get_global_transform_with_canvas().origin.x - _bubble.position.x, 4.0, _bubble.size.x - 5.0)


## UI pixels (the bubble layer is the window's): the tail's tip 4 px over the ears.
func _place_bubble() -> void:
	var at := get_global_transform_with_canvas().origin
	var screen := get_viewport().get_visible_rect().size
	var desired := at + Vector2(-_bubble.size.x / 2.0, -(TOP * _size() + 2.0) * 2.0 - _bubble.size.y)
	desired.x = clampf(desired.x, 1.0, maxf(1.0, screen.x - _bubble.size.x - 1.0))
	desired.y = clampf(desired.y, 1.0, maxf(1.0, screen.y - _bubble.size.y - 5.0))
	_bubble.position = desired.round()
	_bubble.queue_redraw()


func _size() -> float:
	return 2.0 if kind == &"boss" else 1.0


func _row(moving: bool) -> int:
	var happy := _mood_time > 0.0 and _mood == Mood.HAPPY
	var sad := _mood_time > 0.0 and _mood != Mood.HAPPY
	if moving:
		return Row.WALK_HAPPY if happy else (Row.WALK_SAD if sad else Row.WALK)
	if happy:
		return Row.HAPPY
	if sad:
		return Row.SAD
	return Row.BLINK if _blink < 0.0 else Row.IDLE


func _draw() -> void:
	if kind == &"bubble":
		return
	var size := _size()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 7.0 * size, Color(0, 0, 0, 0.3))
	var moving := walking and not held
	var frame := _steps % 4 if moving else int(_age / IDLE_FRAME) % 4
	draw_set_transform(Vector2(0, -hop), 0.0, Vector2(facing * size, size))
	draw_texture_rect_region(SHEETS[look], Rect2(-CELL.x / 2.0, -FOOT, CELL.x, CELL.y), Rect2(Vector2(frame, _row(moving)) * CELL, CELL), _tint)
	draw_set_transform(Vector2.ZERO)
	if kind == &"homeless":
		for i in 3:
			var line := PackedVector2Array()
			for j in 5:
				line.append(Vector2(-5 + i * 5 + roundf(sin(_age * 4.0 + j + i)), -TOP - 3 - j))
			draw_polyline(line, Color("9c8a99"), 1.0)
	if kind == &"special" and not minigame_completed:
		draw_string(ThemeDB.get_project_theme().default_font, Vector2(-2, -TOP - 2), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8c46a"))
