class_name Backpack
extends RefCounted
## Relic grid like Backpack Battles. Relics from special cats land in the pocket (a
## grid of its own, POCKET wide, as tall as it needs); at night the player places them. A placed relic works with its neighbors: every other
## placed relic with a cell touching one of its cells, diagonals included.
## Every change recounts the live numbers of the placed relics, see live(). Copies of a
## relic stack: their chances, counts, goals and powers add up. The effect
## calls at the bottom take plain values and never touch the day: Game and Day call
## them at their moments. stats() feeds Game.set_mods(&"relics", ...).

signal changed

const POCKET := Vector2i(7, 7)		# pocket grid; it grows down when a new relic doesn't fit

var items: Array[Dictionary] = []	# {id, cell: Vector2i, rot: 0..3 clockwise, live, mult}
var pocket: Array[Dictionary] = []	# {id, cell, rot} on the pocket grid, do nothing there

var _seed := 0				# today's tie breaker for the power strips
var _tv_until := -1.0		# day time the crt tvs tip until
var _arcade: Array[Dictionary] = []	# the arcades of the last arcade_roll() that won


func clear() -> void:
	items.clear()
	pocket.clear()
	_seed = 0
	_tv_until = -1.0
	_arcade = []
	changed.emit()


## Into the first free spot of the pocket, row by row.
func add_to_pocket(id: StringName) -> Dictionary:
	var item := {}
	var y := 0
	while item.is_empty():
		for x in POCKET.x:
			if item.is_empty():
				item = put_in_pocket(id, Vector2i(x, y), 0)
		y += 1
	return item


func can_pocket(id: StringName, cell: Vector2i, rot: int) -> bool:
	for c in turned(id, rot):
		var at: Vector2i = cell + c
		if at.x < 0 or at.y < 0 or at.x >= POCKET.x or not pocket_at(at).is_empty():
			return false
	return true


func put_in_pocket(id: StringName, cell: Vector2i, rot: int) -> Dictionary:
	if not can_pocket(id, cell, rot):
		return {}
	var item := {id = id, cell = cell, rot = posmod(rot, 4)}
	pocket.append(item)
	changed.emit()
	return item


func take_from_pocket(item: Dictionary) -> void:
	pocket.erase(item)
	changed.emit()


func pocket_at(cell: Vector2i) -> Dictionary:
	for item in pocket:
		if cells_of(item).has(cell):
			return item
	return {}


## Rows the pocket uses: POCKET.y, more when relics lie lower.
func pocket_rows() -> int:
	var rows := POCKET.y
	for item in pocket:
		for c in cells_of(item):
			rows = maxi(rows, c.y + 1)
	return rows


func pocket_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for item in pocket:
		out.append(item.id)
	return out


func placed() -> Array[StringName]:
	var out: Array[StringName] = []
	for item in items:
		out.append(item.id)
	return out


## Grid size, grows with the grid mod (the backpack upgrade). Placed relics stay.
static func size() -> Vector2i:
	return Relics.GRID_SIZES[clampi(int(Game.mod(&"grid")), 0, Relics.GRID_SIZES.size() - 1)]


## The grid shrank: relics that hang off it go back to the pocket.
func fit() -> void:
	var grid := size()
	for item in items.duplicate():
		for c in cells_of(item):
			if c.x >= grid.x or c.y >= grid.y:
				take(item)
				add_to_pocket(item.id)
				break


func can_place(id: StringName, cell: Vector2i, rot: int) -> bool:
	var grid := size()
	for c in turned(id, rot):
		var at: Vector2i = cell + c
		if at.x < 0 or at.y < 0 or at.x >= grid.x or at.y >= grid.y or not item_at(at).is_empty():
			return false
	return true


func place(id: StringName, cell: Vector2i, rot: int) -> Dictionary:
	if not can_place(id, cell, rot):
		return {}
	var item := {id = id, cell = cell, rot = posmod(rot, 4)}
	items.append(item)
	_changed()
	return item


## Lifts a placed relic off the grid (to move it or pocket it).
func take(item: Dictionary) -> void:
	items.erase(item)
	_changed()


func item_at(cell: Vector2i) -> Dictionary:
	for item in items:
		if cells_of(item).has(cell):
			return item
	return {}


