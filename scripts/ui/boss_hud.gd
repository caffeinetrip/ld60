class_name BossHud
extends Node2D
## HP bar with hearts and stage pips under it, floating over the boss. The origin is the
## top centre of the bar. Stages count from 0; set_hp(max_hp) refills the bar for the next one.

const BAR := Vector2(24, 3)
const FLASH := 0.12			# the lost part of the bar stays white this long
const DRAIN := 0.35			# then the bar eases down
const POP := 0.4			# a lost heart grows and fades
const FRAME := preload("res://art/ui/boss/bar.png")		# the bar's frame and its dark back
const HEART := preload("res://art/ui/boss/heart.png")	# white, tinted
const COL_HP := Color("e05a5a")
const COL_FRAME := Color("2b1d2e")
const COL_HEART := Color("ff8fb1")
const COL_PIP := Color("9c8a99")
const COL_STAGE := Color("ffd34d")

var max_hp := 1
var hp := 1
var lives := 0
var max_lives := 0
var stage := 0
var stages := 0

var _shown := 1.0		# where the bar ends on screen, 0..1
var _white := 0.0
var _drain: Tween
var _pops := {}			# heart index -> 0..1


func _ready() -> void:
	add_to_group(&"ui")
	z_index = 40
	# it's UI: the room light doesn't dim it
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit


func setup(full_hp: int, start_lives: int) -> void:
	max_hp = maxi(1, full_hp)
	hp = max_hp
	max_lives = maxi(0, start_lives)
	lives = max_lives
	if _drain:
		_drain.kill()
	_shown = 1.0
	_white = 0.0
	_pops.clear()
	queue_redraw()


func set_hp(value: int) -> void:
	value = clampi(value, 0, max_hp)
	if value == hp:
		return
	var lost := value < hp
	hp = value
	if _drain:
		_drain.kill()
	_drain = create_tween()
	if lost:
		_white = 1.0
		Feel.play(&"boss/hp", to_global(Vector2(0, 2)))
		_drain.tween_interval(FLASH)
		_drain.tween_property(self, "_shown", ratio(), DRAIN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_drain.parallel().tween_property(self, "_white", 0.0, DRAIN)
	else:
		_white = 0.0
		_drain.tween_property(self, "_shown", ratio(), DRAIN).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func set_lives(n: int) -> void:
	n = maxi(n, 0)
	max_lives = maxi(max_lives, n)
	if n < lives:
		for i in range(n, lives):
			_pops[i] = 0.0
		Feel.play(&"boss/life_lost", to_global(_heart(lives - 1) + Vector2(1, 1)))
	for i in range(lives, n):
		_pops.erase(i)
	lives = n
	queue_redraw()


func set_stage(i: int, count: int) -> void:
	stages = maxi(count, 0)
	stage = clampi(i, 0, maxi(stages - 1, 0))
	queue_redraw()


func ratio() -> float:
	return float(hp) / max_hp


## Top left of heart `i`, the row is centred under the bar.
func _heart(i: int) -> Vector2:
	return Vector2(-floorf((max_lives * 4 - 1) * 0.5) + i * 4, 6)


func _process(delta: float) -> void:
	for i in _pops.keys():
		_pops[i] += delta / POP
		if _pops[i] >= 1.0:
			_pops.erase(i)
	queue_redraw()


func _draw() -> void:
	draw_texture(FRAME, Vector2(-BAR.x * 0.5 - 1, 0))
	var bar := Rect2(-BAR.x * 0.5, 1, BAR.x, BAR.y)
	var now := roundf(BAR.x * ratio())
	var end := roundf(BAR.x * _shown)
	draw_rect(Rect2(bar.position, Vector2(end, BAR.y)), COL_HP)
	if _white > 0.0 and end > now:
		draw_rect(Rect2(bar.position.x + now, bar.position.y, end - now, BAR.y), Color(1, 1, 1, _white))

	for i in max_lives:
		_draw_heart(_heart(i), COL_HEART if i < lives else COL_FRAME)
	for i in _pops:
		var t: float = _pops[i]
		var c := _heart(i) + Vector2(1.5, 1.5)
		draw_set_transform(c, 0.0, Vector2.ONE * (1.0 + t * 1.5))
		_draw_heart(Vector2(-1.5, -1.5), Color(COL_HEART.lerp(Color.WHITE, 0.5 * (1.0 - t)), 1.0 - t))
		draw_set_transform(Vector2.ZERO)

	var x := -floorf((stages * 3 - 1) * 0.5)
	var y := 10.0 if max_lives > 0 else 6.0
	for i in stages:
		draw_rect(Rect2(x + i * 3, y, 2, 2), COL_STAGE if i == stage else COL_PIP)


func _draw_heart(at: Vector2, color: Color) -> void:
	draw_texture(HEART, at, color)
