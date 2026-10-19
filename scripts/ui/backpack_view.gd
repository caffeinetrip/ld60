class_name BackpackView
extends Control
## Relic grids for the night panel: the pocket (left) and the backpack (right), both on
## cells. Drag a relic with LMB, RMB or wheel turns it while carried. Carried it lifts and
## trails the mouse, a green / red silhouette shows where it would land; dropped where it
## can't go it flies back. Hover or carry a relic: its neighbor ring lights up and the
## relics it works on get an outline; hover one for its tooltip. The rules live in Backpack.
## Compact layout embeds the inventory and backpack inside the CRT.

const CELL := 16
const POCKET_AT := Vector2(104, 0)
const TIP_W := 180
const PAD := 5			# tooltip padding
const LIFT := 1.25		# a carried relic is drawn this much bigger
const RAISE := 2.0		# px up, so its landing silhouette peeks out under it
const FOLLOW := 22.0	# how fast a carried relic catches up with the mouse
const LAND := 0.1		# s, a dropped relic settles into its cells
const BACK := 0.15		# s, flies back when dropped where it can't go
const GHOST := 0.25		# s, the landing silhouette fades
var ROW := 10			# tooltip line height
var CAP := 7			# cap height of the tooltip font, draw_string wants the baseline
var COL_CELL := Color("1a1220")
const CELL_ART := preload("res://art/ui/backpack/cell.png")
const CELL_ART_COMPACT := preload("res://art/ui/backpack/cell_compact.png")
var COL_FRAME := Color("c9a24a")
const COL_TEXT := Color("f2e6c9")
const COL_DIM := Color("9c8a99")
const COL_LIT := Color("ffd34d")
const COL_RING := Color("c9a24a", 0.3)
const COL_OK := Color("7fd17f", 0.55)
const COL_BAD := Color("e05a5a", 0.55)

var compact := false
var grid_origin := Vector2.ZERO
var pocket_origin := POCKET_AT
var _cell := CELL
var _pocket_shown := 4		# pocket rows on screen, the wheel scrolls the rest
var _pocket_scroll := 0		# rows

var _held := {}			# {id, rot, from = {grid, cell, rot} or {}, grab = mouse - its top left, at, lift}
var _fly := {}			# {item, from, lift, t, time, ghost}: a dropped relic on its way to its cells
var _focus := {}		# the relic whose ring shows: hovered, or held over a free spot
var _info := Label.new()
var _tip := Control.new()
var _tip_info := {}
var _tip_rows := []		# [text, starts a bullet]
var _tip_flavor := PackedStringArray()
var _tip_name := PackedStringArray()


func _ready() -> void:
	if compact:
		_cell = 10
		pocket_origin = Vector2.ZERO
		_pocket_shown = 7
		grid_origin = Vector2(76, 0)
		COL_CELL = Color("354b45")
		COL_FRAME = Color("69796f")
		ROW = 12
		CAP = 9
	custom_minimum_size = Vector2(136, 78) if compact else Vector2(304, 124)
	size = custom_minimum_size
	_info.position = Vector2(0, 75) if compact else Vector2(0, 68)
	_info.size = Vector2(90, 16) if compact else Vector2(304, 52)
	_info.mouse_filter = MOUSE_FILTER_IGNORE
	_info.clip_text = true
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_tip.z_index = 1
	_tip.top_level = true		# Keep readable UI pixels even inside the scaled room.
	_tip.mouse_filter = MOUSE_FILTER_IGNORE
	_tip.draw.connect(_draw_tip)
	_tip.hide()
	add_child(_tip)
	preload("res://scripts/ui/appear.gd").attach(_tip)
	set_process(false)
	Game.backpack.changed.connect(_refresh)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_put_back()
	elif what == NOTIFICATION_MOUSE_EXIT and is_inside_tree():
		_refresh()


func _bp() -> Backpack:
	return Game.backpack


## The mouse in the view's pixels.
func _mouse() -> Vector2:
	return get_local_mouse_position()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		accept_event()
		var wheel := mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				_release(mb.position)
		elif mb.pressed and not _held.is_empty():
			_turn(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1)
		elif mb.pressed and wheel and _pocket_rect().has_point(mb.position):
			var most := maxi(0, _bp().pocket_rows() - _pocket_shown)
			_pocket_scroll = clampi(_pocket_scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, most)
			_refresh()
	if event is InputEventMouseMotion:
		_refresh()


