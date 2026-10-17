extends HBoxContainer
## Placeholder top bar: money and day on the left, stock of what's on sale on the right.

var _left := Label.new()
var _right := Label.new()


func _ready() -> void:
	position = Vector2(4, 1)
	size = Vector2(298, 27)
	mouse_filter = MOUSE_FILTER_IGNORE
	_right.size_flags_horizontal = SIZE_EXPAND_FILL
	_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label in [_left, _right]:
		label.add_theme_color_override("font_outline_color", Color("1a1220"))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_constant_override("line_spacing", -5)
		add_child(label)
	Game.money_changed.connect(_refresh.unbind(1))
	Game.stock_changed.connect(_refresh)
	Game.week_changed.connect(_refresh.unbind(1))	# after the day counter moves
	_refresh()


func _refresh() -> void:
	_left.text = "Money: $%d\nDay: %d" % [Game.money, Game.day]
	var parts := PackedStringArray()
	for kind in Ingredients.KINDS:
		parts.append("%s: %d" % [Ingredients.KIND_NAMES[kind], Game.stock[Game.selected[kind]]])
	_right.text = "  ".join(parts) + "\nGlasses: %d" % Game.glasses
