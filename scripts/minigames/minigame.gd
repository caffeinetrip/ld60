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

const SLOT := Rect2(218, 321, 204, 10)	# the inset in the wooden timing panel, UI px
const TIER_TEXT := {&"perfect": "Perfect", &"good": "Good", &"meh": "Meh", &"miss": "Miss"}
const TIER_COLOR := {
	&"perfect": HudStyle.RUN_BRIGHT, &"good": HudStyle.RUN_TEXT,
	&"meh": HudStyle.LABEL, &"miss": HudStyle.WARN,
}

@export var preroll := 0.35		# shown before it starts
@export var hold := 0.45		# result stays on screen
@export var auto_hold := 0.4	# an auto result (pc tower) stays this long

var area := SLOT		# where the game draws, UI pixels
var difficulty := 0.0
var pace := 1.0
var zone := 1.0
var running := false
var tier := &""
var flash := 0.0
var auto := false		# resolved as perfect without a click (params.auto)
var on_result := Callable()	# params.on_result: called with {tier, quality} the moment it is decided

var _open := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	use_parent_material = true
	visible = false
	_rng.randomize()
	preload("res://scripts/ui/appear.gd").attach(self)


func run(params := {}) -> Dictionary:
	difficulty = params.get("difficulty", 0.0)
	pace = params.get("pace", 1.0)
	zone = params.get("zone", 1.0)
	auto = params.get("auto", false)
	on_result = params.get("on_result", Callable())
	tier = &""
	_setup(params)
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	create_tween().tween_property(self, "_open", 1.0, 0.12).from(0.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Feel.play(&"hit/start")
	var result := {tier = &"perfect", quality = 1.0}
	if auto:
		running = true
		finish(result.tier, result.quality)
		await _wait(auto_hold)
	else:
		await _wait(preroll)
		running = true
		result = await resolved
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


## `at` = viewport point for the particles, the game's centre by default.
func finish(result_tier: StringName, quality: float, at := Vector2.INF) -> void:
	if not running:
		return
	running = false
	tier = result_tier
	flash = 1.0
	if at == Vector2.INF:
		at = area.get_center()
	Feel.play(StringName("hit/" + String(tier)), at, 1.0, get_parent())
	if tier == &"perfect" or tier == &"good":
		var celebration := preload("res://scripts/feel/success_fx.gd").new()
		celebration.position = at
		celebration.perfect = tier == &"perfect"
		get_parent().add_child(celebration)
	if on_result.is_valid():
		on_result.call({tier = tier, quality = quality})
	resolved.emit({tier = tier, quality = quality})


func _setup(_params: Dictionary) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _click() -> void:
	pass


## `r` = `area` moved so its centre is at the origin.
func _draw_game(_r: Rect2) -> void:
	pass


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pressed: bool = event is InputEventMouseButton and event.pressed
	pressed = pressed or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		get_viewport().set_input_as_handled()
		if running:
			_click()


func _process(delta: float) -> void:
	if running:
		# fast-forward speeds the day up, not the minigame (hitstop still applies)
		_tick(delta / (Feel.speed if Feel.fast else 1.0))
	flash = move_toward(flash, 0.0, delta * 3.0)
	if visible:
		modulate.a = clampf(_open, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	if _open <= 0.0:
		return
	var c := area.get_center()
	draw_set_transform(c)
	var r := Rect2(area.position - c, area.size)
	_draw_game(r)
	if tier != &"":
		var label: String = ("Auto " if auto else "") + TIER_TEXT[tier]
		var width := HudStyle.TALK_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.RUN_FONT_SIZE).x
		draw_string(HudStyle.TALK_FONT, Vector2(roundf(-width * 0.5), -18), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, HudStyle.RUN_FONT_SIZE, HudStyle.WARN if tier == &"miss" else HudStyle.RUN_TEXT)
	draw_set_transform(Vector2.ZERO)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
