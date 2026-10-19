class_name Kick
extends MiniGame
## Kick a street cat out: a needle swings over a half-circle gauge, click while it's in the
## wedge. The boot winds up with the needle and swings through on a hit.
## Own params (override the curve): speed, wedge, target, sweeps, flip.

# difficulty 0 -> 1
const SPEED := Vector2(0.8, 0.8)		# sweeps per second, a sweep = one end to the other
const WEDGE := Vector2(126.0, 126.0)	# sweet spot width, degrees: 4.5x the old 28, very easy all run
const PERFECT := Vector2(0.4, 0.3)		# middle part of the wedge that is perfect
const MEH := 16.0						# degrees past the wedge that still count as meh
const SWEEPS := 2						# then it's a miss
const ROOM := 30.0						# wedge centre keeps this far from the ends, degrees

const BOX := Rect2(277, 285, 86, 32)	# stands on the counter's ledge like the hit bar, UI px
const RADIUS := 29
const WINDUP := 40.0					# boot angle at the far end of a sweep
const KICK := -70.0						# and when it swings through
const SWING := 0.15						# the kick pose holds this long
const BOOT := [Vector2(-3, 0), Vector2(3, 0), Vector2(3, 9), Vector2(7, 9), Vector2(10, 11),
		Vector2(10, 14), Vector2(-3, 14)]	# hangs from its pivot, toe to the right
const TOE := Vector2(10, 13)
const COL_FRAME := HudStyle.LINE
const COL_DARK := HudStyle.SHADE
const COL_LIGHT := HudStyle.TEXT
const COL_NEAR := HudStyle.LIP
const COL_GOOD := HudStyle.EDGE
const COL_PERFECT := HudStyle.GOLD
const COL_BOOT := HudStyle.LABEL
const DIAL := preload("res://art/minigames/kick_dial.png")		# face + base, top left at the pivot - 30
const TICKS := preload("res://art/minigames/kick_ticks.png")	# same spot, over the wedges
const HUB := preload("res://art/minigames/kick_hub.png")

var speed := 1.0
var wedge := 28.0
var perfect := 11.2
var target := 90.0
var sweeps := SWEEPS

var _t := 0.0			# sweeps done
var _flip := false
var _trail: Array[float] = []
var _boot := 0.0
var _swing := 0.0


func _setup(p: Dictionary) -> void:
	area = BOX
	speed = p.get("speed", lerpf(SPEED.x, SPEED.y, difficulty) * pace)
	wedge = p.get("wedge", minf(lerpf(WEDGE.x, WEDGE.y, difficulty) * zone, 160.0))
	perfect = wedge * lerpf(PERFECT.x, PERFECT.y, difficulty)
	var room := maxf(ROOM, wedge * 0.5)
	target = p.get("target", _rng.randf_range(room, 180.0 - room))
	sweeps = p.get("sweeps", SWEEPS)
	_flip = p.get("flip", false)
	_t = 0.0
	_trail.clear()
	_boot = 0.0
	_swing = 0.0


func _tick(delta: float) -> void:
	_trail.push_front(needle())
	if _trail.size() > 3:
		_trail.pop_back()
	var turns := int(_t)
	_t += speed * delta
	_boot = WINDUP * _sweep()
	if int(_t) > turns:
		Feel.play(&"kick/turn")
	_t = fposmod(_t, 2.0)


func _click() -> void:
	var edge := wedge * 0.5 + MEH
	judge(absf(needle() - target) / edge, perfect * 0.5 / edge, wedge * 0.5 / edge, _tip(area))


func finish(result_tier: StringName, quality: float, at := Vector2.INF) -> void:
	if not running:
		return
	super(result_tier, quality, at)
	if tier == &"perfect" or tier == &"good":
		_boot = KICK
		_swing = SWING
		Feel.play(&"kick/swing", _leg(area) * TOE, 1.5 if tier == &"perfect" else 1.0, get_parent())


## Degrees, 0 = left end, 180 = right end.
func needle() -> float:
	return 180.0 * (1.0 - _sweep() if _flip else _sweep())


## How far the needle is from the side it started on, 0..1, slow at the ends.
func _sweep() -> float:
	var s := (1.0 - cos(PI * fmod(_t, 1.0))) * 0.5
	return 1.0 - s if int(_t) % 2 == 1 else s


func _process(delta: float) -> void:
	super(delta)
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta)
	elif not running:
		_boot = move_toward(_boot, 0.0, delta * 400.0)


func _pivot(r: Rect2) -> Vector2:
	return Vector2(r.position.x + RADIUS + 1, r.end.y - 3)


func _tip(r: Rect2) -> Vector2:
	return _pivot(r) + _dir(needle()) * (RADIUS - 2)


func _dir(degrees: float) -> Vector2:
	return Vector2.LEFT.rotated(deg_to_rad(degrees))


## The boot hangs from here, turned by `degrees`.
func _leg(r: Rect2, degrees := _boot) -> Transform2D:
	return Transform2D(deg_to_rad(degrees), Vector2(r.end.x - 13, r.position.y + 8))


func _wedge(o: Vector2, from: float, to: float, color: Color) -> void:
	from = maxf(from, 0.0)
	to = minf(to, 180.0)
	if to - from < 1.0:
		return
	var points := PackedVector2Array([o])
	var steps := maxi(2, ceili((to - from) / 6.0))
	for i in steps + 1:
		points.append(o + _dir(lerpf(from, to, float(i) / steps)) * (RADIUS - 1))
	draw_colored_polygon(points, color)


func _draw_game(r: Rect2) -> void:
	var o := _pivot(r)
	var corner := o - Vector2.ONE * (RADIUS + 1)
	draw_texture(DIAL, corner)

	var half := wedge * 0.5
	_wedge(o, target - half - MEH, target + half + MEH, COL_NEAR)
	_wedge(o, target - half, target + half, COL_GOOD)
	var gold := COL_PERFECT.lerp(HudStyle.GOLD_LIGHT, flash) if tier == &"perfect" else COL_PERFECT
	_wedge(o, target - perfect * 0.5, target + perfect * 0.5, gold)
	draw_texture(TICKS, corner)

	if running:
		for i in _trail.size():
			draw_line(o, o + _dir(_trail[i]) * (RADIUS - 2), Color(COL_LIGHT, 0.3 - i * 0.1))
	var col: Color = COL_LIGHT if tier == &"" else TIER_COLOR[tier].lerp(HudStyle.GOLD_LIGHT, flash)
	var tip := _tip(r)
	# dark edges keep it readable over the wedge, the hit flash makes it fat
	var side := Vector2.RIGHT if absf(_dir(needle()).x) < 0.7 else Vector2.DOWN
	for s in [side, -side]:
		draw_line(o + s, tip + s, col if flash > 0.3 else COL_DARK)
	draw_line(o, tip, col)
	draw_texture(HUB, o - Vector2(2, 2))

	if _swing > 0.0:
		var swoosh := PackedVector2Array()
		for i in 7:
			swoosh.append(_leg(r, lerpf(WINDUP, KICK, i / 6.0)) * TOE)
		draw_polyline(swoosh, Color(COL_LIGHT, _swing / SWING))
	var leg := _leg(r)
	var boot := leg * PackedVector2Array(BOOT)
	draw_colored_polygon(boot, COL_BOOT)
	draw_colored_polygon(leg * PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, 2), Vector2(-3, 2)]), COL_FRAME)
	boot.append(boot[0])
	draw_polyline(boot, COL_DARK)
	draw_line(leg * Vector2(-2, 13), leg * Vector2(9, 13), COL_DARK)
