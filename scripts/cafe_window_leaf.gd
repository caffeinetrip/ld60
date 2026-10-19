extends CanvasLayer
## Now and then a leaf falls past the windows: a soft dark shape seen only through the glass,
## swinging side to side as it drops, its shadow sliding over the lit floor (owner: leaves
## outside the window instead of the sill cat). Drawn over the room in UI pixels, following the
## camera; behind_glass.gdshader keeps it where the picture behind is glass / lit floor.

const FALL := 3.4					# seconds from above the windows to under the sill
const DROP := Vector2(44, 124)		# world y fallen through
const ACROSS := Vector2(256, 300)	# world x a leaf starts at
const DRIFT := 16.0					# wind: px sideways over the whole fall, either way
const SWAY := 5.0					# px to each side of the swing
const SWING := 1.6					# seconds for one swing there and back
const TILT := 0.55					# the leaf dips into its swing
const GAP := Vector2(4.0, 10.0)		# seconds between two leaves
const PAIR := 0.3					# chance a second leaf follows close behind
const SHADE := Vector2(-45, 112)	# shadow of a leaf on the sill: x from the leaf, world y at x 258
const LIGHT := Vector2(-0.5, 0.25)	# the shadow moves this way per px the leaf is above the sill
const PAD := 4						# transparent border around the leaf, room for the blur
const LEAF := [
	".......##....",
	"....######...",
	"..#########..",
	"#############",
	"..##########.",
	"....######...",
	"......##.....",
]

var _leaves: Array[Dictionary] = []
var _leaf := _texture(1)
var _blur := _texture(2)
var _front := Node2D.new()
var _shadow := Node2D.new()
var _rng := RandomNumberGenerator.new()
var _wait := 0.0


func _init() -> void:
	name = "WindowLeaf"
	layer = 2
	follow_viewport_enabled = true


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(2.0, 4.0)
	_shadow.material = _material(Color(0, 0, 0, 0.4), 0.2, 0.26, 0.39, 3.0, 111.0)
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	_front.material = _material(Color8(52, 46, 40, 224), 0.43, 0.55, 2.0, 1.0, -10000.0)
	_front.draw.connect(_draw_front)
	add_child(_front)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_drop(0.0)
		if _rng.randf() < PAIR:
			_drop(-_rng.randf_range(0.5, 1.2))
		_wait = _rng.randf_range(GAP.x, GAP.y)
	for leaf in _leaves:
		leaf.time += delta
	_leaves = _leaves.filter(func(leaf: Dictionary) -> bool: return leaf.time < FALL)
	_front.queue_redraw()
	_shadow.queue_redraw()


## A new leaf; a negative `time` holds it back that long.
func _drop(time: float) -> void:
	_leaves.append({
		time = time,
		x = _rng.randf_range(ACROSS.x, ACROSS.y),
		drift = DRIFT * _rng.randf_range(-1.0, 1.0),
		phase = _rng.randf() * TAU,
		turn = -1.0 if _rng.randf() < 0.5 else 1.0,
		spin = _rng.randf_range(1.2, 2.6),
		roll = _rng.randf() * TAU,
	})


func _draw_front() -> void:
	for leaf in _leaves:
		if leaf.time < 0.0:
			continue
		_front.draw_set_transform(_at(leaf), _tilt(leaf), Vector2(leaf.turn, _roll(leaf)) * 0.5)
		_front.draw_texture(_leaf, -_leaf.get_size() / 2.0)
	_front.draw_set_transform(Vector2.ZERO)


func _draw_shadow() -> void:
	for leaf in _leaves:
		if leaf.time < 0.0:
			continue
		var at := _at(leaf)
		var sill := 73.0 + (at.x - 258.0) * 0.95
		var high := sill - at.y
		var fade := clampf(high / 10.0, 0.0, 1.0) * clampf((at.y - DROP.x) / 10.0, 0.0, 1.0)
		var spot := Vector2(at.x + SHADE.x, SHADE.y + (at.x - 258.0) * 0.5) + LIGHT * maxf(high, 0.0)
		_shadow.draw_set_transform(spot, _tilt(leaf) * 0.5, Vector2(leaf.turn * 1.6, _roll(leaf) * 0.8) * 0.25)
		_shadow.draw_texture(_blur, -_blur.get_size() / 2.0, Color(1, 1, 1, fade))
	_shadow.draw_set_transform(Vector2.ZERO)


## Falls straight through DROP, drifting with the wind, swinging like a pendulum: a bit higher
## at both ends of the swing.
func _at(leaf: Dictionary) -> Vector2:
	var k: float = leaf.time / FALL
	var swing := _swing(leaf)
	return Vector2(leaf.x + leaf.drift * k + SWAY * sin(swing), lerpf(DROP.x, DROP.y, k) - 2.0 * sin(swing) ** 2)


func _swing(leaf: Dictionary) -> float:
	return TAU * leaf.time / SWING + leaf.phase


func _tilt(leaf: Dictionary) -> float:
	return TILT * cos(_swing(leaf))


## The leaf turns over now and then: seen edge-on it gets thin.
func _roll(leaf: Dictionary) -> float:
	return 0.4 + 0.6 * absf(cos(leaf.spin * leaf.time + leaf.roll))


func _texture(grow: int) -> ImageTexture:
	var image := Image.create(LEAF[0].length() + PAD * 2, LEAF.size() + PAD * 2, false, Image.FORMAT_RGBA8)
	for y in LEAF.size():
		for x in LEAF[y].length():
			if LEAF[y][x] == "#":
				image.set_pixel(x + PAD, y + PAD, Color.WHITE)
	if grow > 1:
		image.resize(image.get_width() * grow, image.get_height() * grow, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


func _material(tint: Color, from_light: float, full_light: float, to_light: float, soft: float, above_y: float) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = preload("res://shaders/behind_glass.gdshader")
	out.set_shader_parameter(&"tint", tint)
	out.set_shader_parameter(&"from_light", from_light)
	out.set_shader_parameter(&"full_light", full_light)
	out.set_shader_parameter(&"to_light", to_light)
	out.set_shader_parameter(&"soft", soft)
	out.set_shader_parameter(&"above_y", above_y)
	return out