func _process(delta: float) -> void:
	if not _held.is_empty():
		var to: Vector2 = _mouse() - _held.grab
		_held.at = _held.at.lerp(to, 1.0 - exp(-FOLLOW * delta))
		_held.lift = move_toward(_held.lift, LIFT, delta * 4.0)
	if not _fly.is_empty():
		_fly.t += delta
		if _fly.t >= maxf(_fly.time, GHOST if _fly.ghost else 0.0):
			_fly = {}
	set_process(not _held.is_empty() or not _fly.is_empty())
	queue_redraw()


## LMB down on a relic picks it up where it was grabbed.
func _press(at: Vector2) -> void:
	if not _held.is_empty():
		return
	var grid := true
	var item := _bp().item_at(_cell_at(at))
	if item.is_empty() and _pocket_rect().has_point(at):
		grid = false
		item = _bp().pocket_at(_pocket_cell(at))
	if item.is_empty():
		return
	if not _fly.is_empty() and is_same(_fly.item, item):
		_fly = {}
	var top := _top_left(item, grid)
	if grid:
		_bp().take(item)
	else:
		_bp().take_from_pocket(item)
	_hold(item.id, item.rot, {grid = grid, cell = item.cell, rot = item.rot}, at - top)


## LMB up: lands on the spot under it, or flies back where it came from.
func _release(at: Vector2) -> void:
	if _held.is_empty():
		return
	var spot := _spot(at)
	var held := _held
	_held = {}
	var links := _links()
	var item := {}
	if spot.get("ok", false):
		item = _bp().place(held.id, spot.cell, held.rot) if spot.grid else _bp().put_in_pocket(held.id, spot.cell, held.rot)
		Feel.play(&"relic/drop")
		if _links() > links:
			Feel.play(&"relic/star")
	else:
		item = _return(held.id, held.from)
		Feel.play(&"ui/error" if not spot.is_empty() else &"relic/drop")
	_fly = {item = item, from = held.at, lift = held.lift, t = 0.0,
		time = LAND if spot.get("ok", false) else BACK, ghost = spot.get("ok", false)}
	set_process(true)
	_refresh()


## `grab` = the mouse minus the relic's top left; zero = its middle.
func _hold(id: StringName, rot: int, from: Dictionary, grab := Vector2.ZERO) -> void:
	if grab == Vector2.ZERO:
		grab = _box(id, rot) / 2.0
	_held = {id = id, rot = rot, from = from, grab = grab, at = _mouse() - grab, lift = 1.0}
	Feel.play(&"relic/pick")
	set_process(true)
	_refresh()


## Turns the carried relic around the mouse.
func _turn(by: int) -> void:
	_held.rot = posmod(_held.rot + by, 4)
	_held.grab = _box(_held.id, _held.rot) / 2.0
	Feel.play(&"relic/rotate")
	_refresh()


## Panel closed mid-drag: the relic goes back where it came from.
func _put_back() -> void:
	_fly = {}
	if _held.is_empty():
		return
	var held := _held
	_held = {}
	_return(held.id, held.from)


func _return(id: StringName, from: Dictionary) -> Dictionary:
	var item := {}
	if not from.is_empty():
		item = _bp().place(id, from.cell, from.rot) if from.grid else _bp().put_in_pocket(id, from.cell, from.rot)
	if item.is_empty():
		item = _bp().add_to_pocket(id)
	return item


## Where the carried relic would land if dropped with the mouse at `at`:
## {grid (else the pocket), cell, ok}, or {} when the mouse is over neither.
func _spot(at: Vector2) -> Dictionary:
	var top: Vector2 = at - _held.grab
	if _grid_rect().grow(_cell / 2.0).has_point(at):
		var cell := Vector2i(((top - grid_origin) / _cell).round())
		return {grid = true, cell = cell, ok = _bp().can_place(_held.id, cell, _held.rot)}
	if _pocket_rect().grow(_cell / 2.0).has_point(at):
		var cell := Vector2i(((top - _pocket_top()) / _cell).round())
		var rows := _pocket_scroll + _pocket_shown
		var fits := _bp().can_pocket(_held.id, cell, _held.rot) and cell.y >= _pocket_scroll
		for c in Backpack.turned(_held.id, _held.rot):
			fits = fits and cell.y + c.y < rows
		return {grid = false, cell = cell, ok = fits}
	return {}


## How many neighbors get their numbers changed, all relics together.
func _links() -> int:
	var n := 0
	for item in _bp().items:
		n += _bp().affects(item).size()
	return n


func _cell_at(at: Vector2) -> Vector2i:
	return Vector2i(((at - grid_origin) / _cell).floor())


func _pocket_cell(at: Vector2) -> Vector2i:
	return Vector2i(((at - _pocket_top()) / _cell).floor())


