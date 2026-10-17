extends "res://tests/suite.gd"

const A := Ingredients.Kind.ALCOHOL
const M := Ingredients.Kind.MIXER
const F := Ingredients.Kind.FLAVOR


func _finish_day(revenue: int) -> void:
	Game.start_day()
	Game.today.revenue = revenue
	Game.end_day(&"time")


func test_new_run() -> void:
	Game.money = 3
	Game.day = 9
	Game.upgrades[&"storage"] = 2
	Game.new_run()
	eq(Game.money, 120, "money")
	eq(Game.day, 1, "day")
	eq(Game.price, 10, "price")
	eq(Game.glasses, 8, "starter glasses")
	eq(Game.stock[&"brandy"], 8, "starter brandy")
	eq(Game.stock[&"ginger_ale"], 16, "starter ginger ale")
	eq(Game.stock[&"sake"], 0, "sake")
	eq(Game.storage(), 25, "storage")
	eq(Game.selected, {A: &"brandy", M: &"ginger_ale", F: &"cinnamon"}, "on sale")
	eq(Game.recipe, {A: 1, M: 2, F: 0}, "recipe")
	eq(Game.unlocked.keys().size(), 3, "open ingredients")
	eq(Game.drinks_possible(), 8, "drinks")
	eq(Game.week_earned(), 0, "week")


func test_starter_kit_lacks_only_flavor() -> void:
	eq(Game.ideal(), {A: 1, M: 2, F: 1}, "brandy, ginger, cinnamon")
	eq(Game.taste(), {score = 0.75, line = "Needs some flavor..."}, "taste")


func test_ideal_follows_ingredients() -> void:
	Game.unlocked[&"sake"] = true
	Game.unlocked[&"absinthe"] = true
	Game.select(&"sake")
	eq(Game.ideal(), {A: 2, M: 1, F: 1}, "light sake, less mixer")
	Game.select(&"absinthe")
	eq(Game.ideal(), {A: 1, M: 3, F: 1}, "strong absinthe, more mixer")
	_finish_day(0)
	_finish_day(0)
	eq(Game.ideal(), {A: 1, M: 3, F: 1}, "same every day")
	for a in Ingredients.of_kind(A):
		for f in Ingredients.of_kind(F):
			Game.selected[A] = a
			Game.selected[F] = f
			var sum: int = Game.ideal().values().reduce(func(t, v): return t + v)
			check(sum <= Game.BASE_CAPACITY, "%s + %s fits a plain glass" % [a, f])


func test_unlock() -> void:
	var paid := record(Game.money_changed)
	check(not Game.unlock(&"absinthe"), "absinthe is too expensive")
	eq(Game.money, 120, "money after failed unlock")
	check(not Game.select(&"sake"), "can't sell locked sake")
	check(Game.unlock(&"sake"), "sake unlocks for $120")
	eq(Game.money, 0, "money after unlock")
	eq(paid, [0], "money_changed")
	check(not Game.unlock(&"sake"), "second unlock")
	check(Game.select(&"sake"), "sell sake")
	eq(Game.selected[A], &"sake", "alcohol on sale")


func test_recipe_limits() -> void:
	check(not Game.set_recipe(A, 0), "alcohol can't be 0")
	check(Game.set_recipe(F, 2), "fill the glass to 5")
	check(not Game.set_recipe(M, 3), "6 units don't fit")
	eq(Game.recipe, {A: 1, M: 2, F: 2}, "recipe")
	check(Game.set_recipe(F, -3), "negative clamps")
	eq(Game.recipe[F], 0, "flavor")
	Game.money = 1000
	Game.buy_upgrade(&"capacity")
	eq(Game.capacity(), 6, "tall glasses")
	check(Game.set_recipe(A, 3), "3+2 fits")
	check(Game.set_recipe(M, 3), "3+3 fits in 6")
	Game.set_bonuses({capacity = 1.0})
	eq(Game.capacity(), 7, "relic capacity")


func test_drinks_possible() -> void:
	Game.set_recipe(A, 2)
	eq(Game.drinks_possible(), 4, "8 brandy / 2")
	Game.glasses = 3
	eq(Game.drinks_possible(), 3, "glasses limit")
	Game.set_recipe(A, 1)
	Game.set_recipe(F, 1)
	eq(Game.drinks_possible(), 0, "no cinnamon")


func test_restock() -> void:
	eq(Game.cost_per_drink(), 5, "glass 1 + brandy 2 + ginger 2")
	eq(Game.restock_cost(8), 0, "already have 8")
	check(not Game.restock(8), "nothing to buy")
	eq(Game.restock_cost(10), 10, "2 more drinks")
	check(Game.restock(10), "restock 10")
	eq(Game.money, 110, "money")
	eq(Game.glasses, 10, "glasses")
	eq(Game.stock[&"brandy"], 10, "brandy")
	eq(Game.drinks_possible(), 10, "drinks")


