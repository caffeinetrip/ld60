extends CanvasLayer
## A few dim sprigs hanging into the top corners in front of everything but the UI (owner, the
## Slots & Daggers video: "just a tiny bit"). Room pixels, soft like out of focus, swaying.

const TONES := [Color8(16, 17, 13), Color8(19, 20, 15), Color8(22, 23, 17), Color8(25, 26, 19)]
const RIM := Color8(38, 37, 28)
const PERIOD := 4.8
const FLUTTER := 0.06
# leaves: [x, y, angle, length, width, tone, rim, phase]
const SPRIGS := [
	{anchor = Vector2(-6, 22), sway = 0.034, phase = 4.23,
		stem = [Vector2(-6, 22), Vector2(-1.3, 24.9), Vector2(3.3, 27.9), Vector2(7.8, 31), Vector2(12, 34.5)],
		leaves = [[-1.3, 24.9, 0.37, 6.2, 3.4, 2, false, 4.81], [-1.3, 24.9, 1.43, 6.9, 3.6, 0, true, 5.92],
			[3.3, 27.9, 0.32, 6.4, 3.3, 2, false, 4.6], [3.3, 27.9, 1.59, 5.8, 3.3, 3, false, 1.12],
			[7.8, 31, 1.61, 6.6, 3.5, 2, false, 5.54], [12, 34.5, 0.35, 6.1, 3.4, 1, true, 1.63],
			[12, 34.5, 1.33, 5.8, 3.6, 3, false, 0.91]]},
	{anchor = Vector2(-8, 36), sway = 0.031, phase = 2.86,
		stem = [Vector2(-8, 36), Vector2(-4.9, 40.3), Vector2(-1.8, 44.7), Vector2(0.7, 49.4)],
		leaves = [[-4.9, 40.3, 0.53, 5.8, 3.2, 2, false, 1.25], [-4.9, 40.3, 1.85, 7.2, 3.9, 1, true, 5.87],
			[-1.8, 44.7, 1.53, 7.2, 3.8, 2, true, 1.81], [0.7, 49.4, 0.63, 6.3, 3.6, 0, true, 1.2],
			[0.7, 49.4, 1.63, 5.1, 3.1, 2, false, 2.28]]},
	{anchor = Vector2(332, 4), sway = 0.036, phase = 3.12,
		stem = [Vector2(332, 4), Vector2(327.8, 7.6), Vector2(324, 11.6), Vector2(320.6, 15.9), Vector2(317.6, 20.5)],
		leaves = [[327.8, 7.6, 1.58, 7.4, 3.9, 1, true, 0.39], [327.8, 7.6, 2.86, 9.1, 5.2, 3, false, 2.02],
			[324, 11.6, 1.64, 8.5, 4.9, 1, false, 1.52], [324, 11.6, 2.53, 6.8, 3.6, 3, false, 3.13],
			[320.6, 15.9, 1.59, 5.7, 3, 2, true, 0.32], [320.6, 15.9, 2.7, 7.8, 4.3, 0, false, 0.58],
			[317.6, 20.5, 1.23, 6.9, 3.8, 3, false, 4.03], [317.6, 20.5, 2.62, 6.3, 3.7, 2, false, 2.46]]},
	{anchor = Vector2(328, -6), sway = 0.043, phase = 4.37,
		stem = [Vector2(328, -6), Vector2(325.9, -1.1), Vector2(324, 3.9), Vector2(322.1, 8.9)],
		leaves = [[325.9, -1.1, 1.42, 6.4, 3.7, 2, false, 0.38], [324, 3.9, 1.14, 7.1, 3.7, 0, true, 0.98],
			[324, 3.9, 2.34, 5.7, 3.4, 3, false, 3.46], [322.1, 8.9, 1.16, 4.9, 3, 3, false, 2.76]]},
]

var _time := 0.0
var _soft := GradientTexture2D.new()
var _canvas := Node2D.new()


func _init() -> void:
	name = "CornerLeaves"
	layer = 3


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	_soft.gradient = gradient
	_soft.width = 32
	_soft.height = 32
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.scale = Vector2.ONE * RoomView.SCALE
	_canvas.draw.connect(_draw_sprigs)
	add_child(_canvas)


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _draw_sprigs() -> void:
	for sprig: Dictionary in SPRIGS:
		var anchor: Vector2 = sprig.anchor
		var turn: float = sprig.sway * sin(TAU * _time / PERIOD + sprig.phase)
		var stem := PackedVector2Array()
		for point: Vector2 in sprig.stem:
			stem.append(anchor + (point - anchor).rotated(turn))
		_canvas.draw_polyline(stem, TONES[0], 1.0, true)
		for leaf: Array in sprig.leaves:
			var at := anchor + (Vector2(leaf[0], leaf[1]) - anchor).rotated(turn)
			var angle: float = leaf[2] + turn + FLUTTER * sin(TAU * _time / (PERIOD / 2.0) + leaf[7])
			_leaf(at, angle, leaf[3], leaf[4], TONES[leaf[5]])
			if leaf[6]:
				var side: Vector2 = Vector2.from_angle(angle + PI / 2.0) * leaf[4] * 0.3
				_leaf(at + side, angle, leaf[3] * 0.9, leaf[4] * 0.45, Color(RIM, 0.7))


## A soft oval from `at` along `angle`, a bit bigger than the leaf so its edge fades out around it.
func _leaf(at: Vector2, angle: float, length: float, width: float, color: Color) -> void:
	var size := _soft.get_size()
	var center := at + Vector2.from_angle(angle) * length * 0.5
	_canvas.draw_set_transform(center, angle, Vector2(length * 1.3, width * 1.6) / size)
	_canvas.draw_texture(_soft, -size / 2.0, color)
	_canvas.draw_set_transform(Vector2.ZERO)
