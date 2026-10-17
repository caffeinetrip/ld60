extends "res://tests/suite.gd"

var cafe: Node2D


func before_each() -> void:
	cafe = load("res://scenes/cafe.tscn").instantiate()
	tree.root.add_child(cafe)


func after_each() -> void:
	cafe.free()


func test_markers() -> void:
	eq(cafe.marker("EntranceOutside"), Vector2(30, 140), "outside")
	eq(cafe.marker("EntranceInside"), Vector2(66, 128), "inside")
	eq(cafe.marker("BarOrder"), Vector2(205, 142), "bar")
	check(cafe.marker("StaffDoor") != Vector2.ZERO, "staff door")


func test_tables() -> void:
	var seats: int = cafe.free_seats().size()
	check(seats > 0, "open tables have seats")
	check(not cafe.unlock_table(1), "table 1 is open already")
	check(cafe.unlock_table(3), "table 3 unlocks")
	check(not cafe.unlock_table(3), "once")
	check(cafe.free_seats().size() > seats, "more seats")
	seats = cafe.free_seats().size()
	cafe.free_seats()[0].set_meta("taken", true)
	eq(cafe.free_seats().size(), seats - 1, "taken seat is gone")


func test_entrance() -> void:
	cafe.set_entrance_open(true)
	check(cafe.get_node("Lighting/DoorLight").visible, "door light on")
	cafe.set_entrance_open(false)
	check(not cafe.get_node("Lighting/DoorLight").visible, "door light off")
