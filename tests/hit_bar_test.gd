extends "res://tests/suite.gd"

const MID := 90.0
const AT := Vector2(160, 88)

var layer: CanvasLayer
var bar: HitBar
var result := {}


func before_each() -> void:
	layer = CanvasLayer.new()
	bar = HitBar.new()
	layer.add_child(bar)
	tree.root.add_child(layer)
	result = {}


func after_each() -> void:
	layer.free()


func _start(params: Dictionary) -> void:
	result.merge(await bar.run(params))


## Clicks once the cursor passes `x`, then waits for the bar to close.
func _hit_at(x: float, params := {speed = 60.0}) -> void:
	_start(params)
	check(await wait_for(func(): return bar.running and bar._x >= x, 10.0), "cursor reached %d" % x)
	click(AT)
	check(await wait_for(func(): return not result.is_empty(), 5.0), "bar closed")


func test_no_click_is_a_miss() -> void:
	_start({speed = 600.0})
	check(bar.visible, "shown")
	check(await wait_for(func(): return not result.is_empty(), 5.0), "bar closed")
	eq(result, {tier = &"miss", quality = 0.0}, "result")
	check(not bar.visible, "hidden")
	eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "lets clicks through")


func test_centre_is_perfect() -> void:
	await _hit_at(MID - 1.0)
	eq(result.get("tier"), &"perfect", "tier")
	near(result.get("quality", 0.0), 1.0, "quality")


func test_good() -> void:
	await _hit_at(MID * 1.2)
	eq(result.get("tier"), &"good", "tier")
	var q: float = result.get("quality", 0.0)
	check(q >= 0.6 and q <= 0.9, "quality %.2f in 0.6..0.9" % q)


func test_meh() -> void:
	await _hit_at(MID * 1.8)
	eq(result.get("tier"), &"meh", "tier")
	var q: float = result.get("quality", 0.0)
	check(q >= 0.1 and q <= 0.5, "quality %.2f in 0.1..0.5" % q)


func test_flip_runs_backwards() -> void:
	_start({speed = 60.0, flip = true})
	await wait_for(func(): return bar.running, 2.0)
	var x := bar._x
	await frames(5)
	check(bar._x < x, "moves left")
	await wait_for(func(): return absf(bar._x - MID) < 1.0, 10.0)
	click(AT)
	await wait_for(func(): return not result.is_empty(), 5.0)
	eq(result.get("tier"), &"perfect", "tier")


func test_click_before_start_is_ignored() -> void:
	_start({speed = 600.0})
	click(AT)
	check(result.is_empty(), "preroll click did nothing")
	await wait_for(func(): return not result.is_empty(), 5.0)
	eq(result.get("tier"), &"miss", "still runs out")


func test_curve() -> void:
	bar._setup({})
	near(bar.speed, 120.0, "slow at start")
	near(bar.good_zone, 0.4, "wide at start")
	near(bar.perfect_zone, 0.12, "perfect at start")
	eq(bar._dir, 1, "no flip at start")
	bar.difficulty = 1.0
	bar._setup({})
	near(bar.speed, 240.0, "fast at the top")
	near(bar.good_zone, 0.22, "narrow at the top")
	near(bar.perfect_zone, 0.05, "perfect at the top")
	bar.pace = 0.3
	bar.zone = 6.0
	bar._setup({})
	near(bar.speed, 72.0, "pace")
	near(bar.good_zone, 0.9, "good caps")
	near(bar.perfect_zone, 0.3, "perfect x6")
	bar._setup({speed = 10.0, flip = true})
	near(bar.speed, 10.0, "own params win")
	eq(bar._dir, -1, "flip")


func test_host_applies_mods() -> void:
	var games := MiniGames.new()
	layer.add_child(games)
	Game.earnings.assign([1500])
	Game.set_mods(&"test", {hit_slow = 0.9, hit_zone = 5.0})
	var got := {}
	var play := func(): got.merge(await games.play(&"hit_bar", {pace = 2.0}))
	play.call()
	check(games.current is HitBar, "hit bar is up")
	var hb: HitBar = games.current
	near(hb.difficulty, 1.0, "run difficulty")
	near(hb.pace, 0.6, "pace x slow mod, floored at 0.3")
	near(hb.zone, 6.0, "zone mod")
	near(hb.speed, 144.0, "240 x 0.6")
	check(await wait_for(func(): return not got.is_empty(), 10.0), "ran out")
	eq(got.get("tier"), &"miss", "no click")
	check(games.current == null, "freed")
