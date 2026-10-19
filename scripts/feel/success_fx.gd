extends Node2D
## A small celebration around the timing cursor, with no screen-wide flash.

const SPARKLES := preload("res://art/fx/minisparkles.png")
const MONEY := preload("res://art/fx/money_atlas.png")
const MONEY_GRAVITY := 65.0
var perfect := false
var gold := false
var count := 0		# bills or sparkles, 0 = the usual amount
var gold_target := Vector2.ZERO
var _age := 0.0
var _bits: Array[Dictionary] = []


func _ready() -> void:
	z_index = 51
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if gold else CanvasItem.TEXTURE_FILTER_NEAREST
	if gold:
		var paper_material := CanvasItemMaterial.new()
		paper_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = paper_material
	var rng := RandomNumberGenerator.new()
	var n := count if count > 0 else (2 if gold else (20 if perfect else 12))
	var wide := maxf(n - 2, 0.0)		# a big payment spreads its bills further
	for i in n:
		var angle := rng.randf_range(-PI + 0.2, -0.2)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var velocity := Vector2(side * rng.randf_range(8.0, 16.0 + wide * 3.0), rng.randf_range(1.0 - wide * 4.0, 3.0)) if gold else Vector2.from_angle(angle) * rng.randf_range(35.0, 85.0)
		_bits.append({velocity = velocity,
			spin = rng.randf_range(-0.4, 0.4) if gold else rng.randf_range(-4.0, 4.0),
			size = 32.0 if gold else rng.randf_range(4.0, 7.0),
			frame = i % 4, color = Color("e9bd73") if i % 3 else (Color("f4d994") if gold else Color("b5ceac"))})


func _process(delta: float) -> void:
	_age += delta
	if _age >= 0.9:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var fade := 0.75 if gold else clampf((0.9 - _age) / 0.45, 0.0, 1.0)
	if _age < 0.4 and not gold:
		var progress := _age / 0.4
		var radius := lerpf(4.0, 28.0 if perfect else 19.0, progress)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.55))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.9, 0.73, 0.45, (1.0 - progress) * 0.65), 1.0)
	for bit in _bits:
		# A short sideways burst with a little fall before the register pulls it in.
		var travel := 1.0 - exp(-14.0 * _age) if gold else _age
		var at: Vector2 = bit.velocity * travel + Vector2(0, (MONEY_GRAVITY if gold else 48.0) * _age * _age)
		var pull := 0.0
		if gold:
			var start_time: float = 0.32 + bit.frame * 0.05
			pull = clampf((_age - start_time) / 0.36, 0.0, 1.0)
			if pull >= 1.0:
				continue
			if pull > 0.0:
				var start: Vector2 = bit.velocity * (1.0 - exp(-14.0 * start_time)) + Vector2(0, MONEY_GRAVITY * start_time * start_time)
				var bend := (start + gold_target) * 0.5 + Vector2(0, -12)
				var t := pull * pull
				at = start.lerp(bend, t).lerp(bend.lerp(gold_target, t), t)
		draw_set_transform(at if gold else at.round(), bit.spin * travel)
		var color: Color = bit.color
		color.a = fade * 0.85
		if gold:
			# Keep the printed face visible instead of tumbling through edge-on frames.
			var frame := 0
			var bill_size := Vector2(bit.size, bit.size * 0.5) * (1.0 - pull * pull)
			var region := Rect2(frame * 32, 96, 32, 16)
			for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_texture_rect_region(MONEY, Rect2(-bill_size * 0.5 + offset, bill_size),
					region, Color(0.08, 0.16, 0.06, fade * 0.8))
			draw_texture_rect_region(MONEY, Rect2(-bill_size * 0.5, bill_size),
				region, Color(0.65, 0.72, 0.57, fade))
			continue
		draw_texture_rect_region(SPARKLES, Rect2(Vector2.ONE * -bit.size * 0.5, Vector2.ONE * bit.size),
			Rect2(bit.frame * 16, 0, 16, 16), color)
	draw_set_transform(Vector2.ZERO)
