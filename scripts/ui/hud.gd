extends Control
## Top edge, quiet, sitting in the dark. Left: a small bill, the money, the day. Right: a
## row of bottle/count pairs; an empty one is darker with a red count. A count that changes
## jumps and lights up. HudStyle, worn print; the bottles are 1:1 on the font's pixel grid.

const SHELF := [
	[Ingredients.Kind.ALCOHOL, preload("res://art/ui/hud/room_alcohol.png")],
	[Ingredients.Kind.MIXER, preload("res://art/ui/hud/room_mixer.png")],
	[Ingredients.Kind.FLAVOR, preload("res://art/ui/hud/room_flavor.png")],
	[&"glasses", preload("res://art/ui/hud/room_glass.png")],
]
const SIDE := 24		# from the screen edges
const BASE := 22		# money/day text baseline
const STATUS_FONT_SIZE := HudStyle.RUN_FONT_SIZE
const STOCK_FONT_SIZE := HudStyle.RUN_FONT_SIZE
const STOCK_ICON_GAP := 4
const STOCK_PAIR_GAP := 12
const STOCK_SLOT := 1.6		# slot width per bottle pixel; the bottle itself is drawn 1:1, centred in it
const BOTTLE := Color(0.8, 0.8, 0.8)
const EMPTY := Color(0.45, 0.45, 0.45)

var _last := {}
var _bump := {}			# what changed -> 1..0
var _stock_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = PROCESS_MODE_ALWAYS		# a number that just changed finishes lighting up during a talk
	material = HudStyle.run_material()
	Game.money_changed.connect(_refresh.unbind(1))
	Game.stock_changed.connect(_refresh)
	Game.week_changed.connect(_refresh.unbind(1))
	Game.day_changed.connect(_refresh.unbind(1))
	_refresh()
	preload("res://scripts/ui/appear.gd").attach(self)
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue:
		dialogue.spots[&"stock"] = func(): return Rect2(global_position + _stock_rect.position, _stock_rect.size)


## The money line, for tests and debugging.
func text() -> String:
	return "$%d Day %d" % [Game.money, Game.day]


func _refresh() -> void:
	var now := {&"money": Game.money, &"day": Game.day, &"glasses": Game.glasses}
	for kind in Ingredients.KINDS:
		now[kind] = Game.stock[Game.selected[kind]]
	for key in now:
		if _last.has(key) and _last[key] != now[key]:
			_bump[key] = 1.0
	_last = now
	queue_redraw()


func _process(delta: float) -> void:
	if _bump.is_empty():
		return
	for key in _bump.keys():
		_bump[key] -= delta * 2.5
		if _bump[key] <= 0.0:
			_bump.erase(key)
	queue_redraw()


func _draw() -> void:
	# bill 148  Day 1 - the sale's flying bill, 1:1 on the digits' pixel grid, centred on them
	var bill: Texture2D = HudStyle.RUN_ART.BILL
	var icon_top := BASE - 12
	var icon_center_y := icon_top + bill.get_height() * 0.5
	draw_texture(bill, Vector2(SIDE, icon_top))
	var x := _value(SIDE + bill.get_width() + 4, BASE, str(Game.money), &"money", HudStyle.RUN_TEXT, STATUS_FONT_SIZE)
	x += 10
	draw_string(HudStyle.TALK_FONT, Vector2(x, BASE), "Day", HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, HudStyle.RUN_TEXT)
	x += HudStyle.TALK_FONT.get_string_size("Day", HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE).x - 1
	_value(x + 4, BASE, str(Game.day), &"day", HudStyle.RUN_TEXT, STATUS_FONT_SIZE)

	# Measure the whole row so larger counts stay next to their icons and grow left.
	var stock_width := 0.0
	for item in SHELF:
		var tex: Texture2D = item[1]
		var count_text := str(_last.get(item[0], 0))
		stock_width += roundf(tex.get_width() * STOCK_SLOT) + STOCK_ICON_GAP
		stock_width += HudStyle.TALK_FONT.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STOCK_FONT_SIZE).x
	stock_width += STOCK_PAIR_GAP * (SHELF.size() - 1)
	var stock_x := roundf(size.x - SIDE - stock_width)
	_stock_rect = Rect2(stock_x, BASE - 16, stock_width, 20)
	for item in SHELF:
		var tex: Texture2D = item[1]
		var n: int = _last.get(item[0], 0)
		var slot := roundf(tex.get_width() * STOCK_SLOT)
		var at := Vector2(stock_x + floorf((slot - tex.get_width()) * 0.5), roundf(icon_center_y - tex.get_height() * 0.5))
		draw_texture(tex, at, EMPTY if n <= 0 else BOTTLE)
		stock_x += slot + STOCK_ICON_GAP
		stock_x = _value(stock_x, BASE, str(n), item[0], HudStyle.WARN if n <= 0 else HudStyle.RUN_TEXT, STOCK_FONT_SIZE) + 1 + STOCK_PAIR_GAP


## A number; right after a change it sits 1 px higher and lights up.
func _value(x: float, baseline: float, s: String, key: Variant, color := HudStyle.TEXT, font_size := 16) -> float:
	var bump: float = _bump.get(key, 0.0)
	var col := color.lerp(HudStyle.RUN_BRIGHT, minf(bump * 2.0, 1.0))
	draw_string(HudStyle.TALK_FONT, Vector2(x, baseline - (1 if bump > 0.6 else 0)),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	return x + HudStyle.TALK_FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - 1
