extends "res://tests/suite.gd"


func _progress(week: int) -> void:
	Game.earnings.assign([week])


func test_specials_grow_with_progress() -> void:
	eq(Game.director.specials_today(), 1, "start")
	_progress(375)
	eq(Game.director.specials_today(), 2, "25 %")
	_progress(1125)
	eq(Game.director.specials_today(), 3, "75 %")
	Game.set_bonuses({special_mult = 1.0})
	eq(Game.director.specials_today(), 6, "relic doubles")


func test_day_one_special_near_the_end() -> void:
	var rng := RandomNumberGenerator.new()
	eq(Game.director.special_slots(8, rng), [6] as Array[int], "8 drinks")
	eq(Game.director.special_slots(1, rng), [0] as Array[int], "1 drink")
	eq(Game.director.special_slots(0, rng), [] as Array[int], "no drinks")


func test_later_slots() -> void:
	Game.day = 3
	_progress(1125)
	var rng := RandomNumberGenerator.new()
	for seed in 50:
		rng.seed = seed
		var slots := Game.director.special_slots(8, rng)
		eq(slots.size(), 3, "three specials")
		for s in slots:
			check(s >= 1 and s < 8, "slot %d in 1..7" % s)
			eq(slots.count(s), 1, "slot %d once" % s)
	eq(Game.director.special_slots(2, rng), [1] as Array[int], "first cat is always normal")
	eq(Game.director.special_slots(1, rng).size(), 0, "one drink, no special")


func test_beats_fire_once() -> void:
	eq(Game.director.beats_due().size(), 0, "nothing yet")
	_progress(400)
	var due := Game.director.beats_due()
	eq(due.size(), 1, "one beat")
	eq(due[0].id, &"warming_up", "25 %")
	eq(Game.director.beats_due().size(), 0, "fires once")
	_progress(1200)
	due = Game.director.beats_due()
	eq(due.map(func(b): return b.id), [&"midpoint", &"rush"], "50 and 75 %")


func test_boss() -> void:
	_progress(1499)
	check(not Game.director.boss_due(), "1499")
	_progress(1500)
	check(Game.director.boss_due(), "1500")