func items_of(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in items:
		if item.id == id:
			out.append(item)
	return out


func cells_of(item: Dictionary) -> Array[Vector2i]:
	return _offset(turned(item.id, item.rot), item.cell)


## Cells around `item` in 8 directions, off-grid ones too.
func ring(item: Dictionary) -> Array[Vector2i]:
	var own := cells_of(item)
	var out: Array[Vector2i] = []
	for c in own:
		for y in range(-1, 2):
			for x in range(-1, 2):
				var at := c + Vector2i(x, y)
				if not own.has(at) and not out.has(at):
					out.append(at)
	return out


## Every other placed relic touching `item`. Works for a relic that isn't placed yet too.
func neighbors(item: Dictionary) -> Array[Dictionary]:
	var near := ring(item)
	var out: Array[Dictionary] = []
	for other in items:
		if is_same(other, item):
			continue
		for c in cells_of(other):
			if near.has(c):
				out.append(other)
				break
	return out


## The neighbors whose numbers `item` changes.
func affects(item: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match item.id:
		&"power_strip":
			var target := pick(item)
			if not target.is_empty():
				out.append(target)
		&"wire_tangle":
			out = _with(item, &"chance")
		&"arcade":
			out = _with(item, &"power")
		&"cctv":
			out = _with(item, &"goal")
		&"amplifier":
			for other in neighbors(item):
				if other.id == &"receipt_printer":
					out.append(other)
	return out


## A power strip's neighbor: the one with a chance and the most cells. Equal ones are
## picked by today's seed, so the pick holds all day and changes the next.
func pick(strip: Dictionary) -> Dictionary:
	var best: Array[Dictionary] = []
	var most := 0
	for other in _with(strip, &"chance"):
		var n := cells_of(other).size()
		if n > most:
			best.clear()
			most = n
		if n == most:
			best.append(other)
	if best.is_empty():
		return {}
	return best[posmod(hash([_seed, strip.cell]), best.size())]


## {chance, power, goal, mult} after every boost, only the numbers the relic has
## (mult always). {} for a relic that isn't placed.
func live(item: Dictionary) -> Dictionary:
	return item.get("live", {})


## Plain mods while placed: the fuse boxes' cool_fast and any def `mods`.
func stats() -> Dictionary:
	var out := {}
	for item in items:
		var mods: Dictionary = Relics.get_def(item.id).get("mods", {})
		for key in mods:
			out[key] = out.get(key, 0.0) + mods[key]
		if item.id == &"fuse_box" and item.live.power > 0.0:
			out[&"cool_fast"] = out.get(&"cool_fast", 0.0) + item.live.power
	return out


# --- effects -------------------------------------------------------------------

## A new day: arcade mults back to x1, power strips pick among equal neighbors again.
func start_day(rng: RandomNumberGenerator) -> void:
	for item in items:
		item.erase("mult")
	_seed = rng.randi()
	_tv_until = -1.0
	_arcade = []
	_changed()


## How long an order takes: Relics.FAST_ORDER when the price is under the calculators'
## goals added up.
func order_time(price: float, base: float) -> float:
	var goal := 0.0
	for item in items_of(&"calculator"):
		goal += item.live.goal
	return minf(base, Relics.FAST_ORDER) if price < goal else base


## How many next normal cats an order treats, 0 = none. A POS terminal treats one, a cash
## register 2-4; several add up.
func treats(price: float, rng: RandomNumberGenerator) -> int:
	var n := 0
	for item in items_of(&"pos_terminal"):
		if price > item.live.goal:
			n += 1
	for item in items_of(&"cash_register"):
		if price > item.live.goal:
			n += _register_roll(rng)
	return n


## A normal cat walks in: true when a pager calls a friend right behind it.
func friend_roll(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < _chance(&"pager")


## Relic money on one sale. `order` = {price (the order price, friend discount in),
## money (what the sale pays before relics), score (taste 0..1), tier (&"" for a normal
## order, else the special cat's minigame tier), perfect_money, now (day time, s)}.
## Returns {money (the new total), extra, tip, x2, fixed, fired: the relic ids that worked}.
func order_extras(order: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var tier: StringName = order.get("tier", &"")
	var money: int = order.money
	var fired: Array[StringName] = []
	var payouts: Array[Dictionary] = []
	var out := {money = money, extra = 0, tip = 0, x2 = false, fixed = false, fired = fired, payouts = payouts}
	if tier == &"miss":
		return out

	var bad: bool = tier == &"meh" or (tier == &"" and order.get("score", 1.0) < Relics.BAD_SCORE)
	var equalizers := items_of(&"equalizer").size()
	if bad and equalizers > 0:
		# each copy takes the same bite off what is still missing
		var share := 1.0 - pow(1.0 - Relics.EQUALIZER, equalizers)
		var fair := roundi(order.get("perfect_money", 0.0) * share)
		if fair > money:
			payouts.append({id = &"equalizer", money = fair - money})
			money = fair
			out.fixed = true
			fired.append(&"equalizer")
	if minigame_x2(tier, rng):
		payouts.append({id = &"scoreboard", money = money})
		money *= 2
		out.x2 = true
		fired.append(&"scoreboard")

	if tier == &"":
		var price: float = order.price
		var coins := 0.0
		for item in items_of(&"receipt_printer"):
			# Flat coins, paid in base-sized activations (x2 / x3 = two / three payouts).
			# Round the cumulative sum so amplified printers keep their exact total.
			var remaining: float = item.live.power
			var base: float = Relics.numbers(&"receipt_printer").power
			while remaining > 0.000001:
				var part := minf(base, remaining)
				var cash := roundi(coins + part) - roundi(coins)
				if cash > 0:
					payouts.append({id = &"receipt_printer", money = cash})
				coins += part
				remaining -= part
		out.extra = roundi(coins)
		if out.extra > 0:
			fired.append(&"receipt_printer")
		var tip := 0.0
		for item in items_of(&"boombox"):
			if price > item.live.goal and item.live.power > 0.0:
				tip += price * rng.randf_range(Relics.BOOMBOX_TIP[0], Relics.BOOMBOX_TIP[1]) * item.live.power
				if not fired.has(&"boombox"):
					fired.append(&"boombox")
		if order.get("now", 0.0) < _tv_until:
			var tv := 0.0
			for item in items_of(&"crt_tv"):
				tv += item.live.power
			if tv > 0.0:
				tip += price * tv
				fired.append(&"crt_tv")
		out.tip = roundi(tip)
	out.money = money + out.extra + out.tip
	return out


## LED scoreboard: a perfect minigame rolls each scoreboard's chance to pay double.
func minigame_x2(tier: StringName, rng: RandomNumberGenerator) -> bool:
	if tier != &"perfect":
		return false
	return rng.randf() < _chance(&"scoreboard")


## The machine got whacked at day time `now`: crt tvs tip for Relics.TV_TIME. True if one is placed.
func machine_whacked(now: float) -> bool:
	if items_of(&"crt_tv").is_empty():
		return false
	_tv_until = now + Relics.TV_TIME
	return true


## PC tower: a special cat's minigame sometimes comes twice - a second roll for a relic.
func double_roll(rng: RandomNumberGenerator) -> bool:
	return not items_of(&"pc_tower").is_empty() and rng.randf() < Relics.PC_DOUBLE


## A special cat's minigame: true when the arcades with a power neighbor roll their
## chances added up. Pass that minigame's tier to arcade_apply() then.
func arcade_roll(rng: RandomNumberGenerator) -> bool:
	_arcade = []
	var chance := 0.0
	for item in items_of(&"arcade"):
		if not affects(item).is_empty():
			_arcade.append(item)
			chance += item.live.chance
	if rng.randf() < minf(chance, 1.0):
		return true
	_arcade = []
	return false


## A random power neighbor of the arcades that rolled gets the tier's mult till the day
## ends. Returns {id, mult}, {} when no arcade rolled.
func arcade_apply(tier: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = []
	for arcade in _arcade:
		for item in affects(arcade):
			if not pool.has(item):
				pool.append(item)
	_arcade = []
	if pool.is_empty():
		return {}
	var target := pool[rng.randi() % pool.size()]
	target.mult = Relics.ARCADE_MULT.get(tier, 1)
	_changed()
	return {id = target.id, mult = target.mult}


## A relic's shape turned `rot` times clockwise, its top-left at 0,0.
static func turned(id: StringName, rot: int) -> Array[Vector2i]:
	var shape: Array[Vector2i] = []
	for c in Relics.get_def(id).shape:
		shape.append(_turn(c, rot))
	var low := shape[0]
	for c in shape:
		low = low.min(c)
	return _offset(shape, -low)


func _changed() -> void:
	_recount()
	changed.emit()


## Live numbers: own mult first, then the amplifiers, wire tangles, power strips and
## cameras on their neighbors. A chance never goes over 1.
func _recount() -> void:
	for item in items:
		var n := Relics.numbers(item.id)
		n.mult = item.get("mult", 1)
		if n.has("power"):
			n.power *= n.mult
		item.live = n
	for item in items:
		var p: float = item.live.get("power", 0.0)
		for other in affects(item):
			match item.id:
				&"amplifier":
					other.live.power *= 1.0 + p
				&"wire_tangle", &"power_strip":
					other.live.chance += p
				&"cctv":
					var easier := 1.0 - p if Relics.get_def(other.id).goal == &"above" else 1.0 + p
					other.live.goal = maxf(0.0, other.live.goal * easier)
	for item in items:
		if item.live.has("chance"):
			item.live.chance = minf(item.live.chance, 1.0)


## The chances of every copy of `id` added up, at most 1.
func _chance(id: StringName) -> float:
	var sum := 0.0
	for item in items_of(id):
		sum += item.live.chance
	return minf(sum, 1.0)


## Cash register: 2, 3 or 4 cats by Relics.TREATS odds.
func _register_roll(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	for t in Relics.TREATS:
		r -= t[1]
		if r < 0.0:
			return t[0]
	return Relics.TREATS[-1][0]


## Placed neighbors whose def has `key` (a chance, a power, a goal).
func _with(item: Dictionary, key: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for other in neighbors(item):
		if Relics.get_def(other.id).has(key):
			out.append(other)
	return out


static func _turn(c: Vector2i, rot: int) -> Vector2i:
	for i in posmod(rot, 4):
		c = Vector2i(-c.y, c.x)
	return c


static func _offset(cells: Array[Vector2i], by: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c + by)
	return out
