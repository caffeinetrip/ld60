extends Node
## Run state and the economy rules. Pure model: no nodes, no timers. The day
## controller asks it what happens, the night panel buys through it.
## Numbers live in Tune, content in Ingredients / Relics / Tune.UPGRADES.
##
## The bar sells one drink a day: one picked ingredient per kind (alcohol, mixer,
## flavor) and a recipe in units per glass. Stock is counted in units; "restock for N"
## buys what N drinks need. Every set of ingredients has one right recipe, the same
## every day, like in a real bar (doses in Ingredients) - the closer the drink, the
## bigger the tip and the better tomorrow's reputation.
##
## Mods: everything that changes a number (upgrades, relics, later events) is a source
## of {key: value} in set_mods(); mod(key) is the sum over sources, 0.1 = +10 %.
## Keys: price_mult tip_mult demand_mult fair_mult discount capacity storage
## serve_speed hit_slow hit_zone loot_luck special_mult

signal money_changed(money: int)
signal stock_changed
signal week_changed(earned: int)
signal day_started(day: int)
signal day_ended(report: Dictionary)
signal mods_changed
signal relic_won(id: StringName)

var money := 0
var day := 1
var price := 0
var glasses := 0
var stock := {}				# ingredient id -> units
var unlocked := {}				# ingredient id -> true
var selected := {}				# Kind -> ingredient id on sale
var recipe := {}				# Kind -> units per glass
var earnings: Array[int] = []	# revenue of every finished day
var upgrades := {}				# upgrade id -> level
var mods := {}					# key -> summed value
var reputation := 0.0			# blended average score, 0..1
var backpack := Backpack.new()
var director: Director

var today := {}
var last_report := {}

var _sources := {}				# source -> {key: value}
var _left := 0					# drinks left to sell today
var _open := false				# a day is running
var _taste := {}				# today's drink vs ideal, same for every glass
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	backpack.changed.connect(func(): set_mods(&"relics", backpack.stats()))
	new_run()


func new_run() -> void:
	money = Tune.START_MONEY
	day = 1
	price = Tune.START_PRICE
	reputation = Tune.START_REPUTATION
	stock.clear()
	unlocked.clear()
	selected.clear()
	recipe.clear()
	for id in Ingredients.ids():
		stock[id] = Tune.START_STOCK.get(id, 0)
		if Ingredients.DEFS[id].unlock == 0:
			unlocked[id] = true
	for kind in Ingredients.KINDS:
		selected[kind] = Tune.START_SELECTED[kind]
		recipe[kind] = Tune.START_RECIPE[kind]
	glasses = Tune.START_GLASSES
	earnings.clear()
	upgrades.clear()
	_sources.clear()
	mods.clear()
	backpack.clear()
	last_report = {}
	_left = 0
	_open = false
	director = Director.new()
	_reset_today()


# --- mods --------------------------------------------------------------------

func mod(key: StringName) -> float:
	return mods.get(key, 0.0)


func set_mods(source: StringName, values: Dictionary) -> void:
	_sources[source] = values
	mods.clear()
	for s in _sources.values():
		for key in s:
			mods[key] = mods.get(key, 0.0) + s[key]
	mods_changed.emit()


# --- night: the shop ---------------------------------------------------------

func storage() -> int:
	return Tune.BASE_STORAGE + int(mod(&"storage"))


func capacity() -> int:
	return Tune.BASE_CAPACITY + int(mod(&"capacity"))


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func unlock_cost(id: StringName) -> int:
	return Ingredients.DEFS[id].unlock


func unlock(id: StringName) -> bool:
	if is_unlocked(id) or money < unlock_cost(id):
		return false
	_spend(unlock_cost(id))
	unlocked[id] = true
	stock_changed.emit()
	return true


## Puts an open ingredient on sale instead of the other one of its kind.
func select(id: StringName) -> bool:
	if not is_unlocked(id):
		return false
	selected[Ingredients.kind_of(id)] = id
	stock_changed.emit()
	return true


func units_per_glass() -> int:
	var n := 0
	for kind in recipe:
		n += recipe[kind]
	return n


## Sets units per glass for a kind; refuses to overfill the glass.
func set_recipe(kind: Ingredients.Kind, units: int) -> bool:
	units = maxi(units, 0)
	if units_per_glass() - recipe[kind] + units > capacity():
		return false
	if kind == Ingredients.Kind.ALCOHOL and units == 0:
		return false	# it's a bar
	recipe[kind] = units
	stock_changed.emit()
	return true


func unit_cost(id: StringName) -> int:
	return maxi(1, roundi(Ingredients.cost(id) * (1.0 - mod(&"discount"))))


## How many drinks the current stock makes with the current recipe.
func drinks_possible() -> int:
	var n := glasses
	for kind in recipe:
		if recipe[kind] > 0:
			n = mini(n, floori(float(stock[selected[kind]]) / recipe[kind]))
	return n


## Price of topping the stock up to `drinks` drinks.
func restock_cost(drinks: int) -> int:
	var total := maxi(0, drinks - glasses) * Tune.GLASS_COST
	for kind in recipe:
		var id: StringName = selected[kind]
		total += maxi(0, drinks * recipe[kind] - stock[id]) * unit_cost(id)
	return total


func restock(drinks: int) -> bool:
	drinks = mini(drinks, storage())
	var c := restock_cost(drinks)
	if c <= 0 or money < c:
		return false
	_spend(c)
	_fill(drinks)
	return true


## The guide's help when the shelf is empty and there's no money for a single drink.
func rescue() -> bool:
	if drinks_possible() > 0 or restock_cost(1) <= money:
		return false
	_fill(Tune.RESCUE)
	return true


## True when spending `cost` (and putting `id` on sale) leaves nothing to sell
## and no money for one drink.
func strands(cost: int, id := &"") -> bool:
	var was := selected.duplicate()
	if id != &"":
		selected[Ingredients.kind_of(id)] = id
	var stuck := drinks_possible() == 0 and restock_cost(1) > money - cost
	selected = was
	return stuck


## Most drinks the player can restock to right now.
func max_restock() -> int:
	var n := drinks_possible()
	while n < storage() and restock_cost(n + 1) <= money:
		n += 1
	return n


func cost_per_drink() -> int:
	var total := Tune.GLASS_COST
	for kind in recipe:
		total += recipe[kind] * unit_cost(selected[kind])
	return total


func level(upgrade: StringName) -> int:
	return upgrades.get(upgrade, 0)


func upgrade_cost(upgrade: StringName) -> int:
	var costs: Array = Tune.UPGRADES[upgrade].costs
	var lv := level(upgrade)
	return costs[lv] if lv < costs.size() else -1


func buy_upgrade(upgrade: StringName) -> bool:
	var c := upgrade_cost(upgrade)
	if c < 0 or money < c:
		return false
	_spend(c)
	upgrades[upgrade] = level(upgrade) + 1
	var sum := {}
	for id in upgrades:
		var per: Dictionary = Tune.UPGRADES[id].mods
		for key in per:
			sum[key] = sum.get(key, 0.0) + per[key] * upgrades[id]
	set_mods(&"upgrades", sum)
	stock_changed.emit()
	return true


# --- day ---------------------------------------------------------------------

func start_day() -> void:
	_reset_today()
	_open = true
	_left = drinks_possible()
	_taste = taste()
	day_started.emit(day)


## What cats will pay without blinking: the value of what's in the glass.
func fair_price() -> float:
	var v := 0.0
	for kind in recipe:
		if recipe[kind] > 0:
			v += Ingredients.DEFS[selected[kind]].value
	return v * (Tune.FAIR_BASE + Tune.FAIR_REP * reputation) * (1.0 + mod(&"fair_mult"))


## 1 = full flow of cats, 0 = nobody comes. Cheaper than fair doesn't add more.
func demand() -> float:
	var ratio := price / maxf(fair_price(), 1.0)
	return clampf((Tune.DEMAND_ZERO - ratio) / (Tune.DEMAND_ZERO - 1.0), 0.0, 1.0) * (1.0 + mod(&"demand_mult"))


func serve_time() -> float:
	return Tune.SERVE_TIME / (1.0 + mod(&"serve_speed"))


func drinks_left() -> int:
	return _left


## The right recipe for what's on sale, Kind -> units.
func ideal() -> Dictionary:
	var alcohol: Dictionary = Ingredients.DEFS[selected[Ingredients.Kind.ALCOHOL]]
	return {
		Ingredients.Kind.ALCOHOL: alcohol.dose,
		Ingredients.Kind.MIXER: alcohol.mix,
		Ingredients.Kind.FLAVOR: Ingredients.DEFS[selected[Ingredients.Kind.FLAVOR]].dose,
	}


