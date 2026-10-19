extends Node2D
## A kick's blood, after 222222's BloodTinyExplosion: 15 splats (its atlas row 14, animated)
## thrown in a 35 degree cone and falling, plus 8 thin droplets. Room pixels, frees itself.

const ROW := preload("res://art/fx/blood_row.png")	# 32 frames of 16 px
const COLOR := Color(0.62, 0.11, 0.11)	# 222222 has .42, too dark under our grade
const GRAVITY := 260.0
const SPLATS := 15
const DROPS := 8

var dir := Vector2.UP		# where the blow sends it
var _bits: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in SPLATS:
		_bits.append({pos = Vector2.ZERO, vel = _cone(35.0, 40.0, 70.0), t = 0.0,
			life = _rng.randf_range(0.25, 0.6), size = _rng.randf_range(0.8, 1.2), drop = false})
	for i in DROPS:
		_bits.append({pos = Vector2.ZERO, vel = _cone(25.0, 70.0, 110.0), t = 0.0,
			life = _rng.randf_range(0.3, 0.5), size = 1.0, drop = true})


func _cone(degrees: float, slow: float, fast: float) -> Vector2:
	return dir.normalized().rotated(deg_to_rad(_rng.randf_range(-degrees, degrees))) * _rng.randf_range(slow, fast)


func _process(delta: float) -> void:
	for i in range(_bits.size() - 1, -1, -1):
		var b: Dictionary = _bits[i]
		b.t += delta
		b.vel.y += GRAVITY * delta
		b.pos += b.vel * delta
		if b.t >= b.life:
			_bits.remove_at(i)
	if _bits.is_empty():
		queue_free()
	queue_redraw()


func _draw() -> void:
	for b in _bits:
		var k: float = b.t / b.life
		if b.drop:
			var c := COLOR.lerp(COLOR * 0.54, k)
			draw_line(b.pos, b.pos - b.vel.normalized() * 4.0, c, 1.0)
			continue
		var frame := mini(int(k * 12.0), 31)	# the prefab plays its row at .375 speed
		var s: float = 16.0 * b.size
		draw_texture_rect_region(ROW, Rect2(b.pos - Vector2(s, s) * 0.5, Vector2(s, s)),
			Rect2(frame * 16, 0, 16, 16), COLOR)
