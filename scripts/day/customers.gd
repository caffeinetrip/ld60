class_name Customers extends Node2D

signal at_counter(cat: Cat)
signal gone(cat: Cat)

const OUTSIDE_WEIGHT := Tune.CAT_OUTSIDE_WEIGHT
const WANDER_WEIGHT := Tune.CAT_WANDER_WEIGHT

@export var queue_path := PackedVector2Array()
@export var spacing := 13.0

var _cafe: Node2D
var _line: Array[Cat] = []
var _cats: Dictionary[Cat, Dictionary] = {}
var _spots := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _counter: Cat


func setup(cafe: Node2D) -> void:
	_cafe = cafe
	if queue_path.is_empty():
		queue_path = PackedVector2Array([cafe.marker("BarOrder"), Vector2(194, 159), Vector2(116, 159), Vector2(66, 148)])
	_spots.clear()
	if spacing <= 0.0 or queue_path.is_empty():
		return
	_spots.append(queue_path[0])
	var distance := spacing
	for i in range(1, queue_path.size()):
		var start := queue_path[i - 1]
		var length := start.distance_to(queue_path[i])
		while distance <= length:
			_spots.append(start.move_toward(queue_path[i], distance))
			distance += spacing
		distance -= length


func spawn(kind := &"normal") -> Cat:
	if not is_instance_valid(_cafe) or waiting() >= max_queue():
		return null
	var cat := Cat.new()
	cat.kind = kind
	_cafe.get_node("Props").add_child(cat)
	cat.global_position = _cafe.marker("EntranceOutside")
	# Burst spawns wait in a spaced line outside the door.
	for other: Cat in _cats:
		if cat.global_position.distance_to(other.global_position) < spacing:
			cat.global_position.x = minf(cat.global_position.x, other.global_position.x - spacing)
	_line.append(cat)
	_cats[cat] = {phase = &"enter", route = PackedVector2Array([_cafe.marker("EntranceOutside"), _cafe.marker("EntranceInside")]), time = 0.0, seat = null}
	cat.arrived.connect(_arrived.bind(cat))
	Feel.play(&"cat/enter", cat.global_position)
	_next(cat)
	return cat


func front() -> Cat:
	return _counter


func waiting() -> int:
	return _line.size()


func max_queue() -> int:
	return _spots.size()


func release_front(mood: Cat.Mood) -> void:
	if not is_instance_valid(_counter):
		return
	var cat := _counter
	_counter = null
	_line.erase(cat)
	match mood:
		Cat.Mood.HAPPY:
			Feel.play(&"cat/happy", cat.global_position)
			var tween := cat.create_tween()
			tween.tween_property(cat, "hop", 3.0, 0.12)
			tween.tween_property(cat, "hop", 0.0, 0.12)
		Cat.Mood.SAD:
			cat.say("...")
		Cat.Mood.ANGRY:
			cat.say("Hmph!")
			Feel.play(&"cat/angry", cat.global_position)
	var roll := _rng.randf()
	var seats: Array = _cafe.free_seats()
	if roll < OUTSIDE_WEIGHT:
		_leave(cat)
	elif roll < OUTSIDE_WEIGHT + WANDER_WEIGHT or seats.is_empty():
		_cats[cat].phase = &"wander"
		_cats[cat].time = _rng.randf_range(Tune.CAT_WANDER_TIME.x, Tune.CAT_WANDER_TIME.y)
		_route(cat, _wander_point())
	else:
		var seat: Marker2D = seats[_rng.randi_range(0, seats.size() - 1)]
		seat.set_meta("taken", true)
		_cats[cat].seat = seat
		_cats[cat].phase = &"seat"
		_cats[cat].time = _rng.randf_range(Tune.CAT_SEAT_TIME.x, Tune.CAT_SEAT_TIME.y)
		_route(cat, seat.global_position)
	_advance()


func send_home() -> void:
	_counter = null
	var line := _line.duplicate()
	_line.clear()
	for cat: Cat in line:
		cat.say("...")
		_leave(cat)


func _advance() -> void:
	for cat: Cat in _line:
		if _cats[cat].phase == &"queue":
			_queue(cat)


func _queue(cat: Cat) -> void:
	var index := _line.find(cat)
	if index < 0:
		return
	_cats[cat].phase = &"queue"
	_route(cat, _spots[index])


