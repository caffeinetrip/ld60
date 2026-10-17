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
	check(await wait_for(func(): return bar._running and bar._x >= x, 10.0), "cursor reached %d" % x)
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
	await wait_for(func(): return bar._running, 2.0)
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
