extends Control
## One crisp text stamp, a brief hold, then the report.

const HOLD := 0.65
const FONT := preload("res://art/fonts/PixelOperator8-Bold.ttf")
const FONT_SIZE := 8
const PIXEL_SCALE := 3.0
var title := ""
var detail := ""
var _punch := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func present(report: Dictionary) -> void:
	var copy := message(report)
	title = copy[0]
	detail = copy[1]
	await _present(HOLD)


func present_day(day_number: int) -> void:
	title = "DAY %d" % day_number
	detail = ""
	await _present(0.7, true)


func _present(hold: float, gentle: bool = false) -> void:
	_punch = 1.0 if gentle else 1.45
	modulate.a = 0.0 if gentle else 1.0
	show()
	queue_redraw()
	var pop := create_tween()
	if gentle:
		pop.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		pop.tween_property(self, "_punch", 1.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_interval(hold)
	pop.tween_property(self, "modulate:a", 0.0, 0.4 if gentle else 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pop.finished
	hide()
	modulate.a = 1.0


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


static func message(report: Dictionary) -> PackedStringArray:
	match report.get("ended_by", &""):
		&"stock":
			if report.get("glasses_left", 1) == 0:
				return ["Glasses used up", "Restock supplies before the next day."]
			return ["Supplies used up", "Not enough supplies for another drink."]
		&"time":
			return ["Time to close", "The working day is over."]
		&"nobody":
			return ["Price too high", "The price is too high. Try lowering it."]
	return ["Day finished", "Time to prepare for tomorrow."]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.018, 0.012, 0.44))
	var width := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var fit := minf(PIXEL_SCALE, floorf((size.x - 110.0) / maxf(width, 1.0)))
	var zoom := fit * _punch
	var at := (size * 0.5 - Vector2(width * zoom * 0.5, 3.0 * zoom)).round()
	draw_set_transform(at, 0.0, Vector2.ONE * zoom)
	draw_string(FONT, Vector2(0, 7), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, HudStyle.BRIGHT)
	draw_set_transform(Vector2.ZERO)
