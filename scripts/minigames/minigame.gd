class_name MiniGame
extends Control
## Base for the micro skill checks: 0.5-2 s, one click, instant feedback. Something else
## decides what happens (special cat, relic, ingredient), the minigame decides how well.
## `var r := await game.run(params)` -> {tier, quality}, tiers perfect / good / meh / miss,
## quality 0..1. Every game reads difficulty 0..1, pace (speed mult) and zone (tolerance
## mult); other params are its own, see its _setup().
##
## New game: extend this, set `area`, override _setup / _tick / _click / _draw_game,
## end with judge() or finish(), list it in MiniGames.GAMES.

signal resolved(result: Dictionary)

const PAD := 6
const COL_PANEL := Color("2b1d2e")
const COL_FRAME := Color("c9a24a")
const COL_DARK := Color("1a1220")
const COL_LIGHT := Color("f2e6c9")
const TIER_TEXT := {&"perfect": "PERFECT!", &"good": "GOOD", &"meh": "MEH...", &"miss": "MISS"}
const TIER_COLOR := {
	&"perfect": Color("ffd34d"), &"good": Color("7fd17f"),
	&"meh": Color("9c8a99"), &"miss": Color("e05a5a"),
}

@export var preroll := 0.35		# shown before it starts
@export var hold := 0.45		# result stays on screen

var area := Rect2(70, 78, 180, 20)	# what the panel frames, viewport pixels
var difficulty := 0.0
var pace := 1.0
var zone := 1.0
var running := false
var tier := &""
var flash := 0.0

var _open := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_rng.randomize()


func run(params := {}) -> Dictionary:
	difficulty = params.get("difficulty", 0.0)
	pace = params.get("pace", 1.0)
	zone = params.get("zone", 1.0)
	tier = &""
	_setup(params)
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	create_tween().tween_property(self, "_open", 1.0, 0.12).from(0.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Feel.play(&"hit/start")
	await _wait(preroll)
	running = true
	var result: Dictionary = await resolved
	await _wait(hold)
	var out := create_tween()
	out.tween_property(self, "_open", 0.0, 0.1)
	await out.finished
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	return result


## Distance from the target (0 = dead on, 1 = its edge) -> tier and quality.
func judge(off: float, perfect: float, good: float, at := Vector2.INF) -> void:
	if off <= perfect:
		finish(&"perfect", 1.0, at)
	elif off <= good:
		finish(&"good", lerpf(0.9, 0.6, inverse_lerp(perfect, good, off)), at)
	elif off <= 1.0:
		finish(&"meh", lerpf(0.5, 0.1, inverse_lerp(good, 1.0, off)), at)
	else:
		finish(&"miss", 0.0, at)


## `at` = viewport point for the particles, the panel centre by default.
func finish(result_tier: StringName, quality: float, at := Vector2.INF) -> void:
	if not running:
		return
	running = false
	tier = result_tier
	flash = 1.0
	if at == Vector2.INF:
		at = area.get_center()
	Feel.play(StringName("hit/" + String(tier)), get_viewport().get_canvas_transform().affine_inverse() * at)
	resolved.emit({tier = tier, quality = quality})


func _setup(_params: Dictionary) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _click() -> void:
	pass


## `r` = `area` moved so the panel centre is at the origin.
func _draw_game(_r: Rect2) -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if running:
			_click()


func _process(delta: float) -> void:
	if running:
		_tick(delta)
	flash = move_toward(flash, 0.0, delta * 3.0)
	if visible:
		queue_redraw()


func _draw() -> void:
	if _open <= 0.0:
		return
	var c := area.get_center()
	draw_set_transform(c, 0.0, Vector2(1.0, _open))
	var r := Rect2(area.position - c, area.size)
	var panel := r.grow(PAD)
	draw_rect(panel, COL_PANEL)
	draw_rect(panel.grow(-0.5), COL_FRAME, false, 1.0)
	_draw_game(r)
	if tier != &"":
		var font := get_theme_default_font()
		var at := Vector2(r.position.x, r.position.y - PAD - 4 - roundf(flash * 4.0))
		draw_string_outline(font, at, TIER_TEXT[tier], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, 2, COL_DARK)
		draw_string(font, at, TIER_TEXT[tier], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, TIER_COLOR[tier])
	draw_set_transform(Vector2.ZERO)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
