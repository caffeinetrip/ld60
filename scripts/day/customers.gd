class_name Customers extends Node2D

signal at_counter(cat: Cat)
signal gone(cat: Cat)

@export var queue_path := PackedVector2Array()
@export var spacing := 20.0
@export var outside_places := 10

var _cafe: Node2D
var _line: Array[Cat] = []
var _cats: Dictionary[Cat, Dictionary] = {}
var _spots := PackedVector2Array()
var _lane := PackedVector2Array()
var _distances := PackedFloat32Array()
var _lane_length := 0.0
var _counter: Cat
var day: Node
var _beg_in := 0.0


func setup(cafe: Node2D) -> void:
	_cafe = cafe
	if queue_path.is_empty():
		# The line follows the shortest route from the door to the counter.
		# Overflow waits outside instead of making every visitor tour the room.
		queue_path = _path(cafe.marker("BarOrder"), cafe.marker("EntranceInside"))
		queue_path.insert(0, cafe.marker("BarOrder"))
	_spots.clear()
	_lane.clear()
	_distances.clear()
	_lane_length = 0.0
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
	_lane = queue_path.duplicate()
	# Append the approach in reverse: lane distance is zero at the counter.
	var inside: Vector2 = cafe.marker("EntranceInside")
	var tail := queue_path[queue_path.size() - 1]
	if not tail.is_equal_approx(inside):
		_lane.append_array(_path(tail, inside))
	_lane.append(cafe.marker("EntranceOutside"))
	_distances.append(0.0)
	for i in range(1, _lane.size()):
		_lane_length += _lane[i - 1].distance_to(_lane[i])
		_distances.append(_lane_length)


## `friend` = a pager friend: both it and the cat it came with pay less.
func spawn(kind := &"normal", friend := false) -> Cat:
	if not is_instance_valid(_cafe) or waiting() >= max_queue():
		return null
	var cat := Cat.new()
	cat.kind = kind
	cat.day = day
	_cafe.get_node("Props").add_child(cat)
	# Starts in the doorway, unseen; burst spawns wait there (held) until the one ahead steps out.
	cat.global_position = _cafe.marker("EntranceOutside")
	cat.self_modulate.a = 0.0
	var distance := _lane_length
	if not _line.is_empty():
		distance = maxf(distance, _cats[_line.back()].distance + spacing)
	_line.append(cat)
	cat.queue_managed = true
	_cats[cat] = {phase = &"queue", distance = distance, route = PackedVector2Array(), friend = friend}
	cat.arrived.connect(_arrived.bind(cat))
	Feel.play(&"cat/enter", cat.global_position)
	return cat


func front() -> Cat:
	return _counter


func is_friend(cat: Cat) -> bool:
	return _cats.has(cat) and _cats[cat].friend


func waiting() -> int:
	return _line.size()


func line() -> Array[Cat]:
	return _line


func max_queue() -> int:
	return _spots.size() + maxi(0, outside_places) if not _spots.is_empty() else 0


func release_front(mood: Cat.Mood) -> void:
	if not is_instance_valid(_counter):
		return
	var cat := _counter
	_counter = null
	_line.erase(cat)
	match mood:
		Cat.Mood.HAPPY:
			cat.show_mood(mood)
			Feel.play(&"cat/dog_happy.wav" if cat.look == &"pup" else &"cat/happy", cat.global_position)
			var tween := cat.create_tween()
			tween.tween_property(cat, "hop", 3.0, 0.12)
			tween.tween_property(cat, "hop", 0.0, 0.12)
		Cat.Mood.SAD:
			cat.show_mood(mood)
			cat.say("...")
		Cat.Mood.ANGRY:
			cat.show_mood(mood)
			cat.say("Hmph!")
			if cat.look != &"pup":		# dogs have no angry voice
				Feel.play(&"cat/angry", cat.global_position)
	_leave(cat)


func clear_day() -> void:
	_counter = null
	_line.clear()
	_beg_in = 0.0
	for cat: Cat in _cats:
		cat.hide()
		cat.set_process(false)
		cat.queue_free()
	_cats.clear()


func send_home() -> void:
	_counter = null
	var line := _line.duplicate()
	_line.clear()
	for cat: Cat in line:
		cat.say("...")
		_leave(cat)


func _move_queue(delta: float) -> void:
	# A shared distance prevents overtaking, shortcuts and jams around bends.
	# Excess distance holds burst arrivals unseen outside until there is space.
	for cat: Cat in _line.duplicate():
		var index := _line.find(cat)
		if index < 0 or not _cats.has(cat):
			continue
		var state: Dictionary = _cats[cat]
		var target := index * spacing
		if index > 0:
			target = maxf(target, _cats[_line[index - 1]].distance + spacing)
		state.distance = move_toward(state.distance, target, Tune.CAT_SPEED * delta)
		cat.follow_queue(_lane_position(state.distance), delta)
		if index == 0 and is_zero_approx(state.distance) and _counter != cat:
			_arrived(cat)


func _lane_position(distance: float) -> Vector2:
	for i in range(1, _lane.size()):
		if distance <= _distances[i]:
			return _lane[i - 1].move_toward(_lane[i], maxf(0.0, distance - _distances[i - 1]))
	return _lane[_lane.size() - 1]


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
	if not _cats.has(cat):
		return
	var state: Dictionary = _cats[cat]
	if not state.route.is_empty():
		_next(cat)
		return
	match state.phase:
		&"queue":
			if not _line.is_empty() and _line[0] == cat and _counter != cat:
				_counter = cat
				Feel.play(&"cat/dog_meow.wav" if cat.look == &"pup" else &"cat/meow", cat.global_position)
				at_counter.emit(cat)
		&"exit":
			_cats.erase(cat)
			cat.queue_free()
			gone.emit(cat)


