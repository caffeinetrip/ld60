class_name Director
extends RefCounted
## The week's script. Pacing follows quota progress, not the day number: a beat fires
## once, at the end of the first day that pushes progress past `at`.
## Reorder / retune the story here and nowhere else.

const BEATS := [
	{id = &"first_day", at = 0.0, day = 2},
	{id = &"warming_up", at = 0.25},
	{id = &"newspaper", at = 0.0, day = 5, dialogue = &"newspaper", event = &"newspaper"},
	{id = &"midpoint", at = 0.5, event = &"twist"},
	{id = &"rush", at = 0.75},
]

# special cats a day by progress: [from progress, count]; none before FIRST_SPECIAL_DAY
const FIRST_SPECIAL_DAY := 3		# relics come the day before Inventory opens
const SPECIALS := [[0.0, 1], [0.25, 2], [0.75, 3]]

var _fired := {}


func specials_today() -> int:
	if Game.day < FIRST_SPECIAL_DAY:
		return 0
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
	if Game.day == FIRST_SPECIAL_DAY:
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


## Beats crossed by today's earnings. Each beat fires once per run. Endless runs keep
## the events and drop the talks.
func beats_due() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := Game.quota_progress()
	for beat in BEATS:
		# `day` = not before the night that opens that day
		if p >= beat.at and Game.day >= beat.get("day", 0) and not _fired.has(beat.id):
			_fired[beat.id] = true
			if Game.endless:
				beat = beat.duplicate()
				beat.erase("dialogue")
			out.append(beat)
	return out


func boss_due() -> bool:
	return not Game.endless and Game.week_earned() >= Tune.QUOTA
