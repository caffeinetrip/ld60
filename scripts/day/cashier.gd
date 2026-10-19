class_name Cashier extends Node2D
## The hero behind the counter (sheet: tools/cashier_art.py). Lives in Cafe/Props, so the
## counter, the coffee machine and the till draw over his legs. `busy` is what he is doing
## (pouring = turned to the bottle shelf, focus = a minigame); show_mood() puts a face on top
## of it for a while.

enum Row { IDLE, BLINK, HAPPY, SAD, WOW, FOCUS, POUR }

const SHEET := preload("res://art/cashier.png")
const CELL := Vector2(32, 48)
const FOOT := 38.0		# the feet's row in a cell
const FRAME := {Row.IDLE: 0.3, Row.BLINK: 0.3, Row.HAPPY: 0.08, Row.SAD: 0.4, Row.WOW: 0.07, Row.FOCUS: 0.3, Row.POUR: 0.25}
const ONCE := [Row.HAPPY, Row.WOW]		# one hop, then the last frame holds

var busy := Row.IDLE
var _mood := Row.IDLE
var _mood_time := 0.0
var _mood_age := 0.0
var _age := 0.0
var _blink := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	material = preload("res://art/cashier_material.tres")
	_blink = _rng.randf_range(1.0, 3.0)


func show_mood(row: Row, seconds := 1.2) -> void:
	_mood = row
	_mood_time = seconds
	_mood_age = 0.0


## A minigame's tier on his face: glad on a hit, down on a miss, nothing for a meh.
func react(tier: StringName) -> void:
	if tier == &"perfect" or tier == &"good":
		show_mood(Row.HAPPY)
	elif tier == &"miss":
		show_mood(Row.SAD)


func row() -> Row:
	if _mood_time > 0.0:
		return _mood
	if busy != Row.IDLE:
		return busy
	return Row.BLINK if _blink < 0.0 else Row.IDLE


func _process(delta: float) -> void:
	_age += delta
	_mood_time -= delta
	_mood_age += delta
	_blink -= delta
	if _blink < -0.12:
		_blink = _rng.randf_range(1.5, 4.5)
	queue_redraw()


func _draw() -> void:
	var r := row()
	var t := _mood_age if _mood_time > 0.0 else _age
	var frame := int(t / FRAME[r])
	frame = mini(frame, 3) if r in ONCE else frame % 4
	draw_texture_rect_region(SHEET, Rect2(-CELL.x / 2.0, -FOOT, CELL.x, CELL.y), Rect2(Vector2(frame, r) * CELL, CELL))