func _route(cat: Cat, target: Vector2) -> void:
	_cats[cat].route = _path(cat.global_position, target)
	_next(cat)


func _next(cat: Cat) -> void:
	var route: PackedVector2Array = _cats[cat].route
	if not route.is_empty():
		var next := route[0]
		route.remove_at(0)
		_cats[cat].route = route
		cat.walk_to(next)
	else:
		cat.walking = false
		_arrived(cat)


func _arrived(cat: Cat) -> void:
	var state: Dictionary = _cats[cat]
	if not state.route.is_empty():
		_next(cat)
		return
	match state.phase:
		&"enter":
			_queue(cat)
		&"queue":
			if not _line.is_empty() and _line[0] == cat and _counter != cat:
				_counter = cat
				Feel.play(&"cat/meow", cat.global_position)
				at_counter.emit(cat)
		&"exit":
			_free_seat(cat)
			_cats.erase(cat)
			cat.queue_free()
			gone.emit(cat)
		&"seat":
			state.phase = &"sit"
			var seat: Marker2D = state.seat
			cat.facing = -1.0 if seat.get_meta("facing", "right") == "left" else 1.0


func _process(delta: float) -> void:
	for cat: Cat in _cats.keys():
		var state: Dictionary = _cats[cat]
		cat.held = false
		if state.phase == &"enter" or state.phase == &"queue":
			var index := _line.find(cat)
			if index > 0:
				var leader := _line[index - 1]
				var next := cat.global_position.move_toward(cat._target, Tune.CAT_SPEED * delta)
				cat.held = next.distance_to(leader.global_position) < spacing - 1.0
		if state.phase == &"wander" or state.phase == &"sit":
			state.time -= delta
			if state.time <= 0.0:
				_leave(cat)
			elif state.phase == &"wander" and not cat.walking:
				_route(cat, _wander_point())


func _leave(cat: Cat) -> void:
	_free_seat(cat)
	_cats[cat].phase = &"exit"
	cat.held = false
	var route := _path(cat.global_position, _cafe.marker("EntranceInside"))
	route.append(_cafe.marker("EntranceOutside"))
	_cats[cat].route = route
	_next(cat)


func _free_seat(cat: Cat) -> void:
	var seat: Marker2D = _cats[cat].seat
	if is_instance_valid(seat):
		seat.set_meta("taken", false)
	_cats[cat].seat = null


func _exit_tree() -> void:
	for cat: Cat in _cats:
		_free_seat(cat)
		if is_instance_valid(cat):
			cat.queue_free()


func _obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	# Footprints include the future tables, leaving the same aisles after upgrades.
	for table: Node2D in _cafe.tables():
		var size := Vector2(40, 18) if table.name == &"Table1" else Vector2(32, 16)
		out.append(Rect2(table.global_position - Vector2(size.x / 2.0, 12), size))
	return out


func _wander_point() -> Vector2:
	for attempt in 100:
		var point := Vector2(_rng.randf_range(40, 140), _rng.randf_range(150, 176))
		var clear := true
		for box: Rect2 in _obstacles():
			if box.grow(5).has_point(point):
				clear = false
		if clear:
			return point
	return Vector2(60, 160)


func _path(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var graph := AStar2D.new()
	var points := PackedVector2Array([start, finish])
	var boxes := _obstacles()
	for box: Rect2 in boxes:
		var margin := box.grow(1.0)
		points.append_array(PackedVector2Array([margin.position, Vector2(margin.end.x, margin.position.y), margin.end, Vector2(margin.position.x, margin.end.y)]))
	for i in points.size():
		graph.add_point(i, points[i])
	for i in points.size():
		for j in range(i + 1, points.size()):
			var clear := true
			for box: Rect2 in boxes:
				if _crosses(points[i], points[j], box):
					clear = false
					break
			if clear:
				graph.connect_points(i, j)
	var path := graph.get_point_path(0, 1)
	if not path.is_empty():
		path.remove_at(0)
	return path


func _crosses(a: Vector2, b: Vector2, box: Rect2) -> bool:
	# Slab intersection keeps both diagonal and axis-aligned routes outside tables.
	var low := 0.0
	var high := 1.0
	for axis in 2:
		var d := b[axis] - a[axis]
		if is_zero_approx(d):
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return false
		else:
			var first := (box.position[axis] - a[axis]) / d
			var last := (box.end[axis] - a[axis]) / d
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
	return low <= high
