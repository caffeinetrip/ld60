extends Node2D
## The cafe room.
##
## Tables: Table1 (main, centre) and Table2 (below) are open at start; Table3 and Table4
## are hidden upgrade slots. Every table has Seats/SeatN markers with meta "facing".
## Markers/: EntranceOutside, EntranceInside, BarOrder, StaffDoor.
## Lighting/ holds the day/night light (see cafe_lighting.gd). Debug: N toggles night.

signal table_unlocked(table: Node2D)

const ENTRANCE_CELL := Vector2i(2, 4)

@export var entrance_closed_atlas := Vector2i.ZERO
@export var entrance_open_atlas := Vector2i.ZERO

@onready var _wall_decor: TileMapLayer = $WallDecor
@onready var _door_glow: TileMapLayer = $DoorGlow
@onready var _door_light: PointLight2D = $Lighting/DoorLight
@onready var _lighting: Node = $Lighting
@onready var _props: Node2D = $Props
@onready var _markers: Node2D = $Markers


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_N:
		_lighting.call("set_night", 0.0 if _lighting.get("night") > 0.5 else 1.0)


func tables() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child in _props.get_children():
		if child.name.begins_with("Table"):
			out.append(child)
	return out


func unlock_table(index: int) -> bool:
	var table := _props.get_node_or_null("Table%d" % index) as Node2D
	if table == null or table.visible:
		return false
	table.visible = true
	table_unlocked.emit(table)
	return true


## Seats of the open tables that nobody has taken (meta "taken" set by the game).
func free_seats() -> Array[Marker2D]:
	var out: Array[Marker2D] = []
	for table in tables():
		if not table.visible:
			continue
		for seat in table.get_node("Seats").get_children():
			if not seat.get_meta("taken", false):
				out.append(seat)
	return out


func set_entrance_open(open: bool) -> void:
	_wall_decor.set_cell(ENTRANCE_CELL, 0, entrance_open_atlas if open else entrance_closed_atlas)
	if open:
		_door_glow.set_cell(ENTRANCE_CELL, 0, entrance_open_atlas)
	else:
		_door_glow.erase_cell(ENTRANCE_CELL)
	_door_light.visible = open


func marker(marker_name: String) -> Vector2:
	return (_markers.get_node(marker_name) as Marker2D).global_position
