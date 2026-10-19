extends CanvasLayer
## VN-style talks between the hero and his sister: `await Dialogue.play(&"intro")`.
## The game is paused while a talk is open; LMB anywhere shows the rest of the line or
## goes on to the next one. Texts are in DialogueLines.
## The owner's art (ui/vn: the bar and both portraits as whole 320x180 frames) is drawn
## in room pixels in its own viewport, under the room's grade (main.gd hands over its
## material), and shown 2x. The text goes on top in UI pixels, between the portraits.
## Only those who speak in a talk are on screen. A line with `point` first takes the
## clicks away and slides a light over that HUD spot (`spots`, filled by the HUD).

signal finished(id: StringName)
signal _read_out

const BAR := preload("res://ui/vn/vn bar.png")
const ROOM := Vector2(320, 180)
const TEXT_X := 204.0
const TEXT_W := 242.0
const NAME_Y := 276.0			# baselines
const ROW_Y := 296.0
const ROW := 16.0
const MAX_ROWS := 3
const MARK := Vector2(440, 332)	# the next arrow
const DIM := 0.12				# the room behind
const SHADE := Color(0.55, 0.55, 0.55)	# the one who isn't talking
const LIGHT_TIME := 0.1
const ENTER := 0.13
const RISE := 10.0
const EXIT := 0.27
const DROP := 14.0
const BREATH := 1.2				# the speaker is a pixel higher every other BREATH s
const CHAR_TIME := 1.0 / 26.0
const STOP_TIME := 0.12			# after . , ! ?
const STOPS := ".,!?"
const BLINK := 0.5
const COL_TEXT := HudStyle.BRIGHT
const NEXT := preload("res://art/ui/dialogue/next.png")
const SPOT_TIME := 1.2			# the light finds what she points at, then the line types
const SPOT_PAD := 8.0
const SPOT_OFF := 0.5
const SPOT_BREATH := 2.4		# the hole grows by a pixel or two and back
const SPOT_GROW := 2.0

const CAST := {
	&"hero": {name = "You", art = preload("res://ui/vn/vnboy.png")},
	&"sister": {name = "Jae", art = preload("res://ui/vn/vngirl.png")},
}

var skip_all := DisplayServer.get_name() == "headless"	# tests never wait for a click
var grade: ShaderMaterial:
	set(value):
		grade = value
		_grade.material = value
		_grade.visible = value != null

var _playing := &""
var _lines: Array = []
var _index := 0
var _who := &""
var _text := ""
var _rows := PackedStringArray()
var _shown := 0
var _letters := 0
var _wait := 0.0
var _blink := 0.0
var _clock := 0.0
var _lit := {}
var _all_lit := false
var _bar := false
var _tween: Tween
var _was_paused := false
var spots := {}					# id -> Callable returning a Rect2 in UI px
var vars := {}					# "{key}" in a line -> value, e.g. the run's numbers for the last talk
var pointing := &""
var _speakers := {}
var _spot := Rect2()
var _veil := 0.0
var _hold := 0.0
var _spot_tween: Tween
var _lone := false				# spotlight() without a talk

var _art := SubViewport.new()
var _stage := Control.new()
var _grade := ColorRect.new()
var _dim := ColorRect.new()
var _picture := TextureRect.new()

@onready var _view: Control = $View


func _ready() -> void:
	_art.size = Vector2i(ROOM)
	_art.transparent_bg = true
	_art.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_art.snap_2d_transforms_to_pixel = true
	_art.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_art)
	for c: Control in [_stage, _grade]:
		c.size = ROOM
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.add_child(c)
	_grade.visible = grade != null
	_stage.draw.connect(_draw_stage)

	_dim.color = Color.BLACK
	var veil := ShaderMaterial.new()
	veil.shader = preload("res://shaders/spotlight.gdshader")
	veil.set_shader_parameter(&"dim", DIM)
	_dim.material = veil
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.texture = _art.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.size = ROOM * 2.0
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for c: Control in [_dim, _picture]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.hide()
		add_child(c)
		move_child(c, _view.get_index())
	_view.hide()
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	for who: StringName in CAST:
		_lit[who] = 0.0


