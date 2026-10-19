class_name Relics
## Retro gadgets the special cats leave behind. A relic covers `shape` cells in the
## Backpack grid and works with its neighbors: every placed relic touching one of its
## cells, diagonals too. Its numbers: `chance` (its own roll), `power` (its main number),
## `goal` (&"above" / &"below": works on orders over / under GOAL). Backpack keeps them
## live after the neighbors' boosts and runs the effects; `on` is the tooltip's box label.
## Optional `mods` count while placed (keys as in Game.mod()). Optional `proc` =
## {event, chance, game, reward}: on `event` (&"serve", &"day_start") it rolls `chance`,
## plays minigame `game` and pays `reward` ({money}) times its quality.

const GOAL := 25.0				# order price the goals compare with
const BAD_SCORE := 0.7			# a normal order under this taste score is a bad one
const EQUALIZER := 0.95			# bad orders pay this share of a perfect one
const FRIEND_DISCOUNT := 0.2	# pager: the cat and its friend both pay less
const FAST_ORDER := 0.1			# calculator order time, s
const TV_TIME := 10.0			# crt tv tips this long after the machine breaks
const BOOMBOX_TIP := [0.3, 0.45]	# share of the price, times power
const TREATS := [[2, 0.7], [3, 0.2], [4, 0.1]]	# cash register: cats treated, odds
const ARCADE_MULT := {&"miss": 0, &"meh": 1, &"good": 2, &"perfect": 3}
const GRID_SIZES := [Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 4), Vector2i(6, 4)]	# by the grid mod

const RARITY_COLOR := {&"common": Color("9c8a99"), &"rare": Color("4aa3df"), &"epic": Color("b06ad9")}

const ONE := [Vector2i(0, 0)]
const WIDE := [Vector2i(0, 0), Vector2i(1, 0)]
const TALL := [Vector2i(0, 0), Vector2i(0, 1)]
const LONG := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const SQUARE := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

const DEFS := {
	&"power_strip": {name = "Power Strip", rarity = &"rare", shape = WIDE, power = 0.1,
		on = "neighbors", text = "Boosts one relic. Ties change daily; diagonals count."},
	&"wire_tangle": {name = "Wire Tangle", rarity = &"common", shape = ONE, power = 0.05,
		on = "neighbors", text = "Only affects relics with a chance to activate. Diagonals count."},
	&"arcade": {name = "Arcade Cabinet", rarity = &"epic", shape = TALL, chance = 0.3,
		on = "neighbors", text = "Changes a random neighbor's power until closing. Diagonals count."},
	&"pos_terminal": {name = "POS Terminal", rarity = &"common", shape = ONE, goal = &"above",
		on = "orders", text = "Normal sales only. Customers still pay; instant orders cannot chain."},
	&"cash_register": {name = "Cash Register", rarity = &"epic", shape = SQUARE, goal = &"above",
		on = "orders", text = "Normal sales only. Customers still pay; instant orders cannot chain."},
	&"receipt_printer": {name = "Receipt Printer", rarity = &"common", shape = WIDE, power = 5.0,
		on = "orders", text = "Adds cash to normal sales. Special cats are excluded."},
	&"amplifier": {name = "Amplifier", rarity = &"rare", shape = WIDE, power = 0.5,
		on = "neighbors", text = "Place beside Receipt Printers to boost their bonus. Diagonals count."},
	&"scoreboard": {name = "LED Scoreboard", rarity = &"rare", shape = LONG, chance = 0.1,
		on = "minigames", text = "Doubles cash rewards, not relic drops."},
	&"equalizer": {name = "Equalizer", rarity = &"common", shape = WIDE,
		on = "orders", text = "Protects income from poor drinks. Misses are excluded."},
	&"pager": {name = "Pager", rarity = &"common", shape = ONE, chance = 0.1,
		on = "orders", text = "Requires a free queue slot and enough stock for both cats."},
	&"calculator": {name = "Calculator", rarity = &"common", shape = ONE, goal = &"below",
		on = "orders", text = "Speeds up normal orders. Special cats still play minigames."},
	&"cctv": {name = "CCTV Camera", rarity = &"common", shape = ONE, power = 0.4,
		on = "neighbors", text = "Eases nearby relics' price requirements. Diagonals count."},
	&"boombox": {name = "Boombox", rarity = &"rare", shape = WIDE, goal = &"above", power = 1.0,
		on = "orders", text = "Adds a random bonus based on the normal order's price."},
	&"fuse_box": {name = "Fuse Box", rarity = &"common", shape = TALL, power = 0.2,
		on = "machine", text = "Shortens the wait between boosts. Requires Percussive Maintenance."},
	&"crt_tv": {name = "CRT TV", rarity = &"rare", shape = ONE, power = 0.3,
		on = "machine", text = "Rewards machine boosts. Requires Percussive Maintenance."},
	&"pc_tower": {name = "PC Tower", rarity = &"epic", shape = TALL,
		on = "minigames", text = "Special cats sometimes bring a second minigame."},
}

const PC_DOUBLE := 0.5	# PC tower: chance of a second minigame for a special cat

