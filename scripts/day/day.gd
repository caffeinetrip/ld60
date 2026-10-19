extends Node
## Runs one working day. Cats arrive by demand, the cat at the counter gets a drink,
## special cats get a minigame while the day stands still; relics and ingredients with
## a `proc` can pop one on their event too. Without a Customers node it falls back to a
## timer stand-in, so the loop is playable before the cats exist.

signal finished(report: Dictionary)

const SIM_WALK := 2.0
const BONUS_INTERVAL := 0.25

enum { HAPPY, SAD, ANGRY }		# same order as Cat.Mood

# what a relic says over the counter when it does its thing (placeholders)
const RELIC_TEXT := {
	&"pos_terminal": "Treat!", &"calculator": "Quick math!", &"receipt_printer": "Extra sale!",
	&"equalizer": "Smoothed out!", &"scoreboard": "x2!", &"pager": "+friend",
	&"boombox": "Big tip!", &"crt_tv": "TV tip!",
}
const RELIC_COLOR := Color("b497d6")
const RELIC_TEXT_STEP := 14		# px between relic words that pop at once (the older one is rising)
const BOSS_HUD_Y := -46			# over the big cat's ears
const BOSS_STAGE_LINE := "Not bad. Again!"
const RELIC_TOSS := preload("res://scripts/day/relic_toss.gd")
const TIERS: Array[StringName] = [&"perfect", &"good", &"meh", &"miss"]	# best first
const RELIC_LAYER := 17		# over the black bars, the HUD and the cats' speech

@export var machine_path: NodePath
@export var customers_path: NodePath
@export var minigames_path: NodePath
@export var counter := Vector2(158, 124)
@export var relic_spot := Vector2(162, 100)	# on the bar between the machine and the till

var running := false
var time := 0.0
var order := 0.0				# 0..1, the drink being made right now
var boss_stages: Array = Tune.BOSS_STAGES
var boss_tries := 0
var boss_hud: BossHud

var _machine: Node
var _customers: Node
var _cashier: Cashier
var _games: MiniGames
var _rng := RandomNumberGenerator.new()
var _spawn_in := 0.0
var _spawned := 0				# cats that want a drink, friends too
var _arrivals := 0				# cats the day planned (special slots count these)
var _served := 0
var _feedback_in := 4
var _serving := false
var _frozen := false
var _specials: Array[int] = []
var _street_day := false
var _homeless_today := 0
var _sim_homeless := false
var _generation := 0
var _sim_line: Array[StringName] = []
var _treats := 0				# next normal orders made at once (POS terminal, cash register)
var _said := 0					# relic words stacked over the counter right now
var _said_at := 0


func _ready() -> void:
	_machine = get_node_or_null(machine_path) if not machine_path.is_empty() else null
	_customers = get_node_or_null(customers_path)
	_games = get_node(minigames_path)
	_cashier = get_parent().get_node_or_null(^"Cafe/Props/Cashier") as Cashier
	if _customers:
		_customers.at_counter.connect(_on_at_counter)
	if _machine:
		_machine.whacked.connect(_on_machine_whacked)
	_rng.randomize()


func start() -> void:
	Game.start_day()
	Game.backpack.start_day(_rng)
	time = 0.0
	order = 0.0
	_spawn_in = 0.0	# the first cat is at the door as the day opens
	_spawned = 0
	_arrivals = 0
	_served = 0
	_feedback_in = _rng.randi_range(4, 6)
	_serving = false
	_frozen = false
	_treats = 0
	_sim_line.clear()
	_generation += 1
	_sim_homeless = false
	_street_day = Game.flags.get(&"newspaper", false)
	_homeless_today = 0
	if _customers:
		_customers.start_day(self)
	_specials = Game.director.special_slots(Game.drinks_left(), _rng)
	running = true
	Feel.play(&"day/start")
	_fire(&"day_start")


