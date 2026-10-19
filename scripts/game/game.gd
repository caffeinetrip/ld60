extends Node
## Run state and the economy rules. Pure model: no nodes, no timers. The day
## controller asks it what happens, the night panel buys through it.
## Numbers live in Tune, content in Ingredients / Relics / Tune.UPGRADES.
##
## The bar sells one drink a day: one picked ingredient per kind (alcohol, mixer,
## flavor) and a recipe in units per glass. Stock is counted in units per ingredient + glasses;
## the night's restock tops the shelf up to `target` drinks, buying only the units and
## glasses missing for the current recipe (the scarcest one decides). Every set of ingredients has one right recipe, the same
## every day, like in a real bar (doses in Ingredients) - the closer the drink, the
## bigger the tip and the better tomorrow's reputation.
##
## Mods: everything that changes a number (upgrades, relics, later events) is a source
## of {key: value} in set_mods(); mod(key) is the sum over sources, 0.1 = +10 %.
## Keys: price_mult tip_mult demand_mult fair_mult discount capacity
## serve_speed hit_slow hit_zone loot_luck special_mult arrival_mult
## day_length grid whack cool_fast

signal run_reset

signal money_changed(money: int)
signal stock_changed
signal week_changed(earned: int)
signal day_started(day: int)
signal day_changed(day: int)
signal day_ended(report: Dictionary)
signal mods_changed
signal relic_won(id: StringName)

var money := 0
var day := 1					# the day being played, or prepared for at night
var price := 0
var glasses := 0
var stock := {}				# ingredient id -> units
var unlocked := {}				# ingredient id -> true
var selected := {}				# Kind -> ingredient id on sale
var recipe := {}				# Kind -> units per glass
var target := 0				# drinks the restock fills the shelf up to
var earnings: Array[int] = []	# revenue of every finished day
var sold_total := 0			# drinks sold this run
var flags := {}
var upgrades := {}				# upgrade id -> level
var mods := {}					# key -> summed value
var reputation := 0.0			# blended average score, 0..1
var backpack := Backpack.new()
var director: Director
var endless := false			# after the boss: the run goes on, no story, no boss, no talks

var today := {}
var last_report := {}

var _sources := {}				# source -> {key: value}
var _left := 0					# drinks left to sell today
var _open := false				# a day is running
var _taste := {}				# today's drink vs ideal, same for every glass
var _rng := RandomNumberGenerator.new()
var _started := 0				# ticks usec of new_run()
var _debug_jumping := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	backpack.changed.connect(func(): set_mods(&"relics", backpack.stats()))
	new_run()


func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		debug_bonus_chain.call_deferred()
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		get_viewport().set_input_as_handled()
		debug_day_five.call_deferred()
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		get_viewport().set_input_as_handled()
		debug_after_boss.call_deferred()


## F3: the boss is just beaten, the game goes on from there.
func debug_after_boss() -> void:
	if _debug_jumping:
		return
	_debug_jumping = true
	var tree := get_tree()
	var dialogue := tree.root.get_node_or_null(^"Dialogue")
	if dialogue and dialogue.is_open():
		dialogue.finish_now()
		await dialogue.finished
	tree.paused = false
	Engine.time_scale = 1.0
	set_meta(&"debug_after_boss", true)
	tree.change_scene_to_file("res://scenes/main.tscn")
	_debug_jumping = false


## Fresh stocked test run; rebuilding the scene also clears customers and minigames.
func debug_day_five(bonus_test := false) -> void:
	if _debug_jumping or not OS.is_debug_build():
		return
	_debug_jumping = true
	var tree := get_tree()
	var old_scene := tree.current_scene
	if old_scene:
		old_scene.free()
	var dialogue := tree.root.get_node_or_null(^"Dialogue")
	if dialogue and dialogue.is_open():
		dialogue.finish_now()
		await dialogue.finished
	tree.paused = false
	Engine.time_scale = 1.0
	new_run()
	day = 1 if bonus_test else 5
	if bonus_test:
		price = 20
		recipe = ideal()
		for id in stock:
			stock[id] = 200
		glasses = 100
		set_mods(&"debug_bonus", {fair_mult = 10.0, serve_speed = 1.0})
		backpack.place(&"receipt_printer", Vector2i(0, 0), 0)
		backpack.place(&"amplifier", Vector2i(0, 1), 0)
		set_meta(&"debug_bonus_chain", true)
	# Consume earlier story beats so the debug shift leads straight to its own story.
	for beat in director.beats_due():
		if beat.has("event"):
			flags[beat.event] = true
			set_mods(beat.event, Tune.EVENTS.get(beat.event, {}))
	set_meta(&"debug_start_day", true)
	tree.change_scene_to_file("res://scenes/main.tscn")
	_debug_jumping = false


