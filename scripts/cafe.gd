extends Node2D
## The cafe room.
##
## No tables for now (owner): tables(), free_seats() come back empty and unlock_table()
## refuses. A table would be Props/TableN with Seats/SeatN markers (meta "facing").
## Markers/: EntranceOutside, EntranceInside, BarOrder, StaffDoor.
## Lighting/ holds the day/night light (see cafe_lighting.gd). Debug: N toggles night.

signal table_unlocked(table: Node2D)

const ENTRANCE_CELL := Vector2i(2, 4)
const CASHIER_AT := Vector2(160, 99)		# feet behind the bar, between the machine and the till

@export var entrance_closed_atlas := Vector2i.ZERO
@export var entrance_open_atlas := Vector2i.ZERO

@onready var _wall_decor: TileMapLayer = $WallDecor
@onready var _lighting: Node = $Lighting
@onready var _props: Node2D = $Props
@onready var _markers: Node2D = $Markers


func _ready() -> void:
	$Lamps.position = Vector2(62, 30)	# the right half of the room, short of the windows; into the band
	# the lamps come with the first Street Sign (more cats) and stay for the run
	Game.mods_changed.connect(_show_lamps)
	Game.run_reset.connect(_show_lamps)
	_show_lamps()
	$Lamps.modulate = Color(2.4, 2.2, 1.9)	# near-black art, lit so it reads on the dark wall
	var fireflies := preload("res://scripts/cafe_fireflies.gd").new()
	fireflies.name = "Fireflies"
	add_child(fireflies)
	var cashier := Cashier.new()
	cashier.name = "Cashier"
	cashier.position = CASHIER_AT
	_props.add_child(cashier)


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


func set_story_day(day: int) -> void:
	var glass_material := $Glass.material as ShaderMaterial
	glass_material.set_shader_parameter("deadcat_texture", preload("res://art/deadcat.png"))
	glass_material.set_shader_parameter("deadcat_visible", day == 5)
	var grade_material := _lighting.grade.material as ShaderMaterial
	grade_material.set_shader_parameter("day_five_dread", 1.0 if day == 5 else 0.0)


func marker(marker_name: String) -> Vector2:
	return (_markers.get_node(marker_name) as Marker2D).global_position


func _show_lamps() -> void:
	$Lamps.visible = Game.level(&"cats") > 0
