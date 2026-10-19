extends Node2D
## Sparse, soft motes in room coordinates, underneath the UI and room grade.
## Each mote has its own slow drift and soft breathing cycle; no global RNG changes.

@export_range(0, 80) var amount := 2
@export var area := Rect2(86, 62, 184, 83)
@export_range(0.0, 2.0) var brightness := 0.8

var _rng := RandomNumberGenerator.new()
var _motes: Array[Dictionary] = []
var _lighting: Node
var _night := 0.0
var _glow: GradientTexture2D


func _ready() -> void:
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.4),
		Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)])
	_glow = GradientTexture2D.new()
	_glow.width = 32
	_glow.height = 32
	_glow.gradient = gradient
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	unlit.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = unlit
	_lighting = get_parent().get_node_or_null("Lighting")
	_rng.randomize()
	for i in amount:
		var mote := _new_mote()
		mote.age = _rng.randf() * float(mote.life)
		_motes.append(mote)


func _new_mote() -> Dictionary:
	return {
		"origin": Vector2(_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.position.y, area.end.y)),
		"age": 0.0,
		"life": _rng.randf_range(12.0, 23.0),
		"phase": _rng.randf() * TAU,
		"speed": _rng.randf_range(0.28, 0.56),
		"drift": Vector2(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.5, -0.18)),
		"tint": _rng.randf(),
		"strength": _rng.randf_range(0.45, 0.95),
	}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_night = float(_lighting.get("night")) if is_instance_valid(_lighting) else 0.0
	for i in _motes.size():
		_motes[i].age += delta
		if float(_motes[i].age) >= float(_motes[i].life):
			_motes[i] = _new_mote()
	queue_redraw()


func _draw() -> void:
	for mote in _motes:
		var age: float = mote.age
		var life: float = mote.life
		var phase: float = mote.phase
		var wave: float = age * float(mote.speed) + phase
		var pos: Vector2 = mote.origin + mote.drift * age
		pos += Vector2(sin(wave) * 4.0, cos(wave * 0.71) * 2.0)
		var fade := smoothstep(0.0, 3.0, age) * smoothstep(0.0, 4.0, life - age)
		var pulse := lerpf(0.55, 1.0, pow(0.5 + 0.5 * sin(wave * 1.3), 2.0))
		var alpha: float = fade * pulse * mote.strength * brightness * lerpf(0.55, 0.72, _night)
		var warm := Color(0.88, 0.76, 0.47).lerp(Color(0.70, 0.77, 0.52), mote.tint)
		var tint := warm.lerp(Color(0.68, 0.77, 0.53), _night * 0.35)
		# Continuous radial falloff, without a square core or stepped halo.
		draw_texture_rect(_glow, Rect2(pos - Vector2.ONE * 2.0, Vector2.ONE * 4.0),
			false, Color(tint, alpha))