## F5 in the game: a stocked shift with a boosted printer and no special interruptions.
func debug_bonus_chain() -> void:
	await debug_day_five(true)


func new_run() -> void:
	endless = false
	money = Tune.START_MONEY
	day = 1
	target = Tune.START_TARGET
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
	sold_total = 0
	flags.clear()
	_sources.clear()
	mods.clear()
	upgrades.clear()
	backpack.clear()
	last_report = {}
	_left = 0
	_open = false
	director = Director.new()
	_started = Time.get_ticks_usec()
	_reset_today()
	run_reset.emit()


## Real seconds since the run started: pauses, dialogues and the night count too.
func play_time() -> float:
	return (Time.get_ticks_usec() - _started) / 1000000.0


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


## What the shelf lacks for `drinks` of the current recipe: ingredient id (or
## &"glass") -> units. Empty when it already makes that many.
func restock_needs(drinks: int) -> Dictionary:
	var out := {}
	for kind in recipe:
		var id: StringName = selected[kind]
		var need: int = drinks * recipe[kind] - stock[id]
		if recipe[kind] > 0 and need > 0:
			out[id] = need
	if drinks > glasses:
		out[&"glass"] = drinks - glasses
	return out


## Price of topping the shelf up to `drinks`, 0 when nothing is missing.
func restock_cost(drinks: int) -> int:
	var total := 0
	var needs := restock_needs(drinks)
	for id in needs:
		total += needs[id] * (Tune.GLASS_COST if id == &"glass" else unit_cost(id))
	return total


func restock(drinks: int) -> bool:
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
	var def: Dictionary = Tune.UPGRADES[upgrade]
	if def.has("requires") and not flags.has(def.requires):
		return false
	var c := upgrade_cost(upgrade)
	if c < 0 or money < c:
		return false
	_spend(c)
	upgrades[upgrade] = level(upgrade) + 1
	_apply_upgrades()
	stock_changed.emit()
	return true


## Takes the last level back and pays back what it cost. A smaller backpack drops what
## no longer fits into the pocket.
func sell_upgrade(upgrade: StringName) -> bool:
	var lv := level(upgrade)
	if lv <= 0:
		return false
	var refund: int = Tune.UPGRADES[upgrade].costs[lv - 1]
	if lv == 1:
		upgrades.erase(upgrade)
	else:
		upgrades[upgrade] = lv - 1
	_apply_upgrades()
	backpack.fit()
	_spend(-refund)
	stock_changed.emit()
	return true


func _apply_upgrades() -> void:
	var sum := {}
	for id in upgrades:
		var per: Dictionary = Tune.UPGRADES[id].mods
		for key in per:
			sum[key] = sum.get(key, 0.0) + per[key] * upgrades[id]
	set_mods(&"upgrades", sum)


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


func day_length() -> float:
	return Tune.MAX_DAY + mod(&"day_length")


func earn_passive(amount: int) -> void:
	if not _open or amount <= 0:
		return
	today.passive += amount
	_earn(amount)


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


const OK_LINE := "It's ok."

## Today's drink against the ideal: {score 0..1, line = what a cat says}. One unit off
## only gets "It's ok.", further off the cats say what's wrong.
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
	if penalty == 1:
		line = OK_LINE	# close, but not the best: no hint which way
	elif worst > 0:
		line = "Too much %s!" % what
	elif worst < 0 and recipe[worst_kind] > 0:
		line = "More %s, please." % what
	elif worst < 0:
		line = "Needs %s..." % Ingredients.KIND_NEED[worst_kind]
	return {score = clampf(1.0 - penalty * Tune.PENALTY_PER_UNIT, 0.0, 1.0), line = line}