func play(id: StringName) -> void:
	var lines: Array = DialogueLines.LINES.get(id, [])
	if lines.is_empty():
		return
	# after the boss the bar just goes on, nobody talks any more
	if skip_all or Game.endless:
		finished.emit(id)
		return
	while is_open():
		await finished
	_playing = id
	_lines = lines
	_speakers.clear()
	for line: Dictionary in lines:
		_speakers[line.who] = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_line(0)
	for who: StringName in CAST:
		_lit[who] = 1.0 if who == _who else 0.0
	_all_lit = false
	_bar = true
	_enter(0.0)
	_set_shown(true)
	Feel.play(&"dlg/open")
	_move(_enter, ENTER)
	await _read_out
	pointing = &""
	Feel.play(&"dlg/close")
	_bar = false
	_all_lit = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _move(_exit, EXIT)
	_set_shown(false)
	if _spot_tween:
		_spot_tween.kill()
	_veil = 0.0
	get_tree().paused = _was_paused
	_playing = &""
	finished.emit(id)


## Only the light, no talk: it finds `rect` (UI px), holds and lets go, `seconds` in all.
func spotlight(rect: Rect2, seconds: float) -> void:
	if skip_all or is_open() or _lone:
		return
	_lone = true
	_spot = get_viewport().get_visible_rect().grow(SPOT_PAD * 4.0)
	_veil = 0.0
	_dim.modulate.a = 0.0
	_dim.show()
	var slide := seconds * 0.4
	var off := seconds * 0.25
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	t.tween_property(self, "_veil", 1.0, slide)
	t.tween_property(self, "_spot", rect.grow(SPOT_PAD), slide)
	t.tween_property(_dim, "modulate:a", 1.0, slide * 0.5)
	t.chain().tween_property(self, "_veil", 0.0, off).set_delay(seconds - slide - off)
	t.tween_property(_dim, "modulate:a", 0.0, off).set_delay(seconds - slide - off)
	await t.finished
	_dim.hide()
	_lone = false


func is_open() -> bool:
	return _playing != &""


func finish_now() -> void:
	if is_open() and _index < _lines.size():
		_show_line(_lines.size())


func is_typing() -> bool:
	return _shown < _text.length()


## Same as a click: the rest of the line, or the next line.
func advance() -> void:
	if not is_open() or _index >= _lines.size() or _hold > 0.0:
		return
	Feel.play(&"dlg/click")
	if is_typing():
		_shown = _text.length()
	else:
		_show_line(_index + 1)


func _show_line(index: int) -> void:
	_index = index
	if index >= _lines.size():
		_read_out.emit()
		return
	_who = _lines[index].who
	_text = _lines[index].text.replace("$N", "$%d" % Tune.QUOTA).format(vars)
	_rows = _wrap(_text)
	_shown = 0
	_letters = 0
	_wait = 0.0
	_point(_lines[index].get("point", &""))


## The light slides to the spot (from the whole screen the first time), the text waits for it.
func _point(id: StringName) -> void:
	if id != &"" and not spots.has(id):
		id = &""
	if id == pointing:
		return
	pointing = id
	if _spot_tween:
		_spot_tween.kill()
	_spot_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if id == &"":
		_spot_tween.tween_property(self, "_veil", 0.0, SPOT_OFF)
		return
	if _veil <= 0.0:
		_spot = get_viewport().get_visible_rect().grow(SPOT_PAD * 4.0)
	var to: Rect2 = spots[id].call()
	_spot_tween.tween_property(self, "_veil", 1.0, SPOT_TIME)
	_spot_tween.tween_property(self, "_spot", to.grow(SPOT_PAD), SPOT_TIME)
	_wait = SPOT_TIME
	_hold = SPOT_TIME


