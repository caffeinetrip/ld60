class_name Relics
## Relic list (placeholders for now). A relic covers `shape` cells in the
## Backpack grid; `stars` are cells around it (relative to the shape, outside it) that
## light up when a placed relic with `star_tag` covers them (&"" = any relic).
## `mods` count while placed, `star_mods` once more per lit star; keys as in Game.mod().
## Optional `proc` = {event, chance, game, reward}: on `event` (&"serve", &"day_start")
## it rolls `chance`, plays minigame `game` and pays `reward` ({money}) times its quality.

const RARITY_COLOR := {&"common": Color("9c8a99"), &"rare": Color("4aa3df"), &"epic": Color("b06ad9")}

const DEFS := {
	&"tip_jar": {name = "Tip Jar", rarity = &"common", tags = [&"glass"],
		shape = [Vector2i(0, 0)], stars = [Vector2i(1, 0)], star_tag = &"",
		mods = {tip_mult = 0.1}, star_mods = {tip_mult = 0.05}, text = "Every coin counts."},
	&"lucky_coaster": {name = "Lucky Coaster", rarity = &"common", tags = [&"wood"],
		shape = [Vector2i(0, 0)], stars = [Vector2i(0, -1), Vector2i(0, 1)], star_tag = &"glass",
		mods = {demand_mult = 0.05}, star_mods = {demand_mult = 0.05}, text = "Never a wet ring."},
	&"old_shaker": {name = "Old Shaker", rarity = &"common", tags = [&"metal"],
		shape = [Vector2i(0, 0), Vector2i(0, 1)], stars = [Vector2i(1, 0), Vector2i(1, 1)], star_tag = &"fruit",
		mods = {hit_zone = 0.1}, star_mods = {hit_zone = 0.05}, text = "Dented, still the best."},
	&"bar_spoon": {name = "Bar Spoon", rarity = &"common", tags = [&"metal"],
		shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], stars = [Vector2i(0, 1), Vector2i(2, 1)], star_tag = &"",
		mods = {hit_slow = 0.08}, star_mods = {hit_slow = 0.04}, text = "Stir, don't rush."},
	&"lemon_bowl": {name = "Lemon Bowl", rarity = &"rare", tags = [&"fruit"],
		shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], stars = [Vector2i(2, 0), Vector2i(2, 1)], star_tag = &"glass",
		mods = {fair_mult = 0.08}, star_mods = {fair_mult = 0.04}, text = "Smells like summer."},
	&"neon_sign": {name = "Neon Sign", rarity = &"rare", tags = [&"metal"],
		shape = [Vector2i(0, 0), Vector2i(1, 0)], stars = [Vector2i(0, 1), Vector2i(1, 1)], star_tag = &"cat",
		mods = {demand_mult = 0.1}, star_mods = {price_mult = 0.05}, text = "OPEN, it buzzes."},
	&"cat_bell": {name = "Cat Bell", rarity = &"rare", tags = [&"cat"],
		shape = [Vector2i(0, 0)], stars = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)], star_tag = &"",
		mods = {loot_luck = 0.1}, star_mods = {loot_luck = 0.03}, text = "Someone special is coming."},
	&"wholesale_crate": {name = "Wholesale Crate", rarity = &"rare", tags = [&"wood"],
		shape = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], stars = [Vector2i(1, 0)], star_tag = &"wood",
		mods = {discount = 0.1}, star_mods = {discount = 0.05}, text = "Bought by the dozen."},
	&"golden_tap": {name = "Golden Tap", rarity = &"epic", tags = [&"metal", &"glass"],
		shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], stars = [Vector2i(0, 1), Vector2i(2, 1)], star_tag = &"glass",
		mods = {price_mult = 0.1}, star_mods = {tip_mult = 0.1}, text = "Pours like money."},
	&"fat_cat_statue": {name = "Fat Cat Statue", rarity = &"epic", tags = [&"cat"],
		shape = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], stars = [Vector2i(-1, 0), Vector2i(2, 1)], star_tag = &"",
		mods = {capacity = 1}, star_mods = {fair_mult = 0.05}, text = "Rub the belly for luck."},
}

const MOD_TEXT := {
	price_mult = "+%d%% price", tip_mult = "+%d%% tips", demand_mult = "+%d%% cats",
	fair_mult = "+%d%% fair price", discount = "-%d%% unit cost", serve_speed = "+%d%% serve speed",
	hit_slow = "%d%% slower bar", hit_zone = "+%d%% hit zone", loot_luck = "+%d%% loot luck",
	special_mult = "+%d%% special cats", capacity = "+%d unit per glass", storage = "+%d storage",
}
const FLAT := ["capacity", "storage"]

## Relics made at runtime (events, tests), same format as DEFS.
static var custom := {}


static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, custom.get(id, {}))


static func roll(rarity: StringName, rng: RandomNumberGenerator) -> StringName:
	var pool: Array[StringName] = []
	for id in DEFS:
		if DEFS[id].rarity == rarity:
			pool.append(id)
	if pool.is_empty():
		pool.assign(DEFS.keys())
	return pool[rng.randi() % pool.size()]


## "+10% tips, +1 unit per glass"
static func describe(mods: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in mods:
		var v: float = mods[key] if FLAT.has(key) else mods[key] * 100.0
		parts.append(MOD_TEXT.get(key, String(key) + " %d") % roundi(v))
	return ", ".join(parts)


## Tooltip text: name, rarity and tags, mods, star rule, flavor.
static func info(id: StringName) -> String:
	var d := get_def(id)
	var tags := PackedStringArray()
	for t in d.tags:
		tags.append(String(t).to_upper())
	var lines := PackedStringArray(["%s - %s %s" % [d.name, String(d.rarity).to_upper(), ", ".join(tags)]])
	if not d.get("mods", {}).is_empty():
		lines.append(describe(d.mods))
	if not d.get("star_mods", {}).is_empty():
		var who: String = "any relic" if d.star_tag == &"" else String(d.star_tag)
		lines.append("* next to %s: %s each" % [who, describe(d.star_mods)])
	lines.append(d.text)
	return "\n".join(lines)