func _on_grid(c: Vector2i) -> bool:
	var grid := Backpack.size()
	return c.x >= 0 and c.y >= 0 and c.x < grid.x and c.y < grid.y


func _grid_rect() -> Rect2:
	return Rect2(grid_origin, Vector2(Backpack.size() * _cell))


func _pocket_rect() -> Rect2:
	return Rect2(pocket_origin, Vector2(Backpack.POCKET.x, _pocket_shown) * _cell)


## Where pocket row 0 is drawn, scrolled.
func _pocket_top() -> Vector2:
	return pocket_origin - Vector2(0, _pocket_scroll * _cell)


func _pocket_visible(item: Dictionary) -> bool:
	for c in _bp().cells_of(item):
		if c.y < _pocket_scroll or c.y >= _pocket_scroll + _pocket_shown:
			return false
	return true


func _top_left(item: Dictionary, grid: bool) -> Vector2:
	return (grid_origin if grid else _pocket_top()) + Vector2(item.cell * _cell)


## Pixel size of a relic turned by `rot`.
func _box(id: StringName, rot: int) -> Vector2:
	return _bounds(Backpack.turned(id, rot)).size


## Pixel rect around cells.
func _bounds(cells: Array[Vector2i]) -> Rect2:
	var low := cells[0]
	var high := cells[0]
	for c in cells:
		low = low.min(c)
		high = high.max(c)
	return Rect2(Vector2(low * _cell), Vector2((high - low + Vector2i.ONE) * _cell))


func _refresh() -> void:
	var at := _mouse()
	var inside := is_visible_in_tree() and Rect2(Vector2.ZERO, size).has_point(at)
	_focus = {}
	var tip := &""
	var live := {}
	var near := Rect2()
	if not _held.is_empty():
		var spot := _spot(at)
		if spot.get("ok", false) and spot.grid:
			_focus = {id = _held.id, cell = spot.cell, rot = _held.rot}
	elif inside:
		var item := _bp().item_at(_cell_at(at))
		var pocketed := _bp().pocket_at(_pocket_cell(at)) if _pocket_rect().has_point(at) else {}
		if not item.is_empty():
			_focus = item
			tip = item.id
			live = _bp().live(item)
			# beside the grid, so the lit ring stays in sight
			near = _bounds(_bp().cells_of(item))
			near.position += grid_origin
			near = near.expand(Vector2(grid_origin.x + Backpack.size().x * _cell, near.position.y))
		elif not pocketed.is_empty():
			tip = pocketed.id
			near = Rect2(_top_left(pocketed, false), _box(pocketed.id, pocketed.rot))
	_set_tip(tip, live, near)
	if _bp().items.is_empty() and _bp().pocket.is_empty():
		_info.text = "No relics yet. Special cats bring them."
	else:
		_info.text = "Neighbor effects include diagonal items."
	_info.tooltip_text = _info.text
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if tip != &"" or not _held.is_empty() else CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	var grid := Backpack.size()
	for y in grid.y:
		for x in grid.x:
			_draw_cell(grid_origin + Vector2(x, y) * _cell)
	for y in _pocket_shown:
		for x in Backpack.POCKET.x:
			_draw_cell(pocket_origin + Vector2(x, y) * _cell)
	for item in _bp().items:
		if _fly.is_empty() or not is_same(_fly.item, item):
			_draw_relic(item.id, item.rot, _top_left(item, true))
	for item in _bp().pocket:
		if _pocket_visible(item) and (_fly.is_empty() or not is_same(_fly.item, item)):
			_draw_relic(item.id, item.rot, _top_left(item, false))
	if not _focus.is_empty():
		for c in _bp().ring(_focus):
			if _on_grid(c):
				draw_rect(Rect2(grid_origin + Vector2(c * _cell), Vector2(_cell, _cell)), COL_RING)
		for other in _bp().affects(_focus):
			_outline(_bp().cells_of(other), grid_origin, COL_LIT)

	if not _fly.is_empty():
		var item: Dictionary = _fly.item
		var to := _top_left(item, _bp().items.has(item))
		if _fly.ghost:
			_draw_ghost(item.id, item.rot, to, Color(COL_OK, COL_OK.a * (1.0 - _fly.t / GHOST)))
		var p := 1.0 - pow(1.0 - minf(_fly.t / _fly.time, 1.0), 3.0)
		var lift := lerpf(_fly.lift, 1.0, p)
		var up := RAISE * (lift - 1.0) / (LIFT - 1.0)
		_draw_relic(item.id, item.rot, _fly.from.lerp(to, p) - Vector2(0, up), lift, false)
	if not _held.is_empty():
		var spot := _spot(_mouse())
		if not spot.is_empty():
			var top := (grid_origin if spot.grid else _pocket_top()) + Vector2(spot.cell * _cell)
			_draw_ghost(_held.id, _held.rot, top, COL_OK if spot.ok else COL_BAD)
		var up: float = RAISE * (_held.lift - 1.0) / (LIFT - 1.0)
		_draw_relic(_held.id, _held.rot, _held.at - Vector2(0, up), _held.lift, false)


