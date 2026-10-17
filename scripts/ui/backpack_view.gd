class_name BackpackView
extends Control
## Placeholder relic grid for the night panel: LMB picks up / drops, RMB or wheel turns.
## Goes away with the redesign; the rules live in Backpack.

const STEP := 17			# 16 px cell + 1 px gap
const POCKET := Rect2(108, 0, 196, 68)
const COL_CELL := Color("1a1220")
const COL_FRAME := Color("c9a24a")
const COL_STAR := Color("9c8a99")
const COL_LIT := Color("ffd34d")

var _held := {}			# {id, rot, from}, from = the placed item or {} for the pocket
var _info := Label.new()


func _ready() -> void:
	custom_minimum_size = Vector2(304, 124)
	_info.position = Vector2(0, 72)
	_info.size = Vector2(304, 52)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	Game.backpack.changed.connect(_refresh)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_put_back()


func _bp() -> Backpack:
	return Game.backpack


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		accept_event()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_click(mb.position)
		elif not _held.is_empty():
			_held.rot = posmod(_held.rot + (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1), 4)
			Feel.play(&"relic/rotate")
	if event is InputEventMouseMotion:
		_refresh()


func _click(at: Vector2) -> void:
	var cell := _cell_at(at)
	if _held.is_empty():
		var item := _bp().item_at(cell)
		if not item.is_empty():
			_bp().take(item)
			_hold(item.id, item.rot, item)
		elif _pocket_index(at) >= 0:
			_hold(_bp().take_from_pocket(_pocket_index(at)), 0, {})
		return
	var lit := _bp().lit_total()
	if not _bp().place(_held.id, cell, _held.rot).is_empty():
		Feel.play(&"relic/drop")
		if _bp().lit_total() > lit:
			Feel.play(&"relic/star")
		_held = {}
	elif POCKET.has_point(at):
		Feel.play(&"relic/drop")
		var id: StringName = _held.id
		_held = {}
		_bp().add_to_pocket(id)
	else:
		Feel.play(&"ui/error")


func _hold(id: StringName, rot: int, from: Dictionary) -> void:
	_held = {id = id, rot = rot, from = from}
	Feel.play(&"relic/pick")
	_refresh()


## Panel closed mid-drag: the relic goes back where it came from.
func _put_back() -> void:
	if _held.is_empty():
		return
	var from: Dictionary = _held.from
	var id: StringName = _held.id
	_held = {}
	if from.is_empty() or _bp().place(id, from.cell, from.rot).is_empty():
		_bp().add_to_pocket(id)


func _cell_at(at: Vector2) -> Vector2i:
	return Vector2i((at / STEP).floor())


func _pocket_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x := POCKET.position.x + 3
	var y := POCKET.position.y + 3
	var row := 0.0
	for id in _bp().pocket:
		var box := _bounds(Backpack.turned(id, 0)[0]) * STEP
		if x + box.x > POCKET.end.x:
			x = POCKET.position.x + 3
			y += row + 3
			row = 0.0
		out.append(Rect2(x, y, box.x, box.y))
		x += box.x + 3
		row = maxf(row, box.y)
	return out


func _pocket_index(at: Vector2) -> int:
	var rects := _pocket_rects()
	for i in rects.size():
		if rects[i].has_point(at):
			return i
	return -1


func _bounds(cells: Array[Vector2i]) -> Vector2:
	var high := Vector2i.ZERO
	for c in cells:
		high = high.max(c)
	return Vector2(high + Vector2i.ONE)


func _refresh() -> void:
	var at := get_local_mouse_position()
	var id: StringName = _held.get("id", &"")
	if id == &"":
		var item := _bp().item_at(_cell_at(at))
		var i := _pocket_index(at)
		id = item.id if not item.is_empty() else (_bp().pocket[i] if i >= 0 else &"")
	if id != &"":
		_info.text = Relics.info(id)
	elif _bp().items.is_empty() and _bp().pocket.is_empty():
		_info.text = "No relics yet. Special cats bring them."
	else:
		var stats := _bp().stats()
		_info.text = ("Bonuses: " + Relics.describe(stats)) if not stats.is_empty() else "Place relics on the grid."
	queue_redraw()


func _draw() -> void:
	for y in Backpack.H:
		for x in Backpack.W:
			draw_rect(Rect2(x * STEP, y * STEP, 16, 16), COL_CELL)
	for item in _bp().items:
		_draw_relic(item.id, item.rot, Vector2(item.cell * STEP), 1.0)
		var tag: StringName = Relics.get_def(item.id).get("star_tag", &"")
		for c in _bp().star_cells_of(item):
			if c.x < 0 or c.y < 0 or c.x >= Backpack.W or c.y >= Backpack.H:
				continue
			var other := _bp().item_at(c)
			var lit: bool = not other.is_empty() and (tag == &"" or Relics.get_def(other.id).tags.has(tag))
			_draw_star(Vector2(c * STEP) + Vector2(8, 8), COL_LIT if lit else COL_STAR)

	draw_rect(POCKET.grow(-0.5), COL_FRAME, false, 1.0)
	var rects := _pocket_rects()
	for i in rects.size():
		_draw_relic(_bp().pocket[i], 0, rects[i].position, 1.0)

	if not _held.is_empty():
		var at := get_local_mouse_position()
		var cell := _cell_at(at)
		var on_grid := cell.x >= 0 and cell.y >= 0 and cell.x < Backpack.W and cell.y < Backpack.H
		if on_grid:
			var ok := _bp().can_place(_held.id, cell, _held.rot)
			for c in Backpack.turned(_held.id, _held.rot)[0]:
				draw_rect(Rect2(Vector2(cell + c) * STEP, Vector2(16, 16)), Color("7fd17f" if ok else "e05a5a", 0.5))
		_draw_relic(_held.id, _held.rot, (at - Vector2(8, 8)).floor(), 0.8)


func _draw_relic(id: StringName, rot: int, at: Vector2, alpha: float) -> void:
	var def := Relics.get_def(id)
	var col: Color = Relics.RARITY_COLOR.get(def.rarity, COL_STAR)
	var cells: Array[Vector2i] = Backpack.turned(id, rot)[0]
	for c in cells:
		var r := Rect2(at + Vector2(c * STEP), Vector2(16, 16))
		draw_rect(r, Color(col, alpha))
		draw_rect(r.grow(-0.5), Color(col.lightened(0.4), alpha), false, 1.0)
	draw_string(get_theme_default_font(), at + Vector2(cells[0] * STEP) + Vector2(5, 12),
		def.name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(COL_CELL, alpha))


func _draw_star(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c.x - 1, c.y, 3, 1), col)
	draw_rect(Rect2(c.x, c.y - 1, 1, 3), col)
