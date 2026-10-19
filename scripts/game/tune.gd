class_name Tune
## Every balance number in one place. Juice (shake, flash, bursts) lives in Feel.fx,
## each minigame keeps its own difficulty curve at the top of its script.

# run
const WEEK := 7
const QUOTA := 900			# ~6 min game: the boss comes after day 5
const START_MONEY := 85
const START_PRICE := 7
const GOLD_MULT := 1.15			# cats pay this much of the price (and its tip): +15 % gold, same quota
const START_REPUTATION := 0.5
const SAFE_DAYS := 3			# the sister pays back mistakes (lost tips, walk-aways, spills); reputation can't drop
# the guide's starter kit, in Ingredients.Kind order: right but plain, cats ask for flavor
const START_SELECTED := [&"alcohol", &"mixer", &"flavor"]
const START_RECIPE := [1, 2, 0]
# about 6 drinks: the mixer runs out first, near the end of the first day
const START_GLASSES := 8
const START_STOCK := {&"alcohol": 7, &"mixer": 12, &"flavor": 6}	# night 0 only has the recipe: flavor to try
const START_TARGET := 5			# drinks the night's restock fills the shelf up to (glasses too)

# shop
const GLASS_COST := 1
const BASE_CAPACITY := 5		# units in one glass
const RESCUE := 5				# drinks the guide brings when the bar is broke

# selling
const TIP_MAX := 0.1			# a perfect drink tips a tenth of the price, the Tip Jar adds more
const PENALTY_PER_UNIT := 0.25	# each unit off the ideal costs this much score
const REP_MEMORY := 0.5			# how far one day moves the reputation
const FAIR_BASE := 0.85			# fair price = value * (FAIR_BASE + FAIR_REP * reputation)
const FAIR_REP := 0.3
const DEMAND_ZERO := 1.8		# price / fair at which nobody comes, full flow at 1.0
const SERVE_TIME := 2.0

# day
const ARRIVAL := 2.7			# seconds between passers-by: a queue of 0-1 until Street Sign
const ARRIVAL_JITTER := 0.1
const MAX_DAY := 20.0			# short days, Late Hours grows them
const NOBODY_GIVES_UP := 5.0
const SPECIAL_GAME := &"hit_bar"

# customers
const CAT_SPEED := 30.0 # walking pixels per second
const CAT_DOOR_FADE := 12.0 # pixels from the doorway over which a cat steps out of the dark

# boss: stages one after another, round by round; damage = quality * damage, pace grows
# by speedup each round, flip = every other round runs the other way. Any minigame id.
const BOSS_STAGES := [
	{game = &"hit_bar", hp = 3, damage = 1.0, fixed_damage = true, pace = 1.0, speedup = 0.08},
]
const BOSS_LIVES := 3			# per try, a miss costs one
const BOSS_PAUSE := 1.0			# after a stage is cleared, after the boss laughs

# loot: tier -> [rarity, better rarity, chance of the better one]
# the chance grows by LOOT_LUCK * difficulty + the loot_luck mod
const LOOT := {&"perfect": [&"rare", &"epic", 0.15], &"good": [&"common", &"rare", 0.25],
	&"meh": [&"common", &"rare", 0.1], &"miss": [&"common", &"rare", 0.0]}
const RELIC_CHANCE := 0.7		# a special cat drops a relic, whatever the minigame went like
const EPIC_DAY := 4			# the first special from this day on surely drops an epic
const LATE_RELICS := [&"pc_tower"]	# too strong early: these drop from LATE_DAY on
const LATE_DAY := 4
const LOOT_LUCK := 0.3

# mods are added once per level, keys as in Game.mod()
const UPGRADES := {
	&"tips": {name = "Tip Jar", desc = "Earn larger tips.", details = "Each level adds 400% of the base tip.\nTips still depend on drink quality.", costs = [35, 60, 95], mods = {tip_mult = 4.0}},
	&"service": {name = "Quick Hands", desc = "Serve drinks faster.", details = "Each level adds 60% of the base\nserving speed.", costs = [40, 60, 95], mods = {serve_speed = 0.6}},
	&"cats": {name = "Street Sign", desc = "Attract more cats.", details = "Each level adds 60% of the base\narrival rate. Keep prices fair\nto turn passersby into customers.", costs = [40, 65, 100], mods = {arrival_mult = 0.6}},
	&"hours": {name = "Late Hours", desc = "Keep the bar open longer.", details = "Each level adds 8 seconds\nto the working day.", costs = [35, 60, 95], mods = {day_length = 8}},
	&"whack": {name = "Percussive Maintenance", desc = "Click the machine to serve faster.", details = "Click the machine to add 50% serving\nspeed for 5 seconds.\nThe base cooldown is 20 seconds.", costs = [55], mods = {whack = 1}},
	&"backpack": {name = "Bigger Backpack", desc = "Make room for more relics.", details = "Expand your backpack to 15 slots,\nthen 20, then 24. Relics must be\nin the backpack to take effect.", costs = [25, 50, 90], mods = {grid = 1}, after = &"bag"},
}

const WHACK_TIME := 5.0 # seconds of faster serving
const WHACK_BOOST := 0.5 # extra serve speed
const WHACK_COOLDOWN := 20.0 # seconds from whack to ready
const MACHINE_SPOT := 1.5 # the light on the machine before the first day it can be whacked

const EVENTS := {&"newspaper": {arrival_mult = 0.3}} # story demand sources
const HOMELESS_CHANCE := 0.05 # share of admitted passers-by; only the first street day surely has one
const HOMELESS_SCARE := 0.5 # demand lost while a street cat is inside
const HOMELESS_BEG_TIME := 3.0 # seconds between requests
const HOMELESS_KICK_TIME := 0.45 # flight out of the door
const HOMELESS_KICK_HEIGHT := 34.0 # arc height in pixels
const HOMELESS_KICK_SPINS := 2.0
const HOMELESS_STUMBLE := 4.0 # pixels on a meh kick
const HOMELESS_LOOT := 6 # money a kicked street cat drops on a good kick: a bit under one drink
const HOMELESS_LOOT_PERFECT := 25 # and on a perfect one: a handful of drinks