func _process(delta: float) -> void:
	Feel.fast = running and not get_tree().paused
	if not is_active():
		return
	time += delta
	_spawn_tick(delta)
	if not _serving:
		if _customers and _customers.front():
			_on_at_counter(_customers.front())
		elif not _sim_line.is_empty():
			_serve(_sim_line[0], null)
	_check_end()


func _spawn_tick(delta: float) -> void:
	if time >= Game.day_length():
		return
	if _spawned - _served >= Game.drinks_left():
		return
	if _customers and _customers.waiting() >= _customers.max_queue():
		return
	_spawn_in -= delta
	if _spawn_in > 0.0:
		return
	_spawn_in = Tune.ARRIVAL * _rng.randf_range(1.0 - Tune.ARRIVAL_JITTER, 1.0 + Tune.ARRIVAL_JITTER) / (1.0 + Game.mod(&"arrival_mult"))
	# every passer-by looks at the price; the ones who don't come in only show up in the report
	if _spawned > 0 and _rng.randf() >= arrival_demand():
		Game.walked_away()
		return
	var kind := &"special" if _specials.has(_arrivals) else &"normal"
	# the first street day surely brings one, as the third passer-by at the latest
	var due: bool = _homeless_today == 0 and _arrivals >= 2 and not Game.flags.has(&"street_cat_seen")
	if _street_day and not has_homeless() and (due or _rng.randf() < Tune.HOMELESS_CHANCE):
		_homeless_today += 1
		Game.flags[&"street_cat_seen"] = true
		kind = &"homeless"
	# a pager: a friend walks in right behind, if there's a drink and a spot in line for it
	var friend: bool = kind == &"normal" and _spawned + 1 - _served < Game.drinks_left() \
		and (not _customers or _customers.waiting() + 1 < _customers.max_queue()) \
		and Game.backpack.friend_roll(_rng)
	if kind != &"homeless":
		_spawned += 1
		_arrivals += 1
	_arrive(kind, friend)
	if friend:
		_spawned += 1
		_arrive(&"normal", true)
		_relic(&"pager")


func _arrive(kind: StringName, friend: bool) -> void:
	if _customers:
		_customers.spawn(kind, friend)
		return
	if kind == &"homeless":
		_sim_homeless = true
	var generation := _generation
	get_tree().create_timer(SIM_WALK, false).timeout.connect(func():
		if running and generation == _generation:
			_sim_line.append(&"friend" if friend else kind))


func is_active() -> bool:
	return running and not _frozen and not get_tree().paused


func open_time() -> float:
	return clampf(time / Game.day_length(), 0.0, 1.0)


## Cats in line, the one being served included.
func queue_size() -> int:
	if _customers:
		return _customers.waiting()
	return _sim_line.size()


func _on_at_counter(cat: Node) -> void:
	if is_active():
		_serve(cat.kind, cat)


