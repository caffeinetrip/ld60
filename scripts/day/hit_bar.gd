class_name HitBar
extends Control
## Undertale-style timing bar. A cursor sweeps across, the player clicks to stop it.
## `var r := await hit_bar.run({speed = 160.0})` -> {tier, quality}
## tier: &"perfect" / &"good" / &"meh" / &"miss", quality 0..1.

signal resolved(result: Dictionary)

const BAR := Rect2i(70, 78, 180, 20)
const PANEL_PAD := 6

const COL_PANEL := Color("2b1d2e")
const COL_FRAME := Color("c9a24a")
const COL_BAR := Color("1a1220")
const COL_GOOD := Color("4f7a4f")
const COL_PERFECT := Color("ffd34d")
const COL_CURSOR := Color("f2e6c9")

const TIER_TEXT := {&"perfect": "PERFECT!", &"good": "GOOD", &"meh": "MEH...", &"miss": "MISS"}
const TIER_COLOR := {
	&"perfect": Color("ffd34d"), &"good": Color("7fd17f"),
	&"meh": Color("9c8a99"), &"miss": Color("e05a5a"),
}

@export var speed := 150.0			# px/s across the bar
@export var good_zone := 0.35		# half-width fractions from the centre
@export var perfect_zone := 0.09
@export var preroll := 0.35			# bar is shown before the cursor starts
@export var hold := 0.45			# result stays on screen

var _x := 0.0
var _dir := 1
var _running := false
var _open := 0.0
var _flash := 0.0
var _tier := &""
var _trail: Array[float] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func run(params := {}) -> Dictionary:
	speed = params.get("speed", speed)
	good_zone = params.get("good_zone", good_zone)
	perfect_zone = params.get("perfect_zone", perfect_zone)
	_dir = -1 if params.get("flip", false) else 1
	_x = 0.0 if _dir > 0 else float(BAR.size.x)
	_tier = &""
	_trail.clear()
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(self, "_open", 1.0, 0.12).from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Feel.play(&"hit/start")
	await get_tree().create_timer(preroll, true, false, true).timeout
	_running = true
	var result: Dictionary = await resolved
	await get_tree().create_timer(hold, true, false, true).timeout
	var out := create_tween()
	out.tween_property(self, "_open", 0.0, 0.1)
	await out.finished
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	return result


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _running:
			_stop()


func _process(delta: float) -> void:
	if _running:
		_trail.push_front(_x)
		if _trail.size() > 4:
			_trail.pop_back()
		_x += speed * _dir * delta
		if _x < 0.0 or _x > BAR.size.x:
			_x = clampf(_x, 0.0, BAR.size.x)
			_finish(&"miss", 0.0)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	if visible:
		queue_redraw()


func _stop() -> void:
	var off := absf(_x - BAR.size.x * 0.5) / (BAR.size.x * 0.5)
	if off <= perfect_zone:
		_finish(&"perfect", 1.0)
	elif off <= good_zone:
		_finish(&"good", lerpf(0.9, 0.6, inverse_lerp(perfect_zone, good_zone, off)))
	else:
		_finish(&"meh", lerpf(0.5, 0.1, inverse_lerp(good_zone, 1.0, off)))


func _finish(tier: StringName, quality: float) -> void:
	_running = false
	_tier = tier
	_trail.clear()
	_flash = 1.0
	var at := _to_world(Vector2(BAR.position.x + _x, BAR.position.y + BAR.size.y * 0.5))
	Feel.play(StringName("hit/" + String(tier)), at)
	resolved.emit({tier = tier, quality = quality})


func _draw() -> void:
	if _open <= 0.0:
		return
	var c := Vector2(BAR.get_center())
	draw_set_transform(c, 0.0, Vector2(1.0, _open))
	var bar := Rect2(Vector2(BAR.position) - c, BAR.size)

	var panel := bar.grow(PANEL_PAD)
	draw_rect(panel, COL_PANEL)
	draw_rect(panel.grow(-0.5), COL_FRAME, false, 1.0)

	draw_rect(bar, COL_BAR)
	var half := bar.size.x * 0.5
	var good := Rect2(bar.position.x + half * (1.0 - good_zone), bar.position.y, half * good_zone * 2.0, bar.size.y)
	draw_rect(good, COL_GOOD)
	var perfect := Rect2(bar.position.x + half * (1.0 - perfect_zone), bar.position.y, half * perfect_zone * 2.0, bar.size.y)
	draw_rect(perfect, COL_PERFECT.lerp(Color.WHITE, _flash) if _tier == &"perfect" else COL_PERFECT)
	# ticks every 10 % like a ruler
	for i in range(1, 10):
		var x := floorf(bar.position.x + bar.size.x * i / 10.0)
		draw_line(Vector2(x, bar.end.y - 3), Vector2(x, bar.end.y), Color(0, 0, 0, 0.5))

	for i in _trail.size():
		var tx := floorf(bar.position.x + _trail[i])
		draw_rect(Rect2(tx, bar.position.y - 2, 2, bar.size.y + 4), Color(COL_CURSOR, 0.35 - i * 0.08))

	var cx := floorf(bar.position.x + _x)
	var cur_col := COL_CURSOR
	if _tier != &"":
		cur_col = TIER_COLOR[_tier].lerp(Color.WHITE, _flash)
	var grow := roundf(_flash * 3.0)
	draw_rect(Rect2(cx - grow, bar.position.y - 4 - grow, 2 + grow * 2, bar.size.y + 8 + grow * 2), cur_col)

	if _tier != &"":
		var font := get_theme_default_font()
		var y := bar.position.y - PANEL_PAD - 4 - roundf(_flash * 4.0)
		draw_string_outline(font, Vector2(bar.position.x, y), TIER_TEXT[_tier], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 16, 2, COL_BAR)
		draw_string(font, Vector2(bar.position.x, y), TIER_TEXT[_tier], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 16, TIER_COLOR[_tier])
	draw_set_transform(Vector2.ZERO)


## Screen point -> world point, so particles land where the cursor stopped.
func _to_world(screen: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen
