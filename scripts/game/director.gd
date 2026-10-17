class_name Director
extends RefCounted
## The week's script. Pacing follows quota progress, not the day number: a beat fires
## once, at the end of the first day that pushes progress past `at`.
## Reorder / retune the story here and nowhere else.

const BEATS := [
	{id = &"warming_up", at = 0.25, dialogue = &"day_end_2"},
	{id = &"midpoint", at = 0.5, dialogue = &"day_end_4", event = &"twist"},
	{id = &"rush", at = 0.75},
]

# special cats a day by progress: [from progress, count]
const SPECIALS := [[0.0, 1], [0.25, 2], [0.75, 3]]

var _fired := {}


func specials_today() -> int:
	var p := Game.quota_progress()
	var n := 0
	for row in SPECIALS:
		if p >= row[0]:
			n = row[1]
	return roundi(n * (1.0 + Game.mod(&"special_mult")))


## Which cats of the day (by arrival order) are special.
func special_slots(drinks: int, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var n := mini(specials_today(), drinks)
	if n <= 0:
		return out
	if Game.day == 1:
		# tutorial: one special, near the end so the player has watched a few normal sales
		out.append(maxi(0, drinks - 2))
		return out
	var pool: Array[int] = []
	for i in range(1, drinks):
		pool.append(i)
	for i in n:
		if pool.is_empty():
			break
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## Beats crossed by today's earnings. Each beat fires once per run.
func beats_due() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := Game.quota_progress()
	for beat in BEATS:
		if p >= beat.at and not _fired.has(beat.id):
			_fired[beat.id] = true
			out.append(beat)
	return out


func boss_due() -> bool:
	return Game.week_earned() >= Tune.QUOTA