func _serve(kind: StringName, cat: Node) -> void:
	if kind == &"homeless":
		return
	if _serving or not is_active():
		return
	_serving = true
	var sale: Dictionary
	var won: Array[StringName] = []
	var mood := HAPPY
	var friend: bool = _customers.is_friend(cat) if cat else kind == &"friend"
	var bill := {price = Game.price * (1.0 - Relics.FRIEND_DISCOUNT) if friend else float(Game.price)}
	bill.defer_bonus = true
	if kind == &"special":
		_face(Cashier.Row.WOW, 0.5)
		await _guide(&"special")
		var tries: Array[Dictionary] = [await _play(Tune.SPECIAL_GAME)]
		# the PC tower: sometimes a second go, its own roll for a relic
		if Game.backpack.double_roll(_rng):
			_relic(&"pc_tower", "Again!")
			tries.append(await _play(Tune.SPECIAL_GAME))
		var r: Dictionary = tries[0]
		for t in tries:
			if TIERS.find(t.tier) < TIERS.find(r.tier):
				r = t
		if is_instance_valid(cat):
			cat.minigame_completed = true
			cat.queue_redraw()
		bill.tier = r.tier
		bill.now = time
		_arcade(r.tier)
		sale = Game.sell_next(0.0 if r.tier == &"miss" else r.quality, bill)
		for t in tries:
			var id := Game.grant_relic(t.tier)
			if id != &"":
				won.append(id)
		if r.tier == &"perfect" or r.tier == &"good":
			Game.today.specials_won += 1
		else:
			Game.today.specials_lost += 1
			mood = SAD
	else:
		# a treated cat gets its drink at once
		var treated := _treats > 0
		if treated:
			_treats -= 1
		else:
			Feel.play(&"bar/pour", counter)
			_busy(Cashier.Row.POUR)
			if Game.backpack.order_time(bill.price, Game.serve_time()) < Game.serve_time():
				_relic(&"calculator")
		order = 0.0
		while order < 1.0 and not treated:
			await get_tree().process_frame
			if not running:
				_serving = false
				_busy(Cashier.Row.IDLE)
				return
			if is_active():
				order += get_process_delta_time() / Game.backpack.order_time(bill.price, Game.serve_time())
		order = 0.0
		_busy(Cashier.Row.IDLE)
		bill.now = time
		sale = Game.sell_next(1.0, bill)
		mood = HAPPY if sale.score >= 0.7 else (SAD if sale.score >= 0.35 else ANGRY)
		if not treated:
			var n := Game.backpack.treats(bill.price, _rng)
			if n > 0:
				_treats = maxi(_treats, n)
				if n == 1:
					_relic(&"pos_terminal")
				else:
					_relic(&"cash_register", "Treat x%d!" % n)

	_pay(sale.money)
	_face(Cashier.Row.HAPPY if mood == HAPPY else Cashier.Row.SAD)
	var bonus_generation := _generation
	var activation := 0
	for payout in sale.get("payouts", []):
		var delay := BONUS_INTERVAL
		while delay > 0.0:
			await get_tree().process_frame
			if not running or bonus_generation != _generation:
				return
			if is_active():
				delay -= get_process_delta_time()
		activation += 1
		Game.pay_sale_bonus(payout)
		_pay(payout.money)
		_relic(payout.id, "Extra x%d!" % activation, false)
	for id in won:
		var generation := _generation
		await get_tree().create_timer(0.95, false).timeout
		if not running or generation != _generation:
			return
		Feel.play(&"relic/get", counter)
		_face(Cashier.Row.WOW, 0.8)
		await _toss_relic(id)
	for id in sale.fired:
		if id not in [&"receipt_printer", &"equalizer", &"scoreboard"]:
			_relic(id, "", false)
	_feedback_in -= 1
	if _feedback_in <= 0:
		if cat and sale.line != "":
			cat.say(sale.line)
		_feedback_in = _rng.randi_range(4, 6)
	await _fire(&"serve")
	_served += 1
	if cat:
		_customers.release_front(mood)
	elif not _sim_line.is_empty():
		_sim_line.pop_front()
	_serving = false


## Plays the minigame of every proc on `event` that rolls its chance, pays its reward.
func _fire(event: StringName) -> void:
	for p in Game.procs(event):
		if _rng.randf() >= p.get("chance", 1.0):
			continue
		var r: Dictionary = await _play(p.get("game", Tune.SPECIAL_GAME))
		var quality: float = r.quality
		if Game.backpack.minigame_x2(r.tier, _rng):
			quality *= 2.0
			_relic(&"scoreboard")
		_pay(Game.reward(p.get("reward", {}), quality))


## A special cat's minigame: an arcade may roll and set a neighbor's power for the day by its tier.
func _arcade(tier: StringName) -> void:
	if not Game.backpack.arcade_roll(_rng):
		return
	var hit := Game.backpack.arcade_apply(tier, _rng)
	if not hit.is_empty():
		_relic(&"arcade", "x%d %s!" % [hit.mult, Relics.get_def(hit.id).name])


