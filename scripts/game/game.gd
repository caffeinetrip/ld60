extends Node
## Run state and the economy rules. Pure model: no nodes, no timers. The day
## controller asks it what happens, the night panel buys through it.
##
## The bar sells one drink a day: one picked ingredient per kind (alcohol, mixer,
## flavor) and a recipe in units per glass. Stock is counted in units; "restock for N"
## buys what N drinks need. Every set of ingredients has one right recipe, the same
## every day, like in a real bar (doses in Ingredients) — the closer the drink, the
## bigger the tip and the better tomorrow's reputation.
## Pricier ingredients cost more but cats accept a higher price (Ingredients `value`).

signal money_changed(money: int)
signal stock_changed
signal week_changed(earned: int)
signal day_started(day: int)
signal day_ended(report: Dictionary)
signal bonuses_changed
signal relic_won(id: StringName)

const WEEK := 7
const QUOTA := 1500
const START_MONEY := 120
const GLASS_COST := 1
const BASE_CAPACITY := 5		# units in one glass
const BASE_STORAGE := 25		# max glasses
const TIP_MAX := 0.5			# perfect drink tips half the price
const PENALTY_PER_UNIT := 0.25	# each unit off the ideal costs this much score
const RESCUE := 5				# drinks the guide brings when the bar is broke
const NEED_WORD := ["a kick", "something to mix", "some flavor"]

const UPGRADES := {
	&"storage": {name = "Bigger Shelf", desc = "+5 glasses of storage", costs = [80, 160, 320]},
	&"capacity": {name = "Tall Glasses", desc = "+1 unit per glass", costs = [120, 260]},
	&"service": {name = "Quick Hands", desc = "Serve 20% faster", costs = [60, 140, 300]},
}

var money := START_MONEY
var day := 1
var price := 10
var glasses := 0
var stock := {}				# ingredient id -> units
var unlocked := {}				# ingredient id -> true
var selected := {}				# Kind -> ingredient id on sale
var recipe := {}				# Kind -> units per glass
var earnings: Array[int] = []	# revenue of every finished day
var upgrades := {}				# upgrade id -> level
var bonuses := {}				# from relics
var reputation := 0.5			# blended average score, 0..1
var backpack = null				# Backpack, created once scripts/relics exists
var director: Director

var today := {}
var last_report := {}

var _left := 0					# drinks left to sell today
var _open := false				# a day is running
var _taste := {}				# today's drink vs ideal, same for every glass
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	new_run()


func new_run() -> void:
	money = START_MONEY
	day = 1
	price = 10
	stock.clear()
	unlocked.clear()
	for id in Ingredients.ids():
		stock[id] = 0
		if Ingredients.DEFS[id].unlock == 0:
			unlocked[id] = true
	selected = {
		Ingredients.Kind.ALCOHOL: &"brandy",
		Ingredients.Kind.MIXER: &"ginger_ale",
		Ingredients.Kind.FLAVOR: &"cinnamon",
	}
	earnings.clear()
	upgrades.clear()
	bonuses.clear()
	reputation = 0.5
	last_report = {}
	_left = 0
	_open = false
	director = Director.new()
	var bp_path := "res://scripts/relics/backpack.gd"
	backpack = load(bp_path).new() if ResourceLoader.exists(bp_path) else null
	if backpack:
		backpack.changed.connect(func(): set_bonuses(backpack.stats()))
	# starter kit from the guide, so day 1 opens with cats instead of a shop:
	# right but plain, the cats ask for flavor
	recipe = {Ingredients.Kind.ALCOHOL: 1, Ingredients.Kind.MIXER: 2, Ingredients.Kind.FLAVOR: 0}
	glasses = 8
	stock[&"brandy"] = 8
	stock[&"ginger_ale"] = 16
	_reset_today()


# --- night: the shop ---------------------------------------------------------

func storage() -> int:
	return BASE_STORAGE + 5 * level(&"storage")


func capacity() -> int:
	return BASE_CAPACITY + level(&"capacity") + int(bonus(&"capacity"))


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
	return maxi(1, roundi(Ingredients.cost(id) * (1.0 - bonus(&"discount"))))


## How many drinks the current stock makes with the current recipe.
func drinks_possible() -> int:
	var n := glasses
	for kind in recipe:
		if recipe[kind] > 0:
			n = mini(n, floori(float(stock[selected[kind]]) / recipe[kind]))
	return n


## Price of topping the stock up to `drinks` drinks.
func restock_cost(drinks: int) -> int:
	var total := maxi(0, drinks - glasses) * GLASS_COST
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
	_fill(RESCUE)
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
	var total := GLASS_COST
	for kind in recipe:
		total += recipe[kind] * unit_cost(selected[kind])
	return total