## Sells the next drink. quality < 1 comes from a minigame; 0 = spilled, no money.
## `order` is for the relics: {price (what this cat pays, a friend pays less), tier (a
## special cat's minigame tier), now (day time)}. Returns {money, score, line, fired} -
## fired = the relics that added something.
func sell_next(quality := 1.0, order := {}) -> Dictionary:
	var fired: Array[StringName] = []
	if _left <= 0:
		return {money = 0, score = 0.0, line = "", fired = fired}
	_left -= 1
	glasses -= 1
	for kind in recipe:
		stock[selected[kind]] -= recipe[kind]
	stock_changed.emit()

	var cost: float = order.get("price", float(price))
	var gold := cost * Tune.GOLD_MULT
	var best_tip := gold * Tune.TIP_MAX * (1.0 + mod(&"tip_mult"))
	if quality <= 0.0:
		today.spilled += 1
		today.lost += gold * (1.0 + mod(&"price_mult")) + best_tip
		return {money = 0, score = 0.0, line = "", fired = fired}

	var paid := roundi(gold * (1.0 + mod(&"price_mult")))
	var tip := roundi(best_tip * _taste.score * quality)
	today.lost += maxf(0.0, best_tip - tip)
	var perfect := gold * (1.0 + mod(&"price_mult")) + gold * Tune.TIP_MAX * (1.0 + mod(&"tip_mult"))
	var r := backpack.order_extras({price = cost, money = paid + tip, score = _taste.score,
		tier = order.get("tier", &""), perfect_money = perfect, now = order.get("now", 0.0)}, _rng)
	var deferred: bool = order.get("defer_bonus", false)
	var immediate: int = r.money
	if deferred:
		for payout in r.payouts:
			immediate -= payout.money
	_earn(immediate)
	today.sold += 1
	today.tips += tip + r.tip
	today.score_sum += _taste.score
	if _taste.line != "":
		today.complaints[_taste.line] = today.complaints.get(_taste.line, 0) + 1
	for id in r.fired:
		if not deferred or id not in [&"receipt_printer", &"equalizer", &"scoreboard"]:
			relic_worked(id)
	return {money = immediate, score = _taste.score, line = _taste.line, fired = r.fired,
		payouts = r.payouts if deferred else []}


func pay_sale_bonus(payout: Dictionary) -> void:
	_earn(payout.money)
	relic_worked(payout.id)


## Counts a relic that did its thing today (the report and the balance bot read it).
func relic_worked(id: StringName) -> void:
	today.relics[id] = today.relics.get(id, 0) + 1


## A passer-by didn't like the price.
func walked_away() -> void:
	today.walked += 1
	today.lost += price * Tune.GOLD_MULT


## The first days forgive: what mistakes cost comes back at night, reputation only rises.
func safe() -> bool:
	return not endless and day <= Tune.SAFE_DAYS


func end_day(reason: StringName) -> Dictionary:
	today.ended_by = reason
	today.glasses_left = glasses
	if today.sold > 0:
		var score: float = today.score_sum / today.sold
		if not safe() or score > reputation:
			reputation = lerpf(reputation, score, Tune.REP_MEMORY)
	if safe() and roundi(today.lost) > 0:
		today.refund = roundi(today.lost)
		_spend(-today.refund)
	earnings.append(today.revenue)
	sold_total += today.sold
	_left = 0
	_open = false
	last_report = today.duplicate(true)
	_reset_today()
	day_ended.emit(last_report)
	week_changed.emit(week_earned())
	return last_report


## The night begins: the calendar turns. Not in end_day, so the closing banner still
## shows the day that just ended.
func next_day() -> void:
	day += 1
	day_changed.emit(day)


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


## A special cat drops a relic RELIC_CHANCE of the time whatever the tier (the tier picks
## the rarity), and the first one from day EPIC_DAY on is surely epic. &"" = nothing this
## time. Lands in the pocket.
func grant_relic(tier: StringName) -> StringName:
	var epic := day >= Tune.EPIC_DAY and not flags.has(&"epic_given")
	if not epic and _rng.randf() >= Tune.RELIC_CHANCE:
		return &""
	var roll: Array = Tune.LOOT.get(tier, Tune.LOOT[&"miss"])
	var luck := Tune.LOOT_LUCK * difficulty() + mod(&"loot_luck")
	var rarity: StringName = roll[1] if _rng.randf() < roll[2] + luck else roll[0]
	if epic:
		flags[&"epic_given"] = true
		rarity = &"epic"
	var id := Relics.roll(rarity, _rng)
	# the PC Tower wins every hit bar: not before LATE_DAY, another of its rarity instead
	while Tune.LATE_RELICS.has(id) and day < Tune.LATE_DAY:
		id = Relics.roll(rarity, _rng)
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
	var cash := roundi(what.get("money", 0) * quality * Tune.GOLD_MULT)
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
	today = {sold = 0, revenue = 0, passive = 0, tips = 0, score_sum = 0.0, spilled = 0, lost = 0.0, refund = 0,
		walked = 0, specials_won = 0, specials_lost = 0, complaints = {}, relics = {}, ended_by = &""}


## Tops the shelf up to `drinks` for free.
func _fill(drinks: int) -> void:
	var needs := restock_needs(drinks)
	for id in needs:
		if id == &"glass":
			glasses += needs[id]
		else:
			stock[id] += needs[id]
	stock_changed.emit()