## Rows of the text that fit the box. Each break eats one space, so the rows plus the
## breaks are exactly the text and `_shown` can walk over them.
func _wrap(text: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for para in text.split("\n"):
		var words := para.split(" ")
		var row := words[0]
		for i in range(1, words.size()):
			var wider := row + " " + words[i]
			if HudStyle.width(wider, HudStyle.TALK_FONT) > TEXT_W:
				rows.append(row)
				row = words[i]
			else:
				row = wider
		rows.append(row)
	return rows


func _process(delta: float) -> void:
	if not is_open() and not _lone:
		return
	_clock += delta
	var hole := _spot.grow(SPOT_GROW * (0.5 - 0.5 * cos(_clock * TAU / SPOT_BREATH)))
	_dim.material.set_shader_parameter(&"veil", _veil)
	_dim.material.set_shader_parameter(&"spot", Vector4(hole.position.x, hole.position.y, hole.size.x, hole.size.y))
	if not is_open():
		return
	_hold = maxf(_hold - delta, 0.0)
	_blink = 0.0 if is_typing() else _blink + delta
	if is_typing():
		_wait -= delta
	while is_typing() and _wait <= 0.0:
		var c := _text[_shown]
		_shown += 1
		_wait += CHAR_TIME + (STOP_TIME if c in STOPS else 0.0)
		if c != " ":
			_letters += 1
			if _letters % 2 == 1:
				Feel.play(&"dlg/blip")
	for who: StringName in CAST:
		var on := 1.0 if who == _who or _all_lit else 0.0
		_lit[who] = move_toward(_lit[who], on, delta / LIGHT_TIME)
	_stage.queue_redraw()
	_view.queue_redraw()


func _on_view_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_view.accept_event()
		advance()


func _set_shown(on: bool) -> void:
	for c: CanvasItem in [_dim, _picture, _view]:
		c.visible = on
	_art.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _move(step: Callable, time: float) -> Signal:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(step, 0.0, 1.0, time)
	return _tween.finished


## Portraits rise into place and the whole thing fades in.
func _enter(t: float) -> void:
	var k := 1.0 - pow(1.0 - t, 3.0)
	_picture.position.y = roundf((1.0 - k) * RISE)
	_picture.modulate.a = k
	_dim.modulate.a = k
	_view.modulate.a = k


## The bar and the text are gone at once, both portraits light up, sink and fade.
func _exit(t: float) -> void:
	_picture.position.y = roundf((1.0 - pow(1.0 - t, 3.0)) * DROP)
	_picture.modulate.a = 1.0 - t
	_dim.modulate.a = 1.0 - t


func _draw_stage() -> void:
	if _bar:
		_stage.draw_texture(BAR, Vector2.ZERO)
	for who: StringName in CAST:
		if not _speakers.has(who):
			continue
		var up := 1.0 if _bar and who == _who and int(_clock / BREATH) % 2 == 1 else 0.0
		_stage.draw_texture(CAST[who].art, Vector2(0, -up), SHADE.lerp(Color.WHITE, _lit[who]))


func _draw_view() -> void:
	if not _bar:
		return
	var font := HudStyle.TALK_FONT
	var who_name: String = CAST[_who].name if CAST.has(_who) else String(_who).capitalize()
	HudStyle.text(_view, TEXT_X, NAME_Y, who_name, COL_TEXT, font)
	var left := _shown
	for i in _rows.size():
		if left <= 0:
			break
		HudStyle.text(_view, TEXT_X, ROW_Y + i * ROW, _rows[i].left(left), COL_TEXT, font)
		left -= _rows[i].length() + 1
	if not is_typing() and fmod(_blink, BLINK * 2.0) < BLINK:
		_view.draw_texture(NEXT, MARK)
