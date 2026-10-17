extends Control

const SoundAPI = preload("res://scripts/audio/sound.gd")

var _panel: Panel
var _music: HSlider
var _sound: HSlider


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.position = Vector2(-16, 2)
	button.size = Vector2(14, 14)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button)
	add_child(button)
	button.draw.connect(_draw_icon.bind(button))
	button.pressed.connect(_toggle)
	_panel = Panel.new()
	_panel.position = Vector2(-126, 18)
	_panel.size = Vector2(124, 78)
	_panel.add_theme_stylebox_override("panel", _style(Color("2b1d2e")))
	_panel.hide()
	add_child(_panel)
	_music = _slider("Music", 5, &"Music")
	_sound = _slider("Sound", 28, &"SFX")
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(70, 54)
	close.size = Vector2(48, 18)
	close.focus_mode = Control.FOCUS_NONE
	_style_button(close)
	close.pressed.connect(_toggle)
	_panel.add_child(close)


func _toggle() -> void:
	_click()
	_panel.visible = not _panel.visible
	if _panel.visible:
		_music.set_value_no_signal(SoundAPI.get_bus_volume(&"Music"))
		_sound.set_value_no_signal(SoundAPI.get_bus_volume(&"SFX"))


func _slider(title: String, top: int, bus: StringName) -> HSlider:
	var label := Label.new()
	label.text = title
	label.position = Vector2(6, top)
	label.add_theme_color_override("font_color", Color("f2e6c9"))
	_panel.add_child(label)
	var slider := HSlider.new()
	slider.position = Vector2(50, top + 4)
	slider.size = Vector2(66, 12)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.focus_mode = Control.FOCUS_NONE
	slider.value = SoundAPI.get_bus_volume(bus)
	slider.add_theme_stylebox_override("slider", _style(Color("9c8a99")))
	slider.add_theme_stylebox_override("grabber_area", _style(Color("c9a24a")))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(Color("ffd34d")))
	var image := Image.create(3, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("ffd34d"))
	var texture := ImageTexture.create_from_image(image)
	for icon: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
		slider.add_theme_icon_override(icon, texture)
	slider.value_changed.connect(func(value: float) -> void: SoundAPI.set_bus_volume(bus, value))
	slider.drag_started.connect(_click)
	_panel.add_child(slider)
	return slider


func _click() -> void:
	var feel := get_node_or_null(^"/root/Feel")
	if feel != null:
		feel.call(&"play", &"ui/click")


func _draw_icon(button: Button) -> void:
	for row in 3:
		var y := float(4 + row * 3)
		button.draw_line(Vector2(3, y), Vector2(10, y), Color("f2e6c9"))
		button.draw_rect(Rect2(4 + (row % 2) * 4, y - 1, 1, 3), Color("ffd34d"))


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c9a24a")
	style.set_border_width_all(1)
	return style


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _style(Color("2b1d2e")))
	button.add_theme_stylebox_override("hover", _style(Color("493346")))
	button.add_theme_stylebox_override("pressed", _style(Color("65454d")))
	button.add_theme_color_override("font_color", Color("f2e6c9"))
