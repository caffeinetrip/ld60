class_name HitBar
extends MiniGame
## Undertale-style timing bar: a cursor sweeps across, click to stop it in the middle.
## Own params (override the curve): speed, good_zone, perfect_zone, flip.

# difficulty 0 -> 1
const SPEED := Vector2(120.0, 240.0)	# px/s
const GOOD := Vector2(0.40, 0.22)		# half-width fractions from the centre
const PERFECT := Vector2(0.12, 0.05)
const FLIP := 0.3						# chance to run right to left at difficulty 1

const BAR := Rect2(70, 78, 180, 20)
const COL_GOOD := Color("4f7a4f")
const COL_PERFECT := Color("ffd34d")

var speed := 150.0
var good_zone := 0.35
var perfect_zone := 0.09

var _x := 0.0
var _dir := 1
var _trail: Array[float] = []


func _setup(p: Dictionary) -> void:
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
	_x += speed * _dir * delta
	if _x < 0.0 or _x > area.size.x:
		_x = clampf(_x, 0.0, area.size.x)
		finish(&"miss", 0.0, _cursor())


func _click() -> void:
	var half := area.size.x * 0.5
	judge(absf(_x - half) / half, perfect_zone, good_zone, _cursor())


func _cursor() -> Vector2:
	return Vector2(area.position.x + _x, area.get_center().y)


func _draw_game(r: Rect2) -> void:
	draw_rect(r, COL_DARK)
	var half := r.size.x * 0.5
	draw_rect(Rect2(r.position.x + half * (1.0 - good_zone), r.position.y, half * good_zone * 2.0, r.size.y), COL_GOOD)
	var perfect := Rect2(r.position.x + half * (1.0 - perfect_zone), r.position.y, half * perfect_zone * 2.0, r.size.y)
	draw_rect(perfect, COL_PERFECT.lerp(Color.WHITE, flash) if tier == &"perfect" else COL_PERFECT)
	# ruler ticks every 10 %
	for i in range(1, 10):
		var x := floorf(r.position.x + r.size.x * i / 10.0)
		draw_line(Vector2(x, r.end.y - 3), Vector2(x, r.end.y), Color(0, 0, 0, 0.5))

	if running:
		for i in _trail.size():
			var tx := floorf(r.position.x + _trail[i])
			draw_rect(Rect2(tx, r.position.y - 2, 2, r.size.y + 4), Color(COL_LIGHT, 0.35 - i * 0.08))

	var cx := floorf(r.position.x + _x)
	var col: Color = COL_LIGHT if tier == &"" else TIER_COLOR[tier].lerp(Color.WHITE, flash)
	var grow := roundf(flash * 3.0)
	draw_rect(Rect2(cx - grow, r.position.y - 4 - grow, 2 + grow * 2, r.size.y + 8 + grow * 2), col)
