extends "res://tests/suite.gd"

var cafe: Node2D
var customers: Customers


func before_each() -> void:
	cafe = load("res://scenes/cafe.tscn").instantiate()
	tree.root.add_child(cafe)
	customers = Customers.new()
	tree.root.add_child(customers)
	customers.setup(cafe)
	customers._rng.seed = 37


func after_each() -> void:
	drop_listeners()
	customers.free()
	cafe.free()


func test_twenty_cats() -> void:
	var counters := record(customers.at_counter)
	var departures := record(customers.gone)
	var spawned := 0
	var served := 0
	var elapsed := 0.0
	var spawn_in := 0.0
	var serve_in := 0.8
	var overlaps := false
	while elapsed < 120.0 and departures.size() < 20:
		var delta := tree.root.get_process_delta_time()
		elapsed += delta
		spawn_in -= delta
		if spawned < 20 and spawn_in <= 0.0 and customers.waiting() < customers.max_queue():
			var cat := customers.spawn(&"special" if spawned % 5 == 4 else &"normal")
			check(cat.get_parent() == cafe.get_node("Props"), "cats are y-sorted with furniture")
			spawned += 1
			spawn_in = 1.0
		if customers.front():
			serve_in -= delta
			if serve_in <= 0.0:
				customers.release_front(served % 3 as Cat.Mood)
				served += 1
				serve_in = 0.8
		for i in customers._line.size():
			for j in range(i + 1, customers._line.size()):
				if customers._line[i].global_position.distance_to(customers._line[j].global_position) < 10.0:
					overlaps = true
		await frames()
	eq(spawned, 20, "twenty enter")
	eq(served, 20, "twenty served")
	eq(counters.size(), 20, "counter fires once per cat")
	eq(departures.size(), 20, "twenty leave")
	check(not overlaps, "queue bodies stay separated")
	eq(customers.waiting(), 0, "line empties")
	eq(cafe.free_seats().size(), 5, "all seats freed")


func test_capacity_and_send_home() -> void:
	var counters := record(customers.at_counter)
	var departures := record(customers.gone)
	var capacity := customers.max_queue()
	for i in capacity:
		check(customers.spawn() != null, "room for each spot")
	check(customers.spawn() == null, "full queue refuses extra cat")
	eq(customers.waiting(), capacity, "walking cats count")
	check(customers.front() == null, "front waits for arrival")
	customers.send_home()
	eq(customers.waiting(), 0, "send_home clears immediately")
	check(await wait_for(func(): return departures.size() == capacity, 30.0), "all interrupted entrants leave")
	eq(counters.size(), 0, "sent home cats never order")


func test_polyline_and_furniture() -> void:
	customers.queue_path = PackedVector2Array([Vector2(205, 142), Vector2(205, 155), Vector2(166, 155)])
	customers.setup(cafe)
	eq(customers.max_queue(), 5, "polyline includes both ends")
	eq(customers._spots[2], Vector2(192, 155), "spacing carries around corner")
	cafe.unlock_table(3)
	cafe.unlock_table(4)
	for seat: Marker2D in cafe.free_seats():
		var path := customers._path(Vector2(66, 128), seat.global_position)
		check(not path.is_empty(), "seat is reachable")
		var previous := Vector2(66, 128)
		for point: Vector2 in path:
			for box: Rect2 in customers._obstacles():
				check(not customers._crosses(previous, point, box), "route avoids table footprint")
			previous = point


func test_cat_walk_and_bubble() -> void:
	var cat := Cat.new()
	cafe.add_child(cat)
	cat.position = Vector2(310, 20)
	var arrivals := record(cat.arrived)
	cat.say("More ginger ale, please.")
	cat.walk_to(Vector2(280, 20))
	check(await wait_for(func(): return arrivals.size() == 1, 2.0), "walk arrives")
	near(cat.position.x, 280.0, "exact target")
	check(cat.facing < 0.0, "faces walk direction")
	var bubble := cat._bubble
	check(bubble.global_position.x + bubble.size.x <= 320.0, "bubble stays inside right edge")
	cat.say("...")
	check(await wait_for(func(): return not is_instance_valid(cat._bubble), 2.0), "replacement bubble fades away")
	drop_listeners()
	cat.free()


func test_timer_fallback() -> void:
	var host := Node.new()
	var games := MiniGames.new()
	games.name = "MiniGames"
	host.add_child(games)
	var day: Node = load("res://scripts/day/day.gd").new()
	day.minigames_path = NodePath("../MiniGames")
	host.add_child(day)
	tree.root.add_child(host)
	day.start()
	check(await wait_for(func(): return not day.running, 60.0), "timer stand-in still finishes")
	eq(Game.last_report.sold + Game.last_report.spilled, 8, "stand-in sells stock")
	host.free()



func test_full_queue_moves_up() -> void:
	var arrivals := record(customers.at_counter)
	for i in customers.max_queue():
		customers.spawn()
	var count := customers.max_queue()
	for i in count:
		check(await wait_for(func(): return customers.front() != null, 30.0), "front advances %d" % i)
		customers.release_front(Cat.Mood.SAD)
	eq(arrivals.size(), count, "one counter signal per full-queue cat")
	check(await wait_for(func(): return customers._cats.is_empty(), 45.0), "full queue eventually leaves")


func test_seat_reservation_and_cleanup() -> void:
	customers.spawn()
	check(await wait_for(func(): return customers.front() != null, 15.0), "cat reaches counter")
	# Pick a seed that deterministically selects the seating branch.
	var random := RandomNumberGenerator.new()
	for seed_value in 100:
		random.seed = seed_value
		if random.randf() >= Customers.OUTSIDE_WEIGHT + Customers.WANDER_WEIGHT:
			customers._rng.seed = seed_value
			break
	var cat := customers.front()
	customers.release_front(Cat.Mood.HAPPY)
	eq(cafe.free_seats().size(), 4, "seat reserved before walking there")
	check(await wait_for(func(): return customers._cats[cat].phase == &"sit", 15.0), "cat reaches reserved seat")
	var position := cat.global_position
	await frames(60)
	check(cat.global_position.is_equal_approx(position), "cat rests on seat")
	drop_listeners()
	customers.free()
	eq(cafe.free_seats().size(), 5, "controller teardown releases seat")
	customers = Customers.new()
	tree.root.add_child(customers)
	customers.setup(cafe)