func _process(delta: float) -> void:
	if not is_instance_valid(_cafe):
		return
	_move_queue(delta)
	if is_instance_valid(_counter) and _counter.kind == &"homeless":
		_beg_in -= delta
		if _beg_in <= 0.0:
			_counter.say("Spare a drink?")
			_beg_in = Tune.HOMELESS_BEG_TIME
	else:
		_beg_in = 0.0
	var door: Vector2 = _cafe.marker("EntranceOutside")
	for cat: Cat in _cats.keys():
		# Near the doorway a cat comes out of (or goes into) the dark.
		var lit := smoothstep(0.0, Tune.CAT_DOOR_FADE, cat.global_position.distance_to(door))
		var shade := lerpf(0.3, 1.0, lit)
		cat.self_modulate = Color(shade, shade, shade, lit)


func _leave(cat: Cat) -> void:
	var served: bool = _cats[cat].phase == &"queue" and is_zero_approx(_cats[cat].distance)
	_cats[cat].phase = &"exit"
	cat.queue_managed = false
	cat.held = false
	# An arrival still outside can leave without first walking into the room.
	if cat.global_position.is_equal_approx(_cafe.marker("EntranceOutside")):
		_cats[cat].route = PackedVector2Array()
		_next(cat)
		return
	var inside: Vector2 = _cafe.marker("EntranceInside")
	var route := PackedVector2Array()
	if served:
		# Step beside the line and head for the door without walking through it.
		var aside := cat.global_position + Vector2(-12, 14)
		route.append_array(_path(cat.global_position, aside))
		route.append_array(_path(aside, inside + Vector2(0, 14)))
	else:
		route = _path(cat.global_position, inside)
	route.append(_cafe.marker("EntranceOutside"))
	_cats[cat].route = route
	_next(cat)


func _exit_tree() -> void:
	for cat: Cat in _cats:
		if is_instance_valid(cat):
			cat.queue_free()


func _obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	# Footprints include the future tables, leaving the same aisles after upgrades.
	for table: Node2D in _cafe.tables():
		var size := Vector2(40, 18) if table.name == &"Table1" else Vector2(32, 16)
		out.append(Rect2(table.global_position - Vector2(size.x / 2.0, 12), size))
	return out


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


func start_day(controller: Node) -> void:
	day = controller


func has_homeless() -> bool:
	for cat: Cat in _line:
		if cat.kind == &"homeless":
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(day) or not day.is_active():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for cat: Cat in _line:
			if cat.kind == &"homeless" and Rect2(-9, -Cat.TOP, 18, Cat.TOP + 1).has_point(cat.get_global_transform_with_canvas().affine_inverse() * event.position):
				get_viewport().set_input_as_handled()
				day.kick(cat)
				return


func kick_result(cat: Cat, tier: StringName) -> void:
	if not is_instance_valid(cat) or not _line.has(cat):
		return
	if tier != &"perfect" and tier != &"good":
		Feel.play(StringName("homeless/" + String(tier)), cat.global_position)
		cat.say("Hey!" if tier == &"meh" else "Hmph")
		if tier == &"meh":
			var tween := cat.create_tween()
			tween.tween_property(cat, "position:x", cat.position.x - Tune.HOMELESS_STUMBLE, 0.12)
			tween.tween_property(cat, "position:x", cat.position.x, 0.12)
		return
	_kick_out(cat, tier)


## A good kick: blood, the loot to the till, out the door.
func _kick_out(cat: Cat, tier: StringName) -> void:
	_line.erase(cat)
	if _counter == cat:
		_counter = null
	cat.walking = false
	cat.queue_managed = false
	if is_instance_valid(cat._bubble):
		cat._bubble.hide()
	_cats[cat].phase = &"kicked"
	_cats[cat].route = PackedVector2Array()
	Feel.play(&"homeless/kick", cat.global_position)
	Feel.text("Out!", cat.global_position)
	var blood := preload("res://scripts/feel/blood_burst.gd").new()
	blood.position = cat.global_position + Vector2(0, -12)
	blood.dir = Vector2(-0.6, -1.0)		# up and back, the way the boot sends it
	cat.get_parent().add_child(blood)
	# it drops what it had on it: bills fly to the till with the coin sound
	var register := _cafe.get_node_or_null(^"Props/Counter/Register1") as Node2D
	Feel.gold_gain(Game.reward({money = Tune.HOMELESS_LOOT_PERFECT if tier == &"perfect" else Tune.HOMELESS_LOOT}), cat.global_position,
		register.to_global(Vector2(4, -3)) if register else Vector2.INF)
	Feel.zoom(0.03)
	# straight out through the door: it fades in the doorway's dark and is gone
	var start := cat.global_position
	var finish: Vector2 = _cafe.marker("EntranceOutside")
	var tween := cat.create_tween()
	tween.tween_method(func(t: float):
		cat.global_position = start.lerp(finish, t) + Vector2(0, -sin(t * PI) * Tune.HOMELESS_KICK_HEIGHT)
		cat.rotation = -t * TAU * Tune.HOMELESS_KICK_SPINS, 0.0, 1.0, Tune.HOMELESS_KICK_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_cats.erase(cat)
		cat.queue_free()
		gone.emit(cat))