func test_restock_caps_at_storage() -> void:
	check(Game.restock(100), "restock past storage")
	eq(Game.glasses, 25, "glasses")
	eq(Game.money, 120 - 85, "17 drinks x $5")
	eq(Game.max_restock(), 25, "full")


func test_restock_needs_money() -> void:
	Game.money = 5
	check(not Game.restock(25), "too poor")
	eq(Game.money, 5, "money")
	eq(Game.glasses, 8, "glasses")


func test_max_restock() -> void:
	eq(Game.max_restock(), 25, "rich enough to fill the shelf")
	Game.money = 20
	eq(Game.max_restock(), 12, "4 more drinks for $20")
	check(Game.restock(Game.max_restock()), "buy max")
	eq(Game.money, 0, "money")
	eq(Game.max_restock(), 12, "nothing more")


func _empty_shelf() -> void:
	Game.glasses = 0
	for id in Game.stock:
		Game.stock[id] = 0


func test_rescue() -> void:
	check(not Game.rescue(), "stock left")
	_empty_shelf()
	Game.money = 5
	check(not Game.rescue(), "$5 buys a drink")
	Game.money = 4
	check(Game.rescue(), "broke")
	eq(Game.drinks_possible(), Game.RESCUE, "guide's drinks")
	eq(Game.money, 4, "free")
	check(not Game.rescue(), "once is enough")


func test_strands() -> void:
	check(not Game.strands(120), "the shelf still has drinks")
	_empty_shelf()
	check(not Game.strands(115), "$5 left for a drink")
	check(Game.strands(116), "$4 left")
	check(not Game.strands(113, &"sake"), "$7 left for a sake drink")
	check(Game.strands(114, &"sake"), "$6 left")
	eq(Game.selected[A], &"brandy", "selection untouched")


func test_discount() -> void:
	Game.set_bonuses({discount = 0.5})
	eq(Game.unit_cost(&"brandy"), 1, "brandy")
	eq(Game.unit_cost(&"absinthe"), 3, "absinthe")
	eq(Game.unit_cost(&"ginger_ale"), 1, "never free")


func test_upgrades() -> void:
	check(Game.buy_upgrade(&"storage"), "shelf for 80")
	eq(Game.money, 40, "money")
	eq(Game.storage(), 30, "storage")
	eq(Game.upgrade_cost(&"storage"), 160, "next level")
	check(not Game.buy_upgrade(&"storage"), "too poor")
	Game.money = 1000
	check(Game.buy_upgrade(&"capacity"), "capacity 1")
	check(Game.buy_upgrade(&"capacity"), "capacity 2")
	eq(Game.capacity(), 7, "capacity")
	eq(Game.upgrade_cost(&"capacity"), -1, "maxed")
	check(not Game.buy_upgrade(&"capacity"), "past max")
	eq(Game.money, 1000 - 120 - 260, "money")
	var before := Game.serve_time()
	Game.buy_upgrade(&"service")
	check(Game.serve_time() < before, "quick hands")


func test_fair_price_and_demand() -> void:
	near(Game.fair_price(), 8.0, "brandy 6 + ginger 2")
	near(Game.demand(), 0.5833, "price 10")
	Game.price = 8
	near(Game.demand(), 1.0, "fair price")
	Game.price = 1
	near(Game.demand(), 1.0, "cheap doesn't add more")
	Game.price = 13
	near(Game.demand(), 0.0, "x1.6 is too pricey")
	Game.reputation = 1.0
	near(Game.fair_price(), 9.2, "good name")
	Game.set_recipe(F, 1)
	near(Game.fair_price(), 11.5, "flavor adds value")
	Game.set_bonuses({fair_mult = 1.0})
	near(Game.fair_price(), 23.0, "relic")


func test_sell() -> void:
	Game.stock[&"cinnamon"] = 8
	Game.set_recipe(F, 1)
	Game.start_day()
	eq(Game.drinks_left(), 8, "drinks left")
	eq(Game.sell_next(), {money = 15, score = 1.0, line = ""}, "perfect drink: $10 + $5 tip")
	eq(Game.money, 135, "money")
	eq(Game.today.sold, 1, "sold")
	eq(Game.today.tips, 5, "tips")
	eq(Game.glasses, 7, "glasses")
	eq(Game.stock[&"brandy"], 7, "brandy")
	eq(Game.stock[&"ginger_ale"], 14, "ginger")
	eq(Game.drinks_left(), 7, "left")
	eq(Game.week_earned(), 15, "week counts today")
	eq(Game.sell_next(0.5).money, 13, "meh hit: half tip")
	eq(Game.sell_next(0.0).money, 0, "spilled")
	eq(Game.today.spilled, 1, "spilled")
	eq(Game.today.sold, 2, "spill isn't a sale")
	eq(Game.stock[&"brandy"], 5, "spill still costs the drink")
	Game.set_bonuses({price_mult = 0.2, tip_mult = 1.0})
	eq(Game.sell_next().money, 22, "relics: $12 + $10 tip")


func test_sell_out() -> void:
	Game.start_day()
	for i in 8:
		Game.sell_next()
	eq(Game.drinks_left(), 0, "sold out")
	eq(Game.sell_next(), {money = 0, score = 0.0, line = ""}, "nothing left")
	eq(Game.stock[&"brandy"], 0, "stock")
	eq(Game.glasses, 0, "glasses")


func test_complaints() -> void:
	Game.start_day()
	var sale := Game.sell_next()
	eq(sale.line, "Needs some flavor...", "no flavor")
	near(sale.score, 0.75, "score")
	eq(sale.money, 14, "smaller tip")
	eq(Game.today.complaints, {"Needs some flavor...": 1}, "report")
	Game.set_recipe(F, 1)
	eq(Game.taste(), {score = 1.0, line = ""}, "fixed")
	Game.set_recipe(A, 2)
	eq(Game.taste().line, "Too much Brandy!", "too much")
	Game.set_recipe(A, 1)
	Game.set_recipe(M, 0)
	eq(Game.taste().line, "Needs something to mix...", "no mixer")
	Game.set_recipe(M, 1)
	eq(Game.taste().line, "More Ginger Ale, please.", "too little")
	Game.set_recipe(M, 2)
	Game.unlocked[&"sake"] = true
	Game.select(&"sake")
	eq(Game.taste().line, "More Sake, please.", "sake wants more of itself")


func test_end_day() -> void:
	var reports := record(Game.day_ended)
	Game.start_day()
	Game.sell_next()
	Game.sell_next()
	Game.today.walked = 3
	var r := Game.end_day(&"stock")
	eq(r.sold, 2, "sold")
	eq(r.revenue, 28, "revenue: plain drinks, $10 + $4 tip")
	eq(r.walked, 3, "walked")
	eq(r.ended_by, &"stock", "reason")
	eq(reports.size(), 1, "day_ended")
	eq(Game.last_report, r, "last report")
	eq(Game.day, 2, "next day")
	eq(Game.today.sold, 0, "today reset")
	eq(Game.drinks_left(), 0, "left")
	near(Game.reputation, 0.625, "rep blends half way to 0.75")
	_finish_day(0)
	near(Game.reputation, 0.625, "no sales, rep stays")


func test_week_is_seven_days() -> void:
	for r in [400, 190, 190, 190, 190, 190, 190]:
		_finish_day(r)
	eq(Game.week_earned(), 1540, "night after day 7: days 1-7")
	check(Game.director.boss_due(), "quota met by days 1-7")
	Game.start_day()
	eq(Game.week_earned(), 1140, "day 8 running: days 2-7 + today")
	Game.today.revenue = 50
	eq(Game.week_earned(), 1190, "with today")
	Game.end_day(&"time")
	eq(Game.week_earned(), 1190, "night after day 8: days 2-8")
	near(Game.quota_progress(), 1190.0 / 1500.0, "progress")
	_finish_day(9000)
	near(Game.quota_progress(), 1.0, "progress caps")


func test_hit_params() -> void:
	var p := Game.hit_params()
	near(p.speed, 120.0, "slow at start")
	near(p.good_zone, 0.4, "wide at start")
	near(p.perfect_zone, 0.12, "perfect at start")
	eq(p.flip, false, "no flip at start")
	Game.earnings.assign([1500])
	p = Game.hit_params()
	near(p.speed, 240.0, "fast at quota")
	near(p.good_zone, 0.22, "narrow at quota")
	near(p.perfect_zone, 0.05, "perfect at quota")
	Game.set_bonuses({hit_slow = 0.9, hit_zone = 5.0})
	p = Game.hit_params()
	near(p.speed, 72.0, "slow relic floors at x0.3")
	near(p.good_zone, 0.9, "good caps")
	near(p.perfect_zone, 0.3, "perfect x6")


func test_relic_rolls() -> void:
	var won := record(Game.relic_won)
	eq(Game.grant_relic(&"miss"), &"", "miss")
	eq(Game.grant_relic(&"meh"), &"", "meh")
	for i in 20:
		check(Game.grant_relic(&"perfect") in [&"epic", &"rare"], "perfect rarity")
		check(Game.grant_relic(&"good") in [&"rare", &"common"], "good rarity")
	eq(won.size(), 40, "relic_won")