## Today's drink against the ideal: {score 0..1, line = what a cat says}.
func taste() -> Dictionary:
	var want := ideal()
	var penalty := 0
	var worst := 0
	var worst_kind: int = Ingredients.Kind.ALCOHOL
	for kind in Ingredients.KINDS:
		var d: int = recipe[kind] - want[kind]
		penalty += absi(d)
		if absi(d) > absi(worst):
			worst = d
			worst_kind = kind
	var what := Ingredients.display_name(selected[worst_kind])
	var line := ""
	if worst > 0:
		line = "Too much %s!" % what
	elif worst < 0 and recipe[worst_kind] > 0:
		line = "More %s, please." % what
	elif worst < 0:
		line = "Needs %s..." % Ingredients.KIND_NEED[worst_kind]
	return {score = clampf(1.0 - penalty * Tune.PENALTY_PER_UNIT, 0.0, 1.0), line = line}


## Sells the next drink. quality < 1 comes from a minigame; 0 = spilled, no money.
## Returns {money, score, line}.
func sell_next(quality := 1.0) -> Dictionary:
	if _left <= 0:
		return {money = 0, score = 0.0, line = ""}
	_left -= 1
	glasses -= 1
	for kind in recipe:
		stock[selected[kind]] -= recipe[kind]
	stock_changed.emit()

	if quality <= 0.0:
		today.spilled += 1
		return {money = 0, score = 0.0, line = ""}

	var paid := roundi(price * (1.0 + mod(&"price_mult")))
	var tip := roundi(price * Tune.TIP_MAX * _taste.score * quality * (1.0 + mod(&"tip_mult")))
	_earn(paid + tip)
	today.sold += 1
	today.tips += tip
	today.score_sum += _taste.score
	if _taste.line != "":
		today.complaints[_taste.line] = today.complaints.get(_taste.line, 0) + 1
	return {money = paid + tip, score = _taste.score, line = _taste.line}


func end_day(reason: StringName) -> Dictionary:
	today.ended_by = reason
	if today.sold > 0:
		reputation = lerpf(reputation, today.score_sum / today.sold, Tune.REP_MEMORY)
	earnings.append(today.revenue)
	_left = 0
	_open = false
	last_report = today.duplicate(true)
	_reset_today()
	day_ended.emit(last_report)
	day += 1
	week_changed.emit(week_earned())
	return last_report


## Revenue of the last 7 days: while a day runs, today and the 6 before it.
func week_earned() -> int:
	var sum: int = today.get("revenue", 0)
	var days := Tune.WEEK - 1 if _open else Tune.WEEK
	for i in range(maxi(0, earnings.size() - days), earnings.size()):
		sum += earnings[i]
	return sum


func quota_progress() -> float:
	return clampf(float(week_earned()) / Tune.QUOTA, 0.0, 1.0)


## 0..1, grows with how strong the player is. Drives minigame difficulty and loot.
func difficulty() -> float:
	return quota_progress()


## Relic for a minigame tier, or &"" when the tier earns nothing. Lands in the pocket.
func grant_relic(tier: StringName) -> StringName:
	if not Tune.LOOT.has(tier):
		return &""
	var roll: Array = Tune.LOOT[tier]
	var luck := Tune.LOOT_LUCK * difficulty() + mod(&"loot_luck")
	var rarity: StringName = roll[1] if _rng.randf() < roll[2] + luck else roll[0]
	var id := Relics.roll(rarity, _rng)
	backpack.add_to_pocket(id)
	relic_won.emit(id)
	return id


## What reacts to `event` (&"serve", &"day_start"...): the `proc` of every placed relic
## and every ingredient on sale. A proc is {event, chance, game, reward}, see Relics.
func procs(event: StringName) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for id in backpack.placed():
		defs.append(Relics.get_def(id))
	for kind in selected:
		defs.append(Ingredients.DEFS[selected[kind]])
	var out: Array[Dictionary] = []
	for def in defs:
		var p: Dictionary = def.get("proc", {})
		if p.get("event") == event:
			out.append(p)
	return out


## Pays a proc reward scaled by how well its minigame went. Returns the money.
func reward(what: Dictionary, quality := 1.0) -> int:
	var cash := roundi(what.get("money", 0) * quality)
	if cash > 0:
		_earn(cash)
	return cash


# --- internals ---------------------------------------------------------------

func _spend(amount: int) -> void:
	money -= amount
	money_changed.emit(money)


func _earn(amount: int) -> void:
	_spend(-amount)
	today.revenue += amount
	week_changed.emit(week_earned())


func _reset_today() -> void:
	today = {sold = 0, revenue = 0, tips = 0, score_sum = 0.0, spilled = 0,
		walked = 0, specials_won = 0, specials_lost = 0, complaints = {}, ended_by = &""}


func _fill(drinks: int) -> void:
	glasses = maxi(glasses, drinks)
	for kind in recipe:
		var id: StringName = selected[kind]
		stock[id] = maxi(stock[id], drinks * recipe[kind])
	stock_changed.emit()