## Empty cell: dark, dashed 1 px inside its edge (compact: plain, 1 px apart).
func _draw_cell(at: Vector2) -> void:
	draw_texture(CELL_ART_COMPACT if compact else CELL_ART, at)


## A relic with its top left at `at`, `lift` times bigger around its middle. `seated` ones
## get their rarity tint under them.
func _draw_relic(id: StringName, rot: int, at: Vector2, lift := 1.0, seated := true) -> void:
	var def := Relics.get_def(id)
	var col: Color = Relics.RARITY_COLOR.get(def.get("rarity"), COL_DIM)
	var cells := Backpack.turned(id, rot)
	var tex := Relics.icon(id)
	if tex:
		if seated:
			for c in cells:
				draw_rect(Rect2(at + Vector2(c * _cell), Vector2(_cell - 1, _cell - 1)), Color(col, 0.3))
		_draw_icon(tex, rot, at, _box(id, rot), lift, Color.WHITE)
		return
	draw_set_transform(at + _box(id, rot) / 2.0, 0.0, Vector2.ONE * lift)
	at = -_box(id, rot) / 2.0
	for c in cells:
		draw_rect(Rect2(at + Vector2(c * _cell), Vector2(_cell, _cell)), col)
	_outline(cells, at, col.lightened(0.4))
	var font := get_theme_default_font()
	var font_size := 8 if compact else 16
	var letter: String = def.get("name", "?").left(1)
	var x := floorf((_cell - font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) / 2.0) + 1.0
	draw_string(font, at + Vector2(cells[0] * _cell) + Vector2(x, 7 if compact else 12), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COL_CELL)
	draw_set_transform(Vector2.ZERO)


## The silhouette of a relic where it would land.
func _draw_ghost(id: StringName, rot: int, at: Vector2, col: Color) -> void:
	var mask := Relics.icon(id, true)
	if mask:
		_draw_icon(mask, rot, at, _box(id, rot), 1.0, col)
		return
	for c in Backpack.turned(id, rot):
		draw_rect(Rect2(at + Vector2(c * _cell), Vector2(_cell, _cell)), col)


## Relic art is 10 px per cell, turned around the middle of its cells.
func _draw_icon(tex: Texture2D, rot: int, at: Vector2, box: Vector2, lift: float, col: Color) -> void:
	var px := _cell / 10.0
	draw_set_transform(at + (box - Vector2.ONE * px) / 2.0, rot * PI / 2.0, Vector2.ONE * px * lift)
	draw_texture(tex, -tex.get_size() / 2.0, col)
	draw_set_transform(Vector2.ZERO)


## 1 px line along the outer edges of a group of cells.
func _outline(cells: Array[Vector2i], at: Vector2, col: Color) -> void:
	for c in cells:
		var p := at + Vector2(c * _cell)
		if not cells.has(c + Vector2i.UP):
			draw_rect(Rect2(p, Vector2(_cell, 1)), col)
		if not cells.has(c + Vector2i.DOWN):
			draw_rect(Rect2(p + Vector2(0, _cell - 1), Vector2(_cell, 1)), col)
		if not cells.has(c + Vector2i.LEFT):
			draw_rect(Rect2(p, Vector2(1, _cell)), col)
		if not cells.has(c + Vector2i.RIGHT):
			draw_rect(Rect2(p + Vector2(_cell - 1, 0), Vector2(1, _cell)), col)


# --- tooltip -------------------------------------------------------------------
# Layout of the owner's reference: "RARITY • RELIC", the name, a framed box of bullet
# lines with the numbers in accent, a divider, the flavor line. Placed next to `near`
# (local rect of the relic), kept inside the screen.