## A relic did its thing: counted for the report (sales count their own relics), its
## sound, a word over the counter - RELIC_TEXT unless `text` says otherwise.
func _relic(id: StringName, text := "", count := true) -> void:
	if count:
		Game.relic_worked(id)
	Feel.play(StringName("relic/" + String(id)), counter)
	# words from the same moment stack up instead of covering each other
	if Time.get_ticks_msec() - _said_at > 400:
		_said = 0
	_said_at = Time.get_ticks_msec()
	Feel.text(text if text else RELIC_TEXT.get(id, "!"), counter + Vector2(0, -12 - RELIC_TEXT_STEP * _said), RELIC_COLOR)
	_said += 1


func _on_machine_whacked() -> void:
	if Game.backpack.machine_whacked(time):
		_relic(&"crt_tv", "TV on!", false)


## A won relic rises from the cat into the black band and shows itself there (the day
## stands still meanwhile), then floats onto the bar; its name pops in gold where it lands.
func _toss_relic(id: StringName) -> void:
	var layer := CanvasLayer.new()
	layer.layer = RELIC_LAYER
	get_parent().add_child(layer)
	var item := RELIC_TOSS.new()
	item.id = id
	item.tree_exited.connect(layer.queue_free)
	layer.add_child(item)
	_frozen = true
	item.fly(counter + Vector2(0, -8), relic_spot)
	await item.shown
	_frozen = false


## The sister explains a new thing the first time it comes up, the day stands still.
func _guide(id: StringName) -> void:
	var dialogue := get_node_or_null(^"/root/Dialogue")
	if dialogue == null or Game.endless or Game.flags.has(id):
		return
	Game.flags[id] = true
	_frozen = true
	await dialogue.play(id)
	_frozen = false


## Pause the day clock and arrivals while the cafe keeps animating.
func _play(id: StringName, params := {}) -> Dictionary:
	_frozen = true
	_busy(Cashier.Row.FOCUS)
	var r: Dictionary = await _games.play(id, params)
	_watched(r.tier)
	_frozen = false
	return r


## A minigame is over: the hero stops watching it and shows how it went.
func _watched(tier: StringName) -> void:
	_busy(Cashier.Row.IDLE)
	if _cashier:
		_cashier.react(tier)


func _busy(row: Cashier.Row) -> void:
	if _cashier:
		_cashier.busy = row


func _face(row: Cashier.Row, seconds := 1.2) -> void:
	if _cashier:
		_cashier.show_mood(row, seconds)


func _pay(cash: int) -> void:
	if cash > 0:
		var register := get_parent().get_node_or_null("Cafe/Props/Counter/Register1") as Node2D
		var intake := register.to_global(Vector2(4, -3)) if register else counter
		Feel.gold_gain(cash, counter, intake)


func _check_end() -> void:
	if _serving:
		return
	if Game.drinks_left() == 0:
		_end(&"stock")
	elif time >= Game.day_length() and (_spawned == _served or has_homeless()):
		_end(&"time")
	elif Game.demand() <= 0.0 and time >= Tune.NOBODY_GIVES_UP:
		_end(&"nobody")


func _end(reason: StringName) -> void:
	running = false
	_busy(Cashier.Row.IDLE)
	if _machine:
		_machine.reset()
	if _customers:
		_customers.clear_day()
	Feel.play(&"day/end")
	finished.emit(Game.end_day(reason))


