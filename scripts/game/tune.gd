class_name Tune
## Every balance number in one place. Juice (shake, flash, bursts) lives in Feel.fx,
## each minigame keeps its own difficulty curve at the top of its script.

# run
const WEEK := 7
const QUOTA := 1500
const START_MONEY := 120
const START_PRICE := 10
const START_REPUTATION := 0.5
# the guide's starter kit, in Ingredients.Kind order: right but plain, cats ask for flavor
const START_SELECTED := [&"brandy", &"ginger_ale", &"cinnamon"]
const START_RECIPE := [1, 2, 0]
const START_GLASSES := 8
const START_STOCK := {&"brandy": 8, &"ginger_ale": 16}

# shop
const GLASS_COST := 1
const BASE_CAPACITY := 5		# units in one glass
const BASE_STORAGE := 25		# max glasses
const RESCUE := 5				# drinks the guide brings when the bar is broke

# selling
const TIP_MAX := 0.5			# a perfect drink tips half the price
const PENALTY_PER_UNIT := 0.25	# each unit off the ideal costs this much score
const REP_MEMORY := 0.5			# how far one day moves the reputation
const FAIR_BASE := 0.85			# fair price = value * (FAIR_BASE + FAIR_REP * reputation)
const FAIR_REP := 0.3
const DEMAND_ZERO := 1.6		# price / fair at which nobody comes, full flow at 1.0
const SERVE_TIME := 0.8

# day
const ARRIVAL := 1.0			# seconds between passers-by
const ARRIVAL_JITTER := 0.3
const MAX_DAY := 30.0
const NOBODY_GIVES_UP := 5.0
const SPECIAL_GAME := &"hit_bar"

# boss
const BOSS_HP := 100
const BOSS_DAMAGE := 35.0		# per perfect hit
const BOSS_SPEEDUP := 0.08		# pace added every round

# loot: tier -> [rarity, better rarity, chance of the better one]
# the chance grows by LOOT_LUCK * difficulty + the loot_luck mod
const LOOT := {&"perfect": [&"rare", &"epic", 0.15], &"good": [&"common", &"rare", 0.25]}
const LOOT_LUCK := 0.3

# mods are added once per level, keys as in Game.mod()
const UPGRADES := {
	&"storage": {name = "Bigger Shelf", desc = "+5 glasses of storage", costs = [80, 160, 320], mods = {storage = 5}},
	&"capacity": {name = "Tall Glasses", desc = "+1 unit per glass", costs = [120, 260], mods = {capacity = 1}},
	&"service": {name = "Quick Hands", desc = "Serve 25% faster", costs = [60, 140, 300], mods = {serve_speed = 0.25}},
}