const MOD_TEXT := {
	price_mult = "+%d%% price", tip_mult = "+%d%% tips", demand_mult = "+%d%% cats",
	fair_mult = "+%d%% fair price", discount = "-%d%% unit cost", serve_speed = "+%d%% serve speed",
	hit_slow = "%d%% slower bar", hit_zone = "+%d%% hit zone", loot_luck = "+%d%% loot luck",
	special_mult = "+%d%% special cats", arrival_mult = "+%d%% passers-by",
	cool_fast = "-%d%% machine cooldown", capacity = "+%d unit per glass", day_length = "+%d s day",
	grid = "+%d backpack size", regulars = "+%d regular", whack = "+%d machine whack",
}
const FLAT := ["capacity", "day_length", "grid", "regulars", "whack"]

## Relics made at runtime (events, tests), same format as DEFS.
static var custom := {}
static var _icons := {}


static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, custom.get(id, {}))


## art/relics/<id>.png, 10 px per cell minus the 1 px grid gap; null when there is none.
## `mask` = its white silhouette. Kept here: a texture loaded inside _draw and dropped
## right after draws white.
static func icon(id: StringName, mask := false) -> Texture2D:
	var path := "res://art/relics/%s%s.png" % ["mask/" if mask else "", id]
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]


static func roll(rarity: StringName, rng: RandomNumberGenerator) -> StringName:
	var pool: Array[StringName] = []
	for id in DEFS:
		if DEFS[id].rarity == rarity:
			pool.append(id)
	if pool.is_empty():
		pool.assign(DEFS.keys())
	return pool[rng.randi() % pool.size()]


## The numbers a relic starts with, before any neighbor: {chance, power, goal}, only
## the ones it has.
static func numbers(id: StringName) -> Dictionary:
	var d := get_def(id)
	var out := {}
	if d.has("chance"):
		out.chance = d.chance
	if d.has("power"):
		out.power = d.power
	if d.has("goal"):
		out.goal = GOAL
	return out


## "+10% tips, +1 unit per glass"
static func describe(mods: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in mods:
		var v: float = mods[key] if FLAT.has(key) else mods[key] * 100.0
		parts.append(MOD_TEXT.get(key, String(key) + " %d") % roundi(v))
	return ", ".join(parts)


## Tooltip: {name, rarity, on, lines, text}. `live` = Backpack.live(item), the base
## numbers when empty. Numbers in `lines` are {braced} for the view to color.
static func info(id: StringName, live := {}) -> Dictionary:
	var d := get_def(id)
	var n := numbers(id)
	n.merge(live, true)
	var chance := _pct(n.get("chance", 0.0))
	var power: float = n.get("power", 0.0)
	var goal := "{$%d}" % roundi(n.get("goal", GOAL))
	var lines := PackedStringArray()
	match id:
		&"power_strip":
			lines.append("Adds {%d} percentage points to a neighbor's chance." % roundi(power * 100.0))
			lines.append("Picks the largest eligible relic.")
		&"wire_tangle":
			lines.append("Adds {%d} percentage points to each neighbor's chance." % roundi(power * 100.0))
		&"arcade":
			lines.append("{%s} chance after a special cat's minigame." % chance)
			lines.append("Power: Miss x{0}, Meh x{1}, Good x{2}, Perfect x{3}.")
		&"pos_terminal":
			lines.append("Orders over %s: prepare the next normal order instantly." % goal)
		&"cash_register":
			lines.append("Orders over %s: prepare the next {2-4} normal orders instantly." % goal)
		&"receipt_printer":
			lines.append("Each normal order pays {+$%d} extra." % roundi(power))
		&"amplifier":
			lines.append("Multiplies nearby Receipt Printer bonuses by {%s}." % String.num(1.0 + power, 2))
		&"scoreboard":
			lines.append("A {Perfect} minigame has a {%s} chance to pay {double}." % chance)
		&"equalizer":
			lines.append("Bad orders pay at least {%s} of a perfect sale." % _pct(EQUALIZER))
			lines.append("Applies below {%s} taste or on a {Meh} result." % _pct(BAD_SCORE))
		&"pager":
			lines.append("{%s} chance for a normal cat to bring a friend." % chance)
			lines.append("Both cats pay {%s} less." % _pct(FRIEND_DISCOUNT))
		&"calculator":
			lines.append("Orders under %s take at most {%s} s to prepare." % [goal, String.num(FAST_ORDER, 2)])
		&"cctv":
			lines.append("Lowers minimum order values by {%s}." % _pct(minf(power, 1.0)))
			lines.append("Raises maximum order values by {%s}." % _pct(power))
		&"boombox":
			lines.append("Orders over %s earn an extra {%d-%s} tip." % [goal,
				roundi(BOOMBOX_TIP[0] * power * 100.0), _pct(BOOMBOX_TIP[1] * power)])
		&"fuse_box":
			lines.append("Reduces machine cooldown by {%s}." % _pct(power))
			lines.append("Total reduction is capped at {80%}.")
		&"crt_tv":
			lines.append("Whack the machine to gain {%d} s of bonus tips." % TV_TIME)
			lines.append("Normal orders tip {+%s} of their price." % _pct(power))
		&"pc_tower":
			lines.append("{%s} chance a special cat's minigame comes twice." % _pct(PC_DOUBLE))
			lines.append("Each one rolls for a relic.")
		_:
			if not d.get("mods", {}).is_empty():
				lines.append(describe(d.mods))
	if live.get("mult", 1) != 1:
		lines.append("Arcade power: x{%d} until closing." % live.mult)
	return {name = d.get("name", String(id)), rarity = d.get("rarity", &"common"),
		on = d.get("on", "effect"), lines = lines, text = d.get("text", "")}


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
