class_name WinScreen
extends Control
## The end of the run over the dimmed game: the numbers count up row by row, show_button()
## brings "Play again". Keeps running while a dialogue pauses the tree; the bottom
## (y 124-174) stays free for the dialogue box.

signal play_again

const PANEL := Rect2(92, 20, 136, 98)
const PANEL_ART := preload("res://art/ui/win/panel.png")	# frame, corner dots, the line under the title
const ROWS := [["Time", "time"], ["Days", "days"], ["Week", "week"], ["Boss tries", "tries"]]
const OPEN := 0.3			# dim + panel
const ROW_GAP := 0.25
const COUNT := 0.4			# a number counts up this long
const COL_DARK := Color("1a1220")
const COL_PANEL := Color("2b1d2e")
const COL_FRAME := Color("c9a24a")
const COL_TEXT := Color("f2e6c9")
const COL_DIM := Color("9c8a99")
const COL_ACCENT := Color("ffd34d")

var _stats := {}
var _t := 0.0
var _button := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_STOP
	_button.text = "Play again"
	_button.focus_mode = FOCUS_NONE
	_button.add_theme_stylebox_override("normal", _box(COL_DARK, COL_FRAME))
	_button.add_theme_stylebox_override("hover", _box(COL_PANEL, COL_ACCENT))
	_button.add_theme_stylebox_override("pressed", _box(COL_FRAME, COL_ACCENT))
	_button.add_theme_stylebox_override("disabled", _box(COL_DARK, COL_DIM))
	_button.add_theme_color_override("font_color", COL_TEXT)
	_button.add_theme_color_override("font_hover_color", COL_ACCENT)
	_button.add_theme_color_override("font_pressed_color", COL_DARK)
	_button.add_theme_color_override("font_disabled_color", COL_DIM)
	_button.pressed.connect(_on_play_again)
	_button.hide()
	add_child(_button)
	# after the styles, a Control never shrinks back to a smaller minimum
	_button.position = Vector2(128, 96)
	_button.size = Vector2(64, 16)
	hide()


## {time (seconds), days, week ($), tries (boss attempts)}
func show_result(stats: Dictionary) -> void:
	_stats = stats
	_t = 0.0
	_button.hide()
	_button.disabled = false
	show()


func show_button() -> void:
	if _button.visible:
		return
	_button.show()
	_button.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_button, "modulate:a", 1.0, 0.2)
	t.tween_property(_button, "position:y", _button.position.y, 0.2).from(_button.position.y + 4.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## 754 -> "12:34"
static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]


func _on_play_again() -> void:
	if _button.disabled:
		return
	_button.disabled = true
	Feel.play(&"ui/click")
	play_again.emit()


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


func _row_at(i: int) -> float:
	return OPEN + ROW_GAP * i


func _count(i: int) -> float:
	var p := clampf((_t - _row_at(i)) / COUNT, 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 3.0)


func _value(i: int, done := false) -> String:
	var key: String = ROWS[i][1]
	var v := float(_stats.get(key, 0)) * (1.0 if done else _count(i))
	match key:
		"time":
			return clock(v)
		"week":
			return "$%d" % roundi(v)
	return str(roundi(v))


func _process(delta: float) -> void:
	if not visible:
		return
	var before := _t
	_t += delta
	for i in ROWS.size():
		if before < _row_at(i) and _t >= _row_at(i):
			Feel.play(&"win/row")
	queue_redraw()


func _draw() -> void:
	var open := clampf(_t / OPEN, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(COL_DARK, 0.6 * open))
	var c := PANEL.get_center()
	var grow: float = Tween.interpolate_value(0.0, 1.0, open, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT)
	draw_set_transform(c, 0.0, Vector2(1.0, grow))
	var r := Rect2(PANEL.position - c, PANEL.size)
	draw_texture(PANEL_ART, r.position)

	var font := get_theme_default_font()
	var at := r.position + Vector2(0, 15)
	draw_string_outline(font, at, "YOU WIN", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, 2, COL_DARK)
	draw_string(font, at, "YOU WIN", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, COL_ACCENT)

	var left := r.position.x + 12
	var width := r.size.x - 24
	for i in ROWS.size():
		if _t < _row_at(i):
			break
		var y := r.position.y + 33 + i * 11
		var label: String = ROWS[i][0]
		draw_string(font, Vector2(left, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_DIM)
		var counting := _count(i) < 1.0
		draw_string(font, Vector2(left, y), _value(i), HORIZONTAL_ALIGNMENT_RIGHT, width, 16, COL_ACCENT if counting else COL_TEXT)
		# dotted leader between the name and the final number
		var from := left + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 3
		var to := left + width - font.get_string_size(_value(i, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x - 3
		for x in range(int(from), int(to), 2):
			draw_rect(Rect2(x, y - 1, 1, 1), Color(COL_DIM, 0.5))
	draw_set_transform(Vector2.ZERO)
