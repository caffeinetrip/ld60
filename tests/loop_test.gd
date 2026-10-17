extends "res://tests/suite.gd"
## The real main scene: day by itself, night panel, next day, boss, win.

const A := Ingredients.Kind.ALCOHOL
const M := Ingredients.Kind.MIXER
const F := Ingredients.Kind.FLAVOR

var main: Node
var day: Node
var night: Control
var bar: HitBar
var auto_hit := false


func before_each() -> void:
	auto_hit = false
	tree.process_frame.connect(_auto_hit)


func after_each() -> void:
	tree.process_frame.disconnect(_auto_hit)
	if main:
		main.free()
		main = null


func _open() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	tree.current_scene = main
	day = main.get_node("Day")
	night = main.get_node("UI/NightPanel")
	bar = main.get_node("UI/HitBar")


## Plays every hit bar like a pro.
func _auto_hit() -> void:
	if auto_hit and bar and bar._running and absf(bar._x - HitBar.BAR.size.x * 0.5) <= 3.0:
		click(Vector2(160, 88))


func _night_comes(seconds := 90.0) -> bool:
	return await wait_for(func(): return night.visible, seconds)


func test_first_day() -> void:
	_open()
	check(await wait_for(func(): return day.running, 1.0), "day starts by itself")
	check(not night.visible, "no panel during the day")
	check(await _night_comes(), "night comes")
	var r := Game.last_report
	eq(r.ended_by, &"stock", "sold out")
	eq(r.sold, 7, "normal cats")
	eq(r.spilled, 1, "missed special spills")
	eq(r.specials_lost, 1, "special lost")
	eq(Game.money, 120 + r.revenue, "money")
	eq(Game.day, 2, "day 2 next")
	var report: String = night._report.text
	check(report.contains("Day 1 ended: Out of drinks"), "report: " + report)
	check(report.contains("Sold 7"), "report: " + report)
	var hud: String = main.get_node("UI/HUD")._left.text
	check(hud.contains("Day: 2"), "hud: " + hud)
	check(hud.contains("$%d" % Game.money), "hud: " + hud)


func test_special_cat_won() -> void:
	auto_hit = true
	var relics := record(Game.relic_won)
	_open()
	check(await _night_comes(), "night comes")
	eq(Game.last_report.specials_won, 1, "won")
	eq(Game.last_report.spilled, 0, "nothing spilled")
	eq(Game.last_report.sold, 8, "all sold")
	eq(relics.size(), 1, "relic")


func test_night_shop_and_next_day() -> void:
	_open()
	check(await _night_comes(), "night comes")
	check(night._next.disabled, "sold out: no day without drinks")
	var money := Game.money
	night._picks[M].item_selected.emit(1)
	check(Game.is_unlocked(&"grapefruit"), "unlocked from the list")
	eq(Game.selected[M], &"grapefruit", "on sale")
	eq(Game.money, money - 60, "paid")
	night._picks[A].item_selected.emit(3)
	eq(Game.selected[A], &"brandy", "vermouth is too expensive")
	eq(night._picks[A].selected, 0, "list shows brandy again")

	var units: Label = night._units[F]
	var plus: Button = units.get_parent().get_child(units.get_index() + 1)
	plus.pressed.emit()
	eq(Game.recipe[F], 1, "flavor stepper")
	eq(units.text, "1", "stepper label")

	night._restock_n = 15
	night._refresh()
	check(not night._restock.disabled, "can afford 15")
	night._restock.pressed.emit()
	eq(Game.drinks_possible(), 15, "restocked")
	check(night._restock.disabled, "nothing more to buy")
	check(not night._next.disabled, "ready to open")

	night._next.pressed.emit()
	check(not night.visible, "panel closes")
	check(day.running, "day 2 runs")
	check(await _night_comes(), "day 2 ends")
	eq(Game.day, 3, "day 3 next")
	check(Game.last_report.sold > 0, "sold on day 2")


func test_too_pricey() -> void:
	Game.price = 100
	_open()
	check(await _night_comes(20.0), "night comes")
	eq(Game.last_report.ended_by, &"nobody", "nobody came")
	eq(Game.last_report.sold, 0, "sold")
	check(Game.last_report.walked > 0, "they walked by")
	check(night._report.text.contains("too pricey"), "report says why")


func test_empty_shelf() -> void:
	Game.glasses = 0
	_open()
	check(await _night_comes(5.0), "night comes at once")
	eq(Game.last_report.ended_by, &"stock", "nothing to sell")
	check(night._next.disabled, "can't open with nothing to sell")


func test_broke_buy_asks_then_guide_helps() -> void:
	Game.glasses = 0
	_open()
	check(await _night_comes(5.0), "night")
	Game.money = 60
	night._picks[M].item_selected.emit(1)
	check(night._ask.visible, "grapefruit for all the money asks first")
	eq(Game.money, 60, "nothing paid yet")
	var buttons: Array = night._ask.find_children("*", "Button", true, false)
	buttons[1].pressed.emit()
	check(not night._ask.visible, "cancelled")
	check(not Game.is_unlocked(&"grapefruit"), "not bought")
	eq(night._picks[M].selected, 0, "list shows ginger again")
	night._picks[M].item_selected.emit(1)
	buttons[0].pressed.emit()
	check(Game.is_unlocked(&"grapefruit"), "bought")
	eq(Game.money, 0, "all spent")
	eq(Game.drinks_possible(), Game.RESCUE, "the guide brought drinks")
	check(not night._next.disabled, "can open")
	check(night._info.text.contains("guide"), "says so")


func test_boss_and_win() -> void:
	auto_hit = true
	Game.earnings.assign([1500])
	_open()
	check(await _night_comes(120.0), "win screen")
	check(night._report.text.contains("YOU WIN"), "win text: " + night._report.text)
	check(not night._next.visible, "no next day after the win")
	check(not day.running, "day stopped")


func test_five_days() -> void:
	auto_hit = true
	_open()
	for i in 5:
		check(await _night_comes(), "night %d" % (i + 1))
		eq(Game.day, i + 2, "day counter")
		night._restock_n = Game.max_restock()
		night._refresh()
		night._restock.pressed.emit()
		night._next.pressed.emit()
		check(day.running, "day %d runs" % (i + 2))
	eq(Game.earnings.size(), 5, "five days earned")
	check(Game.week_earned() > 0, "money came in")
