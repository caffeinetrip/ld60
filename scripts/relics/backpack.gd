class_name Backpack
extends RefCounted
## Relic grid like Backpack Battles. Relics from special cats land in the pocket; at
## night the player places them so as many stars as possible light up.
## stats() feeds Game.set_mods(&"relics", ...) on every change.

signal changed

const W := 6
const H := 4

var items: Array[Dictionary] = []	# {id, cell: Vector2i, rot: 0..3 clockwise}
var pocket: Array[StringName] = []


func clear() -> void:
	items.clear()
	pocket.clear()
	changed.emit()


func add_to_pocket(id: StringName) -> void:
	pocket.append(id)
	changed.emit()


func take_from_pocket(index: int) -> StringName:
	var id: StringName = pocket.pop_at(index)
	changed.emit()
	return id


func placed() -> Array[StringName]:
	var out: Array[StringName] = []
	for item in items:
		out.append(item.id)
	return out


func can_place(id: StringName, cell: Vector2i, rot: int) -> bool:
	for c in turned(id, rot)[0]:
		var at: Vector2i = cell + c
		if at.x < 0 or at.y < 0 or at.x >= W or at.y >= H or not item_at(at).is_empty():
			return false
	return true


func place(id: StringName, cell: Vector2i, rot: int) -> Dictionary:
	if not can_place(id, cell, rot):
		return {}
	var item := {id = id, cell = cell, rot = posmod(rot, 4)}
	items.append(item)
	changed.emit()
	return item


## Lifts a placed relic off the grid (to move it or pocket it).
func take(item: Dictionary) -> void:
	items.erase(item)
	changed.emit()


func item_at(cell: Vector2i) -> Dictionary:
	for item in items:
		if cells_of(item).has(cell):
			return item
	return {}


func cells_of(item: Dictionary) -> Array[Vector2i]:
	return _offset(turned(item.id, item.rot)[0], item.cell)


func star_cells_of(item: Dictionary) -> Array[Vector2i]:
	return _offset(turned(item.id, item.rot)[1], item.cell)


func lit_stars(item: Dictionary) -> int:
	var tag: StringName = Relics.get_def(item.id).get("star_tag", &"")
	var n := 0
	for cell in star_cells_of(item):
		var other := item_at(cell)
		if not other.is_empty() and (tag == &"" or Relics.get_def(other.id).tags.has(tag)):
			n += 1
	return n


func lit_total() -> int:
	var n := 0
	for item in items:
		n += lit_stars(item)
	return n


func stats() -> Dictionary:
	var out := {}
	for item in items:
		var def := Relics.get_def(item.id)
		_add(out, def.get("mods", {}), 1)
		_add(out, def.get("star_mods", {}), lit_stars(item))
	return out


## [shape, stars] of a relic turned `rot` times clockwise, the shape's top-left at 0,0.
static func turned(id: StringName, rot: int) -> Array:
	var def := Relics.get_def(id)
	var shape: Array[Vector2i] = []
	var stars: Array[Vector2i] = []
	for c in def.shape:
		shape.append(_turn(c, rot))
	for c in def.stars:
		stars.append(_turn(c, rot))
	var low := shape[0]
	for c in shape:
		low = low.min(c)
	return [_offset(shape, -low), _offset(stars, -low)]


static func _turn(c: Vector2i, rot: int) -> Vector2i:
	for i in posmod(rot, 4):
		c = Vector2i(-c.y, c.x)
	return c


static func _offset(cells: Array[Vector2i], by: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c + by)
	return out


static func _add(to: Dictionary, mods: Dictionary, times: int) -> void:
	if times <= 0:
		return
	for key in mods:
		to[key] = to.get(key, 0.0) + mods[key] * times