## The quota is met: one big cat, `boss_stages` one after another, a minigame each
## round. A miss costs a life; out of lives the sister cheers you up and it starts over.
## Returns on the win, `boss_tries` counts the tries.
func boss_fight() -> void:
	var boss: Cat = null
	if _customers:
		boss = _customers.spawn(&"boss")
		await _customers.at_counter
	var at := boss.global_position if boss else counter
	Feel.play(&"boss/enter", at)
	_face(Cashier.Row.WOW, 1.0)
	boss_hud = BossHud.new()
	boss_hud.position = Vector2(0, BOSS_HUD_Y) if boss else counter + Vector2(0, BOSS_HUD_Y)
	(boss if boss else self).add_child(boss_hud)
	boss_tries = 0
	while true:
		boss_tries += 1
		if await _boss_try(boss, at):
			break
		Feel.play(&"boss/laugh", at)
		_face(Cashier.Row.SAD, 1.6)
		if boss:
			boss.say("Hah!")
		await get_tree().create_timer(Tune.BOSS_PAUSE, false).timeout
		var dialogue := get_node_or_null(^"/root/Dialogue")
		if dialogue:
			await dialogue.play(&"boss_lose")
	boss_hud.queue_free()
	_face(Cashier.Row.HAPPY, 1.6)
	if _customers:
		_customers.release_front(HAPPY)


## One try from stage 1 with full lives. True when the boss is satisfied.
func _boss_try(boss: Cat, at: Vector2) -> bool:
	var lives := Tune.BOSS_LIVES
	var stages := boss_stages.size()
	for i in stages:
		var stage: Dictionary = boss_stages[i]
		var hp: int = stage.hp
		if i == 0:
			boss_hud.setup(hp, lives)
		else:
			boss_hud.max_hp = hp
			boss_hud.set_hp(hp)
		boss_hud.set_stage(i, stages)
		var round_i := 0
		while hp > 0:
			_busy(Cashier.Row.FOCUS)
			var r: Dictionary = await _games.play(stage.game, {boss = true,
				pace = stage.pace + round_i * stage.speedup,
				flip = stage.get("flip", false) and round_i % 2 == 1})
			_watched(r.tier)
			round_i += 1
			if r.tier == &"miss":
				lives -= 1
				boss_hud.set_lives(lives)
				Feel.text("MISS", at + Vector2(0, -20), Color("e05a5a"))
				if lives <= 0:
					return false
			elif r.tier != &"meh":
				var dmg := roundi(stage.damage if stage.get("fixed_damage", false) else r.quality * stage.damage)
				hp = maxi(hp - dmg, 0)
				boss_hud.set_hp(hp)
				Feel.text("-%d" % dmg, at + Vector2(0, -20), Color("e05a5a"))
		if i < stages - 1:
			Feel.play(&"boss/phase", at)
			if boss:
				boss.modulate = Color(2, 2, 2)
				boss.create_tween().tween_property(boss, "modulate", Color.WHITE, 0.3)
			await get_tree().create_timer(Tune.BOSS_PAUSE, false).timeout
			if boss:
				boss.say(BOSS_STAGE_LINE)
	return true


func has_homeless() -> bool:
	return _customers.has_homeless() if _customers else _sim_homeless


func arrival_demand() -> float:
	return Game.demand() * (1.0 - Tune.HOMELESS_SCARE if has_homeless() else 1.0)


func kick_front() -> void:
	await kick(_customers.front() if _customers else null)


func kick(cat: Cat = null) -> void:
	if not is_active():
		return
	if _customers:
		if not is_instance_valid(cat) or cat.kind != &"homeless" or not _customers._line.has(cat):
			return
	elif _sim_line.is_empty() or _sim_line[0] != &"homeless":
		return
	# the cat reacts the moment the click lands, not when the gauge closes
	var hit := func(r: Dictionary) -> void:
		if running and _customers:
			_customers.kick_result(cat, r.tier)
	var result: Dictionary = await _play(&"kick" if MiniGames.GAMES.has(&"kick") else &"hit_bar", {on_result = hit})
	if not running or _customers:
		return
	if result.tier == &"perfect" or result.tier == &"good":
		_sim_line.pop_front()
		_sim_homeless = false
		Feel.play(&"homeless/kick", counter)
		Feel.text("Out!", counter)
	else:
		Feel.play(&"homeless/" + String(result.tier), counter)