func _set_tip(id: StringName, live: Dictionary, near: Rect2) -> void:
	_tip.visible = id != &""
	if id == &"":
		return
	_tip_info = Relics.info(id, live)
	# Measure the actual font instead of packing 16px text into fixed 10px rows.
	ROW = ceili(_tip_font().get_height(16)) + 3
	CAP = ceili(_tip_font().get_ascent(16))
	_tip_name = _wrap(_tip_info.name, TIP_W - 2 * PAD)
	_tip_rows.clear()
	for line in _tip_info.lines:
		var rows := _wrap(line, TIP_W - 2 * PAD - 15)
		for i in rows.size():
			_tip_rows.append([rows[i], i == 0])
	_tip_flavor = _wrap(_tip_info.text, TIP_W - 2 * PAD)
	_tip.size = Vector2(TIP_W, _divider_y() + 6 + _tip_flavor.size() * ROW + PAD)

	# Top-level card: place in UI pixels, independent of the parent room's scale.
	near = get_global_transform() * near
	var screen := get_viewport_rect()
	var x := near.end.x + 3
	if x + _tip.size.x > screen.end.x:
		x = near.position.x - 3 - _tip.size.x
	_tip.position = Vector2(clampf(x, screen.position.x, screen.end.x - _tip.size.x),
		clampf(near.position.y, screen.position.y, screen.end.y - _tip.size.y)).floor()
	_tip.queue_redraw()


func _box_y() -> int:
	return PAD + (1 + _tip_name.size()) * ROW + 6


func _divider_y() -> int:
	return _box_y() + (1 + _tip_rows.size()) * ROW + 18


func _draw_tip() -> void:
	var w := _tip.size.x
	var h := _tip.size.y
	_tip.draw_rect(Rect2(1, 0, w - 2, h), COL_CELL)
	_tip.draw_rect(Rect2(0, 1, w, h - 2), COL_CELL)
	_frame(Rect2(0, 0, w, h), COL_FRAME)

	var rarity: StringName = _tip_info.rarity
	var x := _text(Vector2(PAD, PAD), String(rarity).to_upper(), Relics.RARITY_COLOR.get(rarity, COL_DIM))
	x = _text(Vector2(x, PAD), " • ", COL_DIM)
	_text(Vector2(x, PAD), "RELIC", COL_FRAME)
	for i in _tip_name.size():
		_text(Vector2(PAD, PAD + (i + 1) * ROW), _tip_name[i], COL_LIT)

	var box := Rect2(PAD, _box_y(), w - 2 * PAD, (1 + _tip_rows.size()) * ROW + 12)
	var label := String(_tip_info.on).to_upper()
	_frame(box, COL_DIM)
	_text(Vector2(PAD + 5, box.position.y + 4), label, COL_DIM)
	for i in _tip_rows.size():
		var top := box.position.y + 8 + (i + 1) * ROW
		if _tip_rows[i][1]:
			_text(Vector2(PAD + 4, top), "•", COL_DIM)
		_rich(Vector2(PAD + 11, top), _tip_rows[i][0], COL_TEXT)

	var line := _divider_y()
	_tip.draw_rect(Rect2(PAD, line, w - 2 * PAD, 1), Color(COL_DIM, 0.5))
	for i in _tip_flavor.size():
		_text(Vector2(PAD, line + 6 + i * ROW), _tip_flavor[i], COL_DIM)


## Over the CRT the tooltip reads like the HUD's small text (the CRT's bitmap font is 8 px only).
func _tip_font() -> Font:
	return HudStyle.TALK_FONT if compact else get_theme_default_font()


## Draws `s` with its caps' top-left at `at`, returns where the text ends.
func _text(at: Vector2, s: String, col: Color) -> float:
	var font := _tip_font()
	_tip.draw_string(font, at + Vector2(0, CAP), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	return at.x + font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


## A row where the {braced} parts are accent colored.
func _rich(at: Vector2, row: String, col: Color) -> void:
	var accent := false
	for part in row.replace("}", "{").split("{"):
		at.x = _text(at, part, COL_LIT if accent else col)
		accent = not accent


func _wrap(line: String, width: float) -> PackedStringArray:
	var font := _tip_font()
	var rows := PackedStringArray()
	var row := ""
	for word in line.split(" "):
		var next := word if row == "" else row + " " + word
		var w := font.get_string_size(next.replace("{", "").replace("}", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		if row != "" and w > width:
			rows.append(row)
			row = word
		else:
			row = next
	rows.append(row)
	return rows


## 1 px frame with cut corners; `gap` (from x, to x) stays open in the top line.
func _frame(r: Rect2, col: Color, gap := Vector2.ZERO) -> void:
	var left := r.position.x + 1
	var right := r.end.x - 1
	if gap == Vector2.ZERO:
		_tip.draw_rect(Rect2(left, r.position.y, right - left, 1), col)
	else:
		_tip.draw_rect(Rect2(left, r.position.y, gap.x - left, 1), col)
		_tip.draw_rect(Rect2(gap.y, r.position.y, right - gap.y, 1), col)
	_tip.draw_rect(Rect2(left, r.end.y - 1, right - left, 1), col)
	_tip.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), col)
	_tip.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), col)