func level(upgrade: StringName) -> int:
	return upgrades.get(upgrade, 0)


func upgrade_cost(upgrade: StringName) -> int:
	var costs: Array = UPGRADES[upgrade].costs
	var lv := level(upgrade)
	return costs[lv] if lv < costs.size() else -1


func buy_upgrade(upgrade: StringName) -> bool:
	var c := upgrade_cost(upgrade)
	if c < 0 or money < c:
		return false
	_spend(c)
	upgrades[upgrade] = level(upgrade) + 1
	stock_changed.emit()
	return true


# --- relics ------------------------------------------------------------------

func bonus(key: StringName) -> float:
	return bonuses.get(key, 0.0)


func set_bonuses(b: Dictionary) -> void:
	bonuses = b
	bonuses_changed.emit()


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
	return v * (0.85 + 0.3 * reputation) * (1.0 + bonus(&"fair_mult"))


## 1 = full flow of cats, 0 = nobody comes. Cheaper than fair doesn't add more.
func demand() -> float:
	var ratio := price / maxf(fair_price(), 1.0)
	return clampf((1.6 - ratio) / 0.6, 0.0, 1.0) * (1.0 + bonus(&"demand_mult"))


func serve_time() -> float:
	return 0.8 * pow(0.8, level(&"service"))


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
		line = "Needs %s..." % NEED_WORD[worst_kind]
	return {score = clampf(1.0 - penalty * PENALTY_PER_UNIT, 0.0, 1.0), line = line}


## Sells the next drink. quality < 1 comes from the hit bar; 0 = spilled, no money.
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

	var paid := roundi(price * (1.0 + bonus(&"price_mult")))
	var tip := roundi(price * TIP_MAX * _taste.score * quality * (1.0 + bonus(&"tip_mult")))
	var earned := paid + tip
	_spend(-earned)
	today.sold += 1
	today.revenue += earned
	today.tips += tip
	today.score_sum += _taste.score
	if _taste.line != "":
		today.complaints[_taste.line] = today.complaints.get(_taste.line, 0) + 1
	week_changed.emit(week_earned())
	return {money = earned, score = _taste.score, line = _taste.line}


func end_day(reason: StringName) -> Dictionary:
	today.ended_by = reason
	if today.sold > 0:
		# half memory, so one bad day doesn't empty the bar
		reputation = lerpf(reputation, today.score_sum / today.sold, 0.5)
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
	var days := WEEK - 1 if _open else WEEK
	for i in range(maxi(0, earnings.size() - days), earnings.size()):
		sum += earnings[i]
	return sum


func quota_progress() -> float:
	return clampf(float(week_earned()) / QUOTA, 0.0, 1.0)


## 0..1, grows with how strong the player is. Drives hit bar speed and loot.
func difficulty() -> float:
	return quota_progress()


func hit_params() -> Dictionary:
	var d := difficulty()
	var zone := 1.0 + bonus(&"hit_zone")
	return {
		speed = lerpf(120.0, 240.0, d) * maxf(0.3, 1.0 - bonus(&"hit_slow")),
		good_zone = minf(lerpf(0.40, 0.22, d) * zone, 0.9),
		perfect_zone = minf(lerpf(0.12, 0.05, d) * zone, 0.5),
		flip = _rng.randf() < 0.3 * d,
	}


## Relic for a hit bar result, or &"" when the tier earns nothing.
## Until the relic code lands the roll still happens, it just returns the rarity.
func grant_relic(tier: StringName) -> StringName:
	var luck := 0.3 * difficulty() + bonus(&"loot_luck")
	var rarity := &""
	match tier:
		&"perfect":
			rarity = &"epic" if _rng.randf() < 0.15 + luck else &"rare"
		&"good":
			rarity = &"rare" if _rng.randf() < 0.25 + luck else &"common"
		_:
			return &""
	var defs_path := "res://scripts/relics/relic_defs.gd"
	if not ResourceLoader.exists(defs_path):
		relic_won.emit(rarity)
		return rarity
	var id: StringName = load(defs_path).roll(rarity, _rng)
	if backpack:
		backpack.add_to_pocket(id)
	relic_won.emit(id)
	return id


# --- internals ---------------------------------------------------------------

func _spend(amount: int) -> void:
	money -= amount
	money_changed.emit(money)


func _reset_today() -> void:
	today = {sold = 0, revenue = 0, tips = 0, score_sum = 0.0, spilled = 0,
		walked = 0, specials_won = 0, specials_lost = 0, complaints = {}, ended_by = &""}


func _fill(drinks: int) -> void:
	glasses = maxi(glasses, drinks)
	for kind in recipe:
		var id: StringName = selected[kind]
		stock[id] = maxi(stock[id], drinks * recipe[kind])
	stock_changed.emit()
