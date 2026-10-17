extends Node
## Runs one working day. Cats arrive by demand, the cat at the counter gets a drink,
## special cats get a minigame while the day stands still; relics and ingredients with
## a `proc` can pop one on their event too. Without a Customers node it falls back to a
## timer stand-in, so the loop is playable before the cats exist.

signal finished(report: Dictionary)

const SIM_WALK := 2.0

enum { HAPPY, SAD, ANGRY }		# same order as Cat.Mood

@export var customers_path: NodePath
@export var minigames_path: NodePath
@export var counter := Vector2(205, 124)

var running := false
var time := 0.0
var order := 0.0				# 0..1, the drink being made right now

var _customers: Node
var _games: MiniGames
var _rng := RandomNumberGenerator.new()
var _spawn_in := 0.0
var _spawned := 0
var _served := 0
var _serving := false
var _frozen := false
var _specials: Array[int] = []
var _sim_line: Array[StringName] = []


func _ready() -> void:
	_customers = get_node_or_null(customers_path)
	_games = get_node(minigames_path)
	if _customers:
		_customers.at_counter.connect(_on_at_counter)
	_rng.randomize()


func start() -> void:
	Game.start_day()
	time = 0.0
	order = 0.0
	_spawn_in = 0.3
	_spawned = 0
	_served = 0
	_serving = false
	_frozen = false
	_sim_line.clear()
	_specials = Game.director.special_slots(Game.drinks_left(), _rng)
	running = true
	Feel.play(&"day/start")
	_fire(&"day_start")


func _process(delta: float) -> void:
	if not running or _frozen:
		return
	time += delta
	_spawn_tick(delta)
	if not _serving and not _sim_line.is_empty():
		_serve(_sim_line[0], null)
	_check_end()


func _spawn_tick(delta: float) -> void:
	if time >= Tune.MAX_DAY:
		return
	if _spawned - _served >= Game.drinks_left():
		return
	if _customers and _customers.waiting() >= _customers.max_queue():
		return
	_spawn_in -= delta
	if _spawn_in > 0.0:
		return
	_spawn_in = Tune.ARRIVAL * _rng.randf_range(1.0 - Tune.ARRIVAL_JITTER, 1.0 + Tune.ARRIVAL_JITTER)
	# every passer-by looks at the price; the ones who don't come in only show up in the report
	if _rng.randf() >= Game.demand():
		Game.today.walked += 1
		return
	var kind := &"special" if _specials.has(_spawned) else &"normal"
	_spawned += 1
	if _customers:
		_customers.spawn(kind)
	else:
		get_tree().create_timer(SIM_WALK, false).timeout.connect(func():
			if running:
				_sim_line.append(kind))


func open_time() -> float:
	return clampf(time / Tune.MAX_DAY, 0.0, 1.0)


## Cats in line, the one being served included.
func queue_size() -> int:
	if _customers:
		return _customers.waiting()
	return _sim_line.size()


func _on_at_counter(cat: Node) -> void:
	if running:
		_serve(cat.kind, cat)


func _serve(kind: StringName, cat: Node) -> void:
	_serving = true
	var sale: Dictionary
	var mood := HAPPY
	if kind == &"special":
		var r: Dictionary = await _play(Tune.SPECIAL_GAME)
		sale = Game.sell_next(0.0 if r.tier == &"miss" else r.quality)
		if Game.grant_relic(r.tier) != &"":
			Game.today.specials_won += 1
			Feel.play(&"relic/get", counter)
			Feel.text("New relic!", counter + Vector2(0, -12), Color("b497d6"))
		else:
			Game.today.specials_lost += 1
			mood = SAD
	else:
		Feel.play(&"bar/pour", counter)
		order = 0.0
		await create_tween().tween_property(self, "order", 1.0, Game.serve_time()).finished
		order = 0.0
		sale = Game.sell_next()
		mood = HAPPY if sale.score >= 0.7 else (SAD if sale.score >= 0.35 else ANGRY)

	_pay(sale.money)
	if cat and sale.line != "":
		cat.say(sale.line)
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
		_pay(Game.reward(p.get("reward", {}), r.quality))


## A minigame with the day frozen.
func _play(id: StringName, params := {}) -> Dictionary:
	_frozen = true
	var r: Dictionary = await _games.play(id, params)
	_frozen = false
	return r


func _pay(cash: int) -> void:
	if cash > 0:
		Feel.play(&"bar/coin", counter)
		Feel.text("+$%d" % cash, counter, Color("ffd34d"))


func _check_end() -> void:
	if _serving:
		return
	if Game.drinks_left() == 0:
		_end(&"stock")
	elif time >= Tune.MAX_DAY and _spawned == _served:
		_end(&"time")
	elif Game.demand() <= 0.0 and time >= Tune.NOBODY_GIVES_UP:
		_end(&"nobody")


func _end(reason: StringName) -> void:
	running = false
	if _customers:
		_customers.send_home()
	Feel.play(&"day/end")
	finished.emit(Game.end_day(reason))


## The quota is met: one big cat, minigame after minigame until it's satisfied. Can't be lost yet.
func boss_fight() -> void:
	if _customers:
		_customers.spawn(&"boss")
		await _customers.at_counter
	Feel.play(&"boss/enter", counter)
	var hp := Tune.BOSS_HP
	var round_i := 0
	while hp > 0:
		var r: Dictionary = await _games.play(Tune.SPECIAL_GAME, {
			pace = 1.0 + round_i * Tune.BOSS_SPEEDUP, flip = round_i % 2 == 1})
		var dmg := roundi(r.quality * Tune.BOSS_DAMAGE)
		hp -= dmg
		Feel.text("-%d" % dmg if dmg > 0 else "MISS", counter + Vector2(0, -20), Color("e05a5a"))
		round_i += 1
	Feel.play(&"game/win", counter)
	if _customers:
		_customers.release_front(HAPPY)
