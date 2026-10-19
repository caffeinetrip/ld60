extends Control
## Bottom right: sound (volume plate) and game speed (1x -> 2x -> 3x, shown as 1-3 arrows).
## Worn brass rings, brighter when hovered or active.

const SoundAPI = preload("res://scripts/audio/sound.gd")
const SPEEDS := [1.0, 2.0, 3.0]
const SPEED_ICONS := [preload("res://art/ui/hud/speed_1.png"), preload("res://art/ui/hud/speed_2.png"), preload("res://art/ui/hud/speed_3.png")]
const SOUND_ICON := preload("res://art/ui/hud/sound.png")
const RING := preload("res://art/ui/hud/ring.png")
const TRACK := preload("res://art/ui/hud/run/slider_track.png")
const FILL := preload("res://art/ui/hud/run/slider_fill.png")
const HOVER := preload("res://art/ui/hud/run/slider_hover.png")
const THUMB := preload("res://art/ui/hud/run/slider_thumb.png")
const RIGHT := 624		# same 16 px inset as the timer
const MIDDLE := 344
const REST := Color("82755e")

var _panel: Control
var _music: HSlider
var _sound: HSlider
var _speed: Button
var _sound_button: Button


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	material = HudStyle.run_material()
	var ring := RING.get_size().x
	_speed = _button(Vector2(RIGHT - ring, MIDDLE - floorf(ring / 2.0)), func() -> Texture2D: return SPEED_ICONS[SPEEDS.find(Feel.speed)],
		func() -> bool: return Feel.speed > 1.0)
	_speed.pressed.connect(_next_speed)
	_sound_button = _button(Vector2(RIGHT - ring * 2 - 6, MIDDLE - floorf(ring / 2.0)), func() -> Texture2D: return SOUND_ICON,
		func() -> bool: return _panel.visible)
	_sound_button.pressed.connect(_toggle)

	# volume, a small plate over the buttons
	_panel = Control.new()
	_panel.use_parent_material = true
	_panel.size = Vector2(120, 38)
	_panel.position = Vector2(RIGHT - _panel.size.x, MIDDLE - floorf(ring / 2.0) - 8 - _panel.size.y)
	_panel.draw.connect(func() -> void:
		HudStyle.plate(_panel, Rect2(Vector2.ZERO, _panel.size)))
	_panel.hide()
	add_child(_panel)
	_music = _slider("MUSIC", 9, &"Music")
	_sound = _slider("SOUND", 21, &"SFX")
	preload("res://scripts/ui/appear.gd").attach(self)
	preload("res://scripts/ui/appear.gd").attach(_panel)


## A thin ring with an icon: dim at rest, light when hovered, held or `on`.
func _button(at: Vector2, icon: Callable, on: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.use_parent_material = true
	b.position = at
	b.size = RING.get_size()
	b.draw.connect(func() -> void:
		var tex: Texture2D = icon.call()
		var lit: bool = on.call() or b.get_draw_mode() != BaseButton.DRAW_NORMAL
		var push := 1 if b.get_draw_mode() == BaseButton.DRAW_PRESSED else 0
		var col := HudStyle.RUN_BRIGHT if lit else REST
		b.draw_texture(RING, Vector2.ZERO, col)
		b.draw_texture(tex, ((b.size - tex.get_size()) / 2.0).floor() + Vector2(0, push), col))
	add_child(b)
	return b


func set_intro_mode(enabled: bool) -> void:
	var ring := RING.get_size().x
	_speed.visible = not enabled
	_sound_button.position = Vector2(RIGHT - ring, 16) if enabled else Vector2(RIGHT - ring * 2 - 6, MIDDLE - floorf(ring / 2.0))
	_panel.position = Vector2(RIGHT - _panel.size.x, 16 + ring + 8) if enabled else Vector2(RIGHT - _panel.size.x, MIDDLE - floorf(ring / 2.0) - 8 - _panel.size.y)
	_panel.hide()
	_sound_button.queue_redraw()


func _toggle() -> void:
	_click()
	_panel.visible = not _panel.visible
	_sound_button.queue_redraw()
	if _panel.visible:
		_music.set_value_no_signal(SoundAPI.get_bus_volume(&"Music"))
		_sound.set_value_no_signal(SoundAPI.get_bus_volume(&"SFX"))


func _next_speed() -> void:
	_click()
	Feel.speed = SPEEDS[(SPEEDS.find(Feel.speed) + 1) % SPEEDS.size()]
	_speed.queue_redraw()


func _slider(title: String, top: int, bus: StringName) -> HSlider:
	var label := Label.new()
	label.text = title
	label.use_parent_material = true
	label.position = Vector2(HudStyle.PAD + 1, top - 4)
	label.add_theme_font_override("font", HudStyle.TALK_FONT)
	label.add_theme_font_size_override("font_size", HudStyle.RUN_FONT_SIZE)
	label.add_theme_color_override("font_color", HudStyle.RUN_TEXT)
	_panel.add_child(label)
	var slider := HSlider.new()
	slider.use_parent_material = true
	slider.position = Vector2(52, top)
	slider.size = Vector2(_panel.size.x - 52 - HudStyle.PAD - 1, 6)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.focus_mode = Control.FOCUS_NONE
	slider.value = SoundAPI.get_bus_volume(bus)
	slider.add_theme_stylebox_override("slider", _style(TRACK))
	slider.add_theme_stylebox_override("grabber_area", _style(FILL))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(HOVER))
	for icon: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
		slider.add_theme_icon_override(icon, THUMB)
	slider.value_changed.connect(func(value: float) -> void: SoundAPI.set_bus_volume(bus, value))
	slider.drag_started.connect(_click)
	_panel.add_child(slider)
	return slider


func _click() -> void:
	var feel := get_node_or_null(^"/root/Feel")
	if feel != null:
		feel.call(&"play", &"ui/click")


func _style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
