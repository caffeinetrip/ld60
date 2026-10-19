class_name HitBar
extends MiniGame
## Undertale-style timing bar: a cursor sweeps across, click to stop it in the middle.
## Own params (override the curve): speed, good_zone, perfect_zone, flip.

# difficulty 0 -> 1
const SPEED := Vector2(136.0, 272.0)	# px/s, a sweep takes ~1.5 s -> ~0.75 s
const GOOD := Vector2(0.40, 0.22)		# half-width fractions from the centre
const PERFECT := Vector2(0.12, 0.05)
const FLIP := 0.3						# chance to run right to left at difficulty 1

const BAR := MiniGame.SLOT
const DISPLAY_WIDTH := 156.0
const COL_GOOD := Color("a59e70")
const COL_PERFECT := Color("efc76c")
const COL_CURSOR := Color("fff1ce")

var speed := 60.0
var good_zone := 0.35
var perfect_zone := 0.09

var _x := 0.0
var _dir := 1
var _trail: Array[float] = []


func _setup(p: Dictionary) -> void:
	use_parent_material = false
	var bright_material := HudStyle.run_material()
	bright_material.set_shader_parameter(&"gain", 1.1)
	bright_material.set_shader_parameter(&"saturation", 0.95)
	material = bright_material
	area = BAR
	speed = p.get("speed", lerpf(SPEED.x, SPEED.y, difficulty) * pace)
	good_zone = p.get("good_zone", minf(lerpf(GOOD.x, GOOD.y, difficulty) * zone, 0.9))
	perfect_zone = p.get("perfect_zone", minf(lerpf(PERFECT.x, PERFECT.y, difficulty) * zone, 0.5))
	_dir = -1 if p.get("flip", _rng.randf() < FLIP * difficulty) else 1
	_x = 0.0 if _dir > 0 else area.size.x
	_trail.clear()


func _tick(delta: float) -> void:
	_trail.push_front(_x)
	if _trail.size() > 4:
		_trail.pop_back()
	var width := area.size.x
	var phase := _x if _dir > 0 else 2.0 * width - _x
	phase = fposmod(phase + speed * delta, 2.0 * width)
	_dir = 1 if phase < width else -1
	_x = phase if _dir > 0 else 2.0 * width - phase


func _click() -> void:
	var half := area.size.x * 0.5
	judge(absf(_x - half) / half, perfect_zone, good_zone, _cursor())


func _cursor() -> Vector2:
	return Vector2(area.get_center().x - DISPLAY_WIDTH * 0.5 + _x / area.size.x * DISPLAY_WIDTH, area.get_center().y)


func _draw_game(_r: Rect2) -> void:
	var r := Rect2(-DISPLAY_WIDTH * 0.5, -4, DISPLAY_WIDTH, 8)
	HudStyle.RUN_ART.wood(self, Rect2(-94, -12, 188, 28))
	draw_texture_rect(HudStyle.RUN_ART.HIT_TRACK, r.grow(2), false)
	var inner := r
	var half := inner.size.x * 0.5
	var good_half := roundf(half * good_zone / 2.0) * 2
	var good := Rect2(-good_half, inner.position.y, good_half * 2, inner.size.y)
	draw_texture_rect(HudStyle.RUN_ART.HIT_ZONE, good, false, COL_GOOD)
	var perfect_half := maxf(roundf(half * perfect_zone / 2.0) * 2, 2)
	var perfect := Rect2(-perfect_half, inner.position.y, perfect_half * 2, inner.size.y)
	draw_texture_rect(HudStyle.RUN_ART.HIT_ZONE, perfect, false, COL_PERFECT)

	if running:
		for i in _trail.size():
			var tx := roundf((r.position.x + _trail[i] / area.size.x * DISPLAY_WIDTH) / 2.0) * 2
			draw_texture_rect(HudStyle.RUN_ART.HIT_TRAIL, Rect2(tx, -8, 2, 16), false, Color(COL_CURSOR, 0.2 - i * 0.04))

	# the cursor sticks out of the bar
	var cx := roundf((r.position.x + _x / area.size.x * DISPLAY_WIDTH) / 2.0) * 2
	var col: Color = COL_CURSOR if tier == &"" else TIER_COLOR[tier]
	draw_texture_rect(HudStyle.RUN_ART.HIT_CURSOR_BORDER, Rect2(cx - 2, -10, 6, 20), false)
	draw_texture_rect(HudStyle.RUN_ART.HIT_CURSOR, Rect2(cx, -8, 2, 16), false, col)
