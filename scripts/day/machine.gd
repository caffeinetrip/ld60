class_name Machine extends Node2D

signal whacked

const BODY := preload("res://art/day/machine.png")	# squashed 0 / 1 / 2 px across, normal / hover down

@export var day_path: NodePath

var boost := 0.0
var cooldown := 0.0
var _day: Node
var _burst_in := 0.0
var _age := 0.0
var _squash := 0.0
var _hover := false


func _ready() -> void:
	_day = get_node(day_path)
	Game.run_reset.connect(reset)


func _active() -> bool:
	return Game.mod(&"whack") > 0 and _day.is_active()


func can_whack() -> bool:
	return _active() and cooldown <= 0.0 and boost <= 0.0


## Seconds from a whack to ready again; fuse boxes cut it.
func full_cooldown() -> float:
	return Tune.WHACK_COOLDOWN * (1.0 - minf(Game.mod(&"cool_fast"), 0.8))


func whack() -> void:
	if not can_whack():
		return
	boost = Tune.WHACK_TIME
	cooldown = full_cooldown()
	_burst_in = 0.3
	_squash = 2.0
	Game.set_mods(&"machine", {serve_speed = Tune.WHACK_BOOST})
	Feel.play(&"machine/whack", global_position)
	whacked.emit()


func reset() -> void:
	boost = 0.0
	cooldown = 0.0
	_squash = 0.0
	_hover = false
	Game.set_mods(&"machine", {})
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(-6, -14, 12, 14).has_point(get_global_transform_with_canvas().affine_inverse() * event.position):
			whack()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_hover = _active() and Rect2(-6, -14, 12, 14).has_point(get_local_mouse_position())
	if _day.running:
		_age += delta
		_squash = move_toward(_squash, 0.0, delta * 12.0)
	# boost and cooldown stand still while the day does (minigames, talks)
	if _day.is_active():
		cooldown = maxf(0.0, cooldown - delta)
		if boost > 0.0:
			boost = maxf(0.0, boost - delta)
			if boost == 0.0:
				Game.set_mods(&"machine", {})
			_burst_in -= delta
			if _burst_in <= 0.0:
				_burst_in = 0.3
				Feel.burst(&"sparks", global_position + Vector2(0, -14), 0.3)
	queue_redraw()


func _draw() -> void:
	var offset := Vector2(roundf(sin(_age * 50.0)) if boost > 0.0 else 0.0, roundf(_squash))
	draw_set_transform(offset)
	var hover := 14 if _hover and can_whack() else 0
	draw_texture_rect_region(BODY, Rect2(-6, -14, 12, 14 - offset.y), Rect2(offset.y * 12, hover, 12, 14 - offset.y))
	var screen := Color("7fd17f") if cooldown <= 0.0 or boost > 0.0 else Color("9c8a99")
	draw_rect(Rect2(-3, -11, 6, 4), screen)
	if cooldown > 0.0:
		draw_rect(Rect2(-6, 2, 12, 1), Color("2b1d2e"))
		draw_rect(Rect2(-6, 2, floorf(12.0 * (1.0 - cooldown / full_cooldown())), 1), Color("7fd17f"))
